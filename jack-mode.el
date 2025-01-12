;;; jack-mode.el --- Major mode for Jack language -*- lexical-binding: t; -*-
;;
;; This is free and unencumbered software released into the public domain.
;;
;; Author: Noah Peart <noah.v.peart@gmail.com>
;; Maintainer: Noah Peart <noah.v.peart@gmail.com>
;; URL: https://github.com/nverno/jack-mode
;; Package-Requires: ((emacs "27.1"))
;; Created: 21 December 2021
;; Version: 1.0.0
;;
;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;;; Commentary:
;;
;;  A major mode for editing Jack programming language files. The Jack language is
;;  developed as part of the Nand2Tetris coures (available on Coursera).
;;
;;  This mode derives from `cc-mode', and inherits from `java-mode'.
;;
;;; Code:
(eval-when-compile
  (require 'cl-lib)
  (require 'cc-langs)
  (require 'cc-fonts))
(require 'cc-mode)

(defgroup jack-mode nil
  "Major mode for editing Jack language files."
  :group 'languages
  :prefix "jack-mode-")

(defcustom jack-mode-indent-offset 2
  "Amount by which expressions are indented."
  :type 'integer
  :group 'jack-mode)

(defcustom jack-mode-font-lock-extra-types java-font-lock-extra-types
  "List of extra types to recognize (regexps)."
  :type 'sexp
  :group 'jack-mode)

(defcustom jack-mode-font-lock-builtins t
  "Apply font-lock to Jack OS builtin classes and methods."
  :type 'boolean
  :group 'jack-mode)

(defcustom jack-mode-compiler "JackCompiler"
  "Path to Jack compiler, eg. nand2tetris/tools/JackCompiler.sh."
  :type 'string
  :group 'jack-mode
  :safe 'stringp)

(eval-and-compile
  (defconst jack-mode-builtins
    '(("Math"
       "abs" "divide" "max" "min" "multiply" "sqrt")
      ("String"
       "appendChar" "backSpace" "charAt" "dispose" "doubleQuote" "eraseLastChar"
       "intValue" "length" "new" "setCharAt" "setInt")
      ("Array"
       "dispose" "new")
      ("Output"
       "backSpace" "moveCursor" "printChar" "printInt" "println" "printString")
      ("Screen"
       "clearScreen" "drawCircle" "drawLine" "drawPixel" "drawRectangle"
       "setColor")
      ("Keyboard"
       "keyPressed" "readChar" "readInt" "readLine")
      ("Memory"
       "alloc" "deAlloc" "peek" "poke")
      ("Sys"
       "error" "halt" "wait"))
    "Jack OS API Builtin classes and methods.")

  (defconst jack-mode--builtins-class-re
    (eval-when-compile
      (regexp-opt (mapcar #'car jack-mode-builtins) 'paren)))

  (defconst jack-mode--builtins-method-res
    (eval-when-compile
      (mapcar (lambda (cls)
                (concat "\\_<\\(" (car cls) "\\)\\_>"
                        "\\(?:\\." (regexp-opt (cdr cls) 'symbols) "\\)?"))
              jack-mode-builtins)))

  (defconst jack-mode--font-lock-builtins
    (eval-when-compile
      (mapcar (lambda (re) (list re '(1 'font-lock-function-name-face)
                            '(2 'font-lock-function-name-face)))
              jack-mode--builtins-method-res))))

;;; Modifications of java's defaults -- `c-lang-constants'
;; 
;; `c-constant-kwds' are fine => null, true, false
;;
;; Variable font-locking in decls, params, let expressions:
;;   (static|field|var) type varname(, varname)*;
;;   (method|function|constructor) type funcname((type varname(, type varname)*)?)
;;   let x = "foo";

;; inherit from java-mode
(eval-and-compile (c-add-language 'jack-mode 'java-mode))

(eval-when-compile
  ;; un/define c-lang-defconsts
  (defmacro jack-def-c-consts (&rest kwds)
    (macroexp-progn
     (cl-loop for (kwd . def) in kwds
              collect (if (stringp (car def))
                          `(c-lang-defconst ,kwd jack ',def)
                        `(c-lang-defconst ,kwd jack ,@def)))))
  (defmacro jack-undef-c-consts (&rest kwds)
    (macroexp-progn
     (cl-loop for kwd in kwds
        collect `(c-lang-defconst ,kwd jack nil)))))

(jack-def-c-consts
 (c-keywords "class" "constructor" "method" "function"
             "var" "field" "static"
             "do" "let" "if" "while" "else" "return"
             "true" "false" "null" "void" "this"
             "boolean" "int" "char")
 (c-operator-list "." "[" "]" "(" ")" "<" ">" "~" "-" "+" "/" "*" "|" "&" "=" ",")
 (c-arithmetic-operators "*" "+" "-" "/" "~" "<" ">" "&" "|" "=")
 (c-unary-operators "~" "-")
 (c-modifier-kwds
  (append '("function" "constructor" "method" "var" "field" "let")
          (c-lang-const c-modifier-kwds)))
 (c-typeless-decl-kwds
  ;; font-lock x in let x = ... as variable
  (append '("let") (c-lang-const c-typeless-decl-kwds)))
 (c-simple-stmt-kwds "return" "do"))

;;; Font-locking
(defconst jack-font-lock-keywords-1 (c-lang-const c-matchers-1 jack))
(defconst jack-font-lock-keywords-2 (c-lang-const c-matchers-2 jack))
(defconst jack-font-lock-keywords-3 (c-lang-const c-matchers-3 jack))
(defvar jack-font-lock-keywords jack-font-lock-keywords-3
  "Default expressions to highlight in `jack-mode'.")

(defun jack-mode-font-lock-keywords-2 ()
  "Jack mode font-locking."
  (c-compose-keywords-list jack-font-lock-keywords-2))
(defun jack-mode-font-lock-keywords-3 ()
  "Jack mode font-locking."
  (c-compose-keywords-list jack-font-lock-keywords-3))
(defun jack-mode-font-lock-keywords ()
  "Jack mode font-locking."
  (c-compose-keywords-list jack-font-lock-keywords))

;; Use C syntax
(defvar jack-mode-syntax-table nil)

;;; Compilation
(defvar compilation-error-regexp-alist-alist)
(defvar compilation-error-regexp-alist)

(defvar jack-mode-error-regexp-alist
  '((jack-1 "In \\([^ ]+\\) (line \\([0-9]+\\)):" 1 2))
  "Regexps to match error messages from reference compiler, ie. nand2tetris/tools/JackCompiler.sh.")

(defun jack-mode-compilation-hook ()
  "Setup `jack-mode' compilation."
  (unless (assoc 'jack-1 compilation-error-regexp-alist-alist)
    (mapc (lambda (elem)
            (push (car elem) compilation-error-regexp-alist)
            (push elem compilation-error-regexp-alist-alist))
          jack-mode-error-regexp-alist)
    (remove-hook 'jack-mode-compilation-hook 'compilation-mode-hook)))
(add-hook 'compilation-mode-hook #'jack-mode-compilation-hook)

;;; Imenu
(defvar imenu-generic-expression)

(defvar jack-mode-imenu-expression
  (eval-when-compile
    (let ((decls (regexp-opt '("function" "constructor" "method")))
          (type "[[:alnum:]]+")
          (name "[[:alnum:]]+"))
      `((nil ,(concat "^\\s-*\\<" decls "\\s-+" type "\\s-+"
                      "\\(" name "\\)\\s-*(")
             1)))))

;;;###autoload
(define-derived-mode jack-mode prog-mode "Jack"
  "Major mode for editing jack files.

\\{jack-mode-map}"
  :after-hook (c-update-modeline)
  :syntax-table c-mode-syntax-table     ; C-style comments

  ;; initialize cc-mode stuff
  (c-initialize-cc-mode t)
  (c-init-language-vars jack-mode)
  (c-common-init 'jack-mode)

  ;; indentation
  (setq c-basic-offset jack-mode-indent-offset)
  (c-run-mode-hooks 'c-mode-common-hook)

  (setq-local compile-command
              (format "%s %s" jack-mode-compiler (buffer-file-name)))
  (setq-local imenu-generic-expression jack-mode-imenu-expression)
  (when jack-mode-font-lock-builtins
    (font-lock-add-keywords nil jack-mode--font-lock-builtins 'append)))

;;;###autoload(add-to-list 'auto-mode-alist '("\\.jack\\'" . jack-mode))

(provide 'jack-mode)
;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:
;;; jack-mode.el ends here
