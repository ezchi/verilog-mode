;;; verilog-mode.el --- major mode for editing verilog source in Emacs

;; Copyright (C) 1996-2018 Free Software Foundation, Inc.

;; Author: Michael McNamara <mac@verilog.com>
;;    Wilson Snyder <wsnyder@wsnyder.org>
;; X-URL: http://www.veripool.org
;; Created: 3 Jan 1996
;; Keywords: languages

;; Yoni Rabkin <yoni@rabkins.net> contacted the maintainer of this
;; file on 19/3/2008, and the maintainer agreed that when a bug is
;; filed in the Emacs bug reporting system against this file, a copy
;; of the bug report be sent to the maintainer's email address.

;;    This code supports Emacs 21.1 and later
;;    And XEmacs 21.1 and later
;;    Please do not make changes that break Emacs 21.  Thanks!
;;
;;

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; USAGE
;; =====

;; A major mode for editing Verilog and SystemVerilog HDL source code (IEEE
;; 1364-2005 and IEEE 1800-2012 standards).  When you have entered Verilog
;; mode, you may get more info by pressing C-h m. You may also get online
;; help describing various functions by: C-h f <Name of function you want
;; described>

;; KNOWN BUGS / BUG REPORTS
;; =======================

;; SystemVerilog is a rapidly evolving language, and hence this mode is
;; under continuous development.  Please report any issues to the issue
;; tracker at
;;
;;    http://www.veripool.org/verilog-mode
;;
;; Please use verilog-submit-bug-report to submit a report; type C-c
;; C-b to invoke this and as a result we will have a much easier time
;; of reproducing the bug you find, and hence fixing it.

;; INSTALLING THE MODE
;; ===================

;; An older version of this mode may be already installed as a part of
;; your environment, and one method of updating would be to update
;; your Emacs environment.  Sometimes this is difficult for local
;; political/control reasons, and hence you can always install a
;; private copy (or even a shared copy) which overrides the system
;; default.

;; You can get step by step help in installing this file by going to
;; <http://www.veripool.com/verilog-mode>

;; The short list of installation instructions are: To set up
;; automatic Verilog mode, put this file in your load path, and put
;; the following in code (please un comment it first!) in your
;; .emacs, or in your site's site-load.el

;;   (autoload 'verilog-mode "verilog-mode" "Verilog mode" t )
;;   (add-to-list 'auto-mode-alist '("\\.[ds]?vh?\\'" . verilog-mode))

;; Be sure to examine at the help for verilog-auto, and the other
;; verilog-auto-* functions for some major coding time savers.
;;
;; If you want to customize Verilog mode to fit your needs better,
;; you may add the below lines (the values of the variables presented
;; here are the defaults). Note also that if you use an Emacs that
;; supports custom, it's probably better to use the custom menu to
;; edit these.  If working as a member of a large team these settings
;; should be common across all users (in a site-start file), or set
;; in Local Variables in every file.  Otherwise, different people's
;; AUTO expansion may result different whitespace changes.
;;
;;   ;; Enable syntax highlighting of **all** languages
;;   (global-font-lock-mode t)
;;
;;   ;; User customization for Verilog mode
;;   (setq verilog-indent-level             3
;;         verilog-indent-level-module      3
;;         verilog-indent-level-declaration 3
;;         verilog-indent-level-behavioral  3
;;         verilog-indent-level-directive   1
;;         verilog-case-indent              2
;;         verilog-auto-newline             t
;;         verilog-indent-on-newline   t
;;         verilog-tab-always-indent        t
;;         verilog-auto-endcomments         t
;;         verilog-minimum-comment-distance 40
;;         verilog-indent-begin-after-if    t
;;         verilog-auto-lineup              'declarations
;;         verilog-highlight-p1800-keywords nil
;;         )


;;; History:
;;
;; See commit history at http://www.veripool.org/verilog-mode.html
;; (This section is required to appease checkdoc.)

;;; Code:
;;

;; This variable will always hold the version number of the mode
(defconst verilog-mode-version "__VMVERSION__-__VMREVISION__-__VMPACKAGER__"
  "Version of this Verilog mode.")
(defconst verilog-mode-release-emacs nil
  "If non-nil, this version of Verilog mode was released with Emacs itself.")

(defun verilog-version ()
  "Inform caller of the version of this file."
  (interactive)
  (message "Using verilog-mode version %s" verilog-mode-version))

(defun verilog-regexp-words (a)
  "Call `regexp-opt' with word delimiters for the words A."
  (concat "\\<" (regexp-opt a t) "\\>"))

(defun verilog-font-customize ()
  "Customize fonts used by Verilog-Mode."
  (interactive)
  (customize-apropos "font-lock-*" 'faces))

(defun verilog-insert-last-command-event ()
  "Insert the `last-command-event'."
  (insert last-command-event))

(defvar verilog-no-change-functions nil
  "True if `after-change-functions' is disabled.
Use of `syntax-ppss' may break, as ppss's cache may get corrupted.")

(defvar verilog-in-hooks nil
  "True when within a `verilog-run-hooks' block.")

(defmacro verilog-run-hooks (&rest hooks)
  "Run each hook in HOOKS using `run-hooks'.
Set `verilog-in-hooks' during this time, to assist AUTO caches."
  `(let ((verilog-in-hooks t))
     (run-hooks ,@hooks)))

(defun verilog-syntax-ppss (&optional pos)
  (when verilog-no-change-functions
    (if verilog-in-hooks
        (verilog-scan-cache-flush)
      ;; else don't let the AUTO code itself get away with flushing the cache,
      ;; as that'll make things very slow
      (backtrace)
      (error "%s: Internal problem; use of syntax-ppss when cache may be corrupt"
             (verilog-point-text))))
  (syntax-ppss pos))

(defgroup verilog-mode nil
  "Major mode for Verilog source code."
  :version "26.2"
  :group 'languages)

(defgroup verilog-mode-indent nil
  "Customize indentation and highlighting of Verilog source text."
  :group 'verilog-mode)

(defgroup verilog-mode-actions nil
  "Customize actions on Verilog source text."
  :group 'verilog-mode)

(defgroup verilog-mode-auto nil
  "Customize AUTO actions when expanding Verilog source text."
  :group 'verilog-mode)

(defvar verilog-debug nil
  "Non-nil means enable debug messages for `verilog-mode' internals.")

(defcustom verilog-highlight-translate-off nil
  "Non-nil means background-highlight code excluded from translation.
That is, all code between \"// synopsys translate_off\" and
\"// synopsys translate_on\" is highlighted using a different background color
\(face `verilog-font-lock-translate-off-face').

Note: This will slow down on-the-fly fontification (and thus editing).

Note: Activate the new setting in a Verilog buffer by re-fontifying it (menu
entry \"Fontify Buffer\").  XEmacs: turn off and on font locking."
  :type 'boolean
  :group 'verilog-mode-indent)
;; Note we don't use :safe, as that would break on Emacsen before 22.0.
(put 'verilog-highlight-translate-off 'safe-local-variable 'booleanp)

(defcustom verilog-auto-lineup 'declarations
  "Type of statements to lineup across multiple lines.
If `all' is selected, then all line ups described below are done.

If `declarations', then just declarations are lined up with any
preceding declarations, taking into account widths and the like,
so or example the code:
  reg [31:0] a;
  reg b;
would become
  reg [31:0] a;
  reg        b;

If `assignment', then assignments are lined up with any preceding
assignments, so for example the code
  a_long_variable <= b + c;
  d = e + f;
would become
  a_long_variable <= b + c;
  d                = e + f;

In order to speed up editing, large blocks of statements are lined up
only when a \\[verilog-pretty-expr] is typed; and large blocks of declarations
are lineup only when \\[verilog-pretty-declarations] is typed."

  :type '(radio (const :tag "Line up Assignments and Declarations" all)
                (const :tag "Line up Assignment statements" assignments )
                (const :tag "Line up Declarations" declarations)
                (function :tag "Other"))
  :group 'verilog-mode-indent )
(put 'verilog-auto-lineup 'safe-local-variable
     '(lambda (x) (memq x '(nil all assignments declarations))))

(defcustom verilog-indent-level 3
  "Indentation of Verilog statements with respect to containing block."
  :group 'verilog-mode-indent
  :type 'integer)
(put 'verilog-indent-level 'safe-local-variable 'integerp)

(defcustom verilog-indent-level-module 3
  "Indentation of Module level Verilog statements (eg always, initial).
Set to 0 to get initial and always statements lined up on the left side of
your screen."
  :group 'verilog-mode-indent
  :type 'integer)
(put 'verilog-indent-level-module 'safe-local-variable 'integerp)

(defcustom verilog-indent-level-declaration 3
  "Indentation of declarations with respect to containing block.
Set to 0 to get them list right under containing block."
  :group 'verilog-mode-indent
  :type 'integer)
(put 'verilog-indent-level-declaration 'safe-local-variable 'integerp)

(defcustom verilog-indent-declaration-macros nil
  "How to treat macro expansions in a declaration.
If nil, indent as:
  input [31:0] a;
  input        \\=`CP;
  output       c;
If non nil, treat as:
  input [31:0] a;
  input \\=`CP    ;
  output       c;"
  :group 'verilog-mode-indent
  :type 'boolean)
(put 'verilog-indent-declaration-macros 'safe-local-variable 'booleanp)

(defcustom verilog-indent-lists t
  "How to treat indenting items in a list.
If t (the default), indent as:
  always @( posedge a or
            reset ) begin

If nil, treat as:
  always @( posedge a or
     reset ) begin"
  :group 'verilog-mode-indent
  :type 'boolean)
(put 'verilog-indent-lists 'safe-local-variable 'booleanp)

(defcustom verilog-indent-level-behavioral 3
  "Absolute indentation of first begin in a task or function block.
Set to 0 to get such code to start at the left side of the screen."
  :group 'verilog-mode-indent
  :type 'integer)
(put 'verilog-indent-level-behavioral 'safe-local-variable 'integerp)

(defcustom verilog-indent-level-directive 1
  "Indentation to add to each level of \\=`ifdef declarations.
Set to 0 to have all directives start at the left side of the screen."
  :group 'verilog-mode-indent
  :type 'integer)
(put 'verilog-indent-level-directive 'safe-local-variable 'integerp)

(defcustom verilog-cexp-indent 2
  "Indentation of Verilog statements split across lines."
  :group 'verilog-mode-indent
  :type 'integer)
(put 'verilog-cexp-indent 'safe-local-variable 'integerp)

(defcustom verilog-case-indent 2
  "Indentation for case statements."
  :group 'verilog-mode-indent
  :type 'integer)
(put 'verilog-case-indent 'safe-local-variable 'integerp)

(defcustom verilog-indent-on-newline t
  "Non-nil means automatically indent line after newline."
  :group 'verilog-mode-indent
  :type 'boolean)
(put 'verilog-indent-on-newline 'safe-local-variable 'booleanp)

(defcustom verilog-tab-always-indent t
  "Non-nil means TAB should always re-indent the current line.
A nil value means TAB will only reindent when at the beginning of the line."
  :group 'verilog-mode-indent
  :type 'boolean)
(put 'verilog-tab-always-indent 'safe-local-variable 'booleanp)

(defcustom verilog-tab-to-comment nil
  "Non-nil means TAB moves to the right hand column in preparation for a comment."
  :group 'verilog-mode-actions
  :type 'boolean)
(put 'verilog-tab-to-comment 'safe-local-variable 'booleanp)

(defcustom verilog-indent-begin-after-if t
  "Non-nil means indent begin statements following if, else, while, etc.
Otherwise, line them up."
  :group 'verilog-mode-indent
  :type 'boolean)
(put 'verilog-indent-begin-after-if 'safe-local-variable 'booleanp)

(defcustom verilog-align-ifelse nil
  "Non-nil means align `else' under matching `if'.
Otherwise else is lined up with first character on line holding matching if."
  :group 'verilog-mode-indent
  :type 'boolean)
(put 'verilog-align-ifelse 'safe-local-variable 'booleanp)

(defcustom verilog-minimum-comment-distance 10
  "Minimum distance (in lines) between begin and end required before a comment.
Setting this variable to zero results in every end acquiring a comment; the
default avoids too many redundant comments in tight quarters."
  :group 'verilog-mode-indent
  :type 'integer)
(put 'verilog-minimum-comment-distance 'safe-local-variable 'integerp)

(defcustom verilog-highlight-p1800-keywords nil
  "Non-nil means highlight words newly reserved by IEEE-1800.
These will appear in `verilog-font-lock-p1800-face' in order to gently
suggest changing where these words are used as variables to something else.
A nil value means highlight these words as appropriate for the SystemVerilog
IEEE-1800 standard.  Note that changing this will require restarting Emacs
to see the effect as font color choices are cached by Emacs."
  :group 'verilog-mode-indent
  :type 'boolean)
(put 'verilog-highlight-p1800-keywords 'safe-local-variable 'booleanp)

(defcustom verilog-highlight-grouping-keywords nil
  "Non-nil means highlight grouping keywords more dramatically.
If false, these words are in the `font-lock-type-face'; if True
then they are in `verilog-font-lock-grouping-keywords-face'.
Some find that special highlighting on these grouping constructs
allow the structure of the code to be understood at a glance."
  :group 'verilog-mode-indent
  :type 'boolean)
(put 'verilog-highlight-grouping-keywords 'safe-local-variable 'booleanp)

(defcustom verilog-highlight-modules nil
  "Non-nil means highlight module statements for `verilog-load-file-at-point'.
When true, mousing over module names will allow jumping to the
module definition.  If false, this is not supported.  Setting
this is experimental, and may lead to bad performance."
  :group 'verilog-mode-indent
  :type 'boolean)
(put 'verilog-highlight-modules 'safe-local-variable 'booleanp)

(defcustom verilog-highlight-includes t
  "Non-nil means highlight module statements for `verilog-load-file-at-point'.
When true, mousing over include file names will allow jumping to the
file referenced.  If false, this is not supported."
  :group 'verilog-mode-indent
  :type 'boolean)
(put 'verilog-highlight-includes 'safe-local-variable 'booleanp)

(defcustom verilog-library-flags '("")
  "List of standard Verilog arguments to use for /*AUTOINST*/.
These arguments are used to find files for `verilog-auto', and match
the flags accepted by a standard Verilog-XL simulator.

    -f filename     Reads absolute `verilog-library-flags' from the filename.
    -F filename     Reads relative `verilog-library-flags' from the filename.
    +incdir+dir     Adds the directory to `verilog-library-directories'.
    -Idir           Adds the directory to `verilog-library-directories'.
    -y dir          Adds the directory to `verilog-library-directories'.
    +libext+.v      Adds the extensions to `verilog-library-extensions'.
    -v filename     Adds the filename to `verilog-library-files'.

    filename        Adds the filename to `verilog-library-files'.
                    This is not recommended, -v is a better choice.

You might want these defined in each file; put at the *END* of your file
something like:

    // Local Variables:
    // verilog-library-flags:(\"-y dir -y otherdir\")
    // End:

Verilog-mode attempts to detect changes to this local variable, but they
are only insured to be correct when the file is first visited.  Thus if you
have problems, use \\[find-alternate-file] RET to have these take effect.

See also the variables mentioned above."
  :group 'verilog-mode-auto
  :type '(repeat string))
(put 'verilog-library-flags 'safe-local-variable 'listp)

(defcustom verilog-library-directories '(".")
  "List of directories when looking for files for /*AUTOINST*/.
The directory may be relative to the current file, or absolute.
Environment variables are also expanded in the directory names.
Having at least the current directory is a good idea.

You might want these defined in each file; put at the *END* of your file
something like:

    // Local Variables:
    // verilog-library-directories:(\".\" \"subdir\" \"subdir2\")
    // End:

Verilog-mode attempts to detect changes to this local variable, but they
are only insured to be correct when the file is first visited.  Thus if you
have problems, use \\[find-alternate-file] RET to have these take effect.

See also `verilog-library-flags', `verilog-library-files'
and `verilog-library-extensions'."
  :group 'verilog-mode-auto
  :type '(repeat file))
(put 'verilog-library-directories 'safe-local-variable 'listp)

(defcustom verilog-library-files '()
  "List of files to search for modules.
AUTOINST will use this when it needs to resolve a module name.
This is a complete path, usually to a technology file with many standard
cells defined in it.

You might want these defined in each file; put at the *END* of your file
something like:

    // Local Variables:
    // verilog-library-files:(\"/some/path/technology.v\" \"/some/path/tech2.v\")
    // End:

Verilog-mode attempts to detect changes to this local variable, but they
are only insured to be correct when the file is first visited.  Thus if you
have problems, use \\[find-alternate-file] RET to have these take effect.

See also `verilog-library-flags', `verilog-library-directories'."
  :group 'verilog-mode-auto
  :type '(repeat directory))
(put 'verilog-library-files 'safe-local-variable 'listp)

(defcustom verilog-library-extensions '(".v" ".sv")
  "List of extensions to use when looking for files for /*AUTOINST*/.
See also `verilog-library-flags', `verilog-library-directories'."
  :type '(repeat string)
  :group 'verilog-mode-auto)
(put 'verilog-library-extensions 'safe-local-variable 'listp)

(defcustom verilog-case-fold t
  "Non-nil means `verilog-mode' regexps should ignore case.
This variable is t for backward compatibility; nil is suggested."
  :version "24.4"
  :group 'verilog-mode
  :type 'boolean)
(put 'verilog-case-fold 'safe-local-variable 'booleanp)

(defcustom verilog-typedef-regexp nil
  "If non-nil, regular expression that matches Verilog-2001 typedef names.
For example, \"_t$\" matches typedefs named with _t, as in the C language.
See also `verilog-case-fold'."
  :group 'verilog-mode-auto
  :type '(choice (const nil) regexp))
(put 'verilog-typedef-regexp 'safe-local-variable 'stringp)

(defcustom verilog-mode-hook nil
  "Hook run after Verilog mode is loaded."
  :type 'hook
  :group 'verilog-mode)

(defcustom verilog-getopt-flags-hook nil
  "Hook run after `verilog-getopt-flags' determines the Verilog option lists."
  :group 'verilog-mode-auto
  :type 'hook)

(defcustom verilog-before-getopt-flags-hook nil
  "Hook run before `verilog-getopt-flags' determines the Verilog option lists."
  :group 'verilog-mode-auto
  :type 'hook)

(defcustom verilog-before-save-font-hook nil
  "Hook run before `verilog-save-font-no-change-functions' removes highlighting."
  :version "24.3"  ; rev735
  :group 'verilog-mode-auto
  :type 'hook)

(defcustom verilog-after-save-font-hook nil
  "Hook run after `verilog-save-font-no-change-functions' restores highlighting."
  :version "24.3"  ; rev735
  :group 'verilog-mode-auto
  :type 'hook)

(defvar verilog-imenu-generic-expression
  '((nil            "^\\s-*\\(?:m\\(?:odule\\|acromodule\\)\\|p\\(?:rimitive\\|rogram\\|ackage\\)\\)\\s-+\\([a-zA-Z0-9_.:]+\\)" 1)
    ("*Variables*"  "^\\s-*\\(reg\\|wire\\|logic\\)\\s-+\\(\\|\\[[^]]+\\]\\s-+\\)\\([A-Za-z0-9_]+\\)" 3)
    ("*Classes*"    "^\\s-*\\(?:\\(?:virtual\\|interface\\)\\s-+\\)?class\\s-+\\([A-Za-z_][A-Za-z0-9_]+\\)" 1)
    ("*Tasks*"      "^\\s-*\\(?:\\(?:static\\|pure\\|virtual\\|local\\|protected\\)\\s-+\\)*task\\s-+\\(?:\\(?:static\\|automatic\\)\\s-+\\)?\\([A-Za-z_][A-Za-z0-9_:]+\\)" 1)
    ("*Functions*"  "^\\s-*\\(?:\\(?:static\\|pure\\|virtual\\|local\\|protected\\)\\s-+\\)*function\\s-+\\(?:\\(?:static\\|automatic\\)\\s-+\\)?\\(?:\\w+\\s-+\\)?\\(?:\\(?:un\\)signed\\s-+\\)?\\([A-Za-z_][A-Za-z0-9_:]+\\)" 1)
    ("*Interfaces*" "^\\s-*interface\\s-+\\([a-zA-Z_0-9]+\\)" 1)
    ("*Types*"      "^\\s-*typedef\\s-+.*\\s-+\\([a-zA-Z_0-9]+\\)\\s-*;" 1))
  "Imenu expression for Verilog mode.  See `imenu-generic-expression'.")

;;; Keymap:
;;

(defvar verilog-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map ";"        'electric-verilog-semi)
    (define-key map [(control 59)]    'electric-verilog-semi-with-comment)
    (define-key map ":"        'electric-verilog-colon)
    ;;(define-key map "="        'electric-verilog-equal)
    (define-key map "`"        'electric-verilog-tick)
    (define-key map "\t"       'electric-verilog-tab)
    (define-key map "\r"       'electric-verilog-terminate-line)
    ;; backspace/delete key bindings
    (define-key map [backspace]    'backward-delete-char-untabify)
    (define-key map [delete]       'delete-char)
    (define-key map [(meta delete)] 'kill-word)
    (define-key map "\M-\C-b"  'electric-verilog-backward-sexp)
    (define-key map "\M-\C-f"  'electric-verilog-forward-sexp)
    (define-key map "\M-\r"    `electric-verilog-terminate-and-indent)
    (define-key map "\M-\t"    (if (fboundp 'completion-at-point)
                                   'completion-at-point 'verilog-complete-word))
    (define-key map "\M-?"     (if (fboundp 'completion-help-at-point)
                                   'completion-help-at-point 'verilog-show-completions))
    ;; Note \C-c and letter are reserved for users
    (define-key map "\C-c`"    'verilog-lint-off)
    (define-key map "\C-c*"    'verilog-delete-auto-star-implicit)
    (define-key map "\C-c?"    'verilog-diff-auto)
    (define-key map "\C-c\C-r" 'verilog-label-be)
    (define-key map "\C-c\C-i" 'verilog-pretty-declarations)
    (define-key map "\C-c="    'verilog-pretty-expr)
    (define-key map "\C-c\C-b" 'verilog-submit-bug-report)
    (define-key map "\C-c/"    'verilog-star-comment)
    (define-key map "\C-c\C-c" 'verilog-comment-region)
    (define-key map "\C-c\C-u" 'verilog-uncomment-region)
    (define-key map "\C-c\C-d" 'verilog-goto-defun)
    (define-key map "\C-c\C-k" 'verilog-delete-auto)
    (define-key map "\C-c\C-a" 'verilog-auto)
    (define-key map "\C-c\C-z" 'verilog-inject-auto)
    (define-key map "\C-c\C-e" 'verilog-expand-vector)
    (define-key map "\C-c\C-h" 'verilog-header)
    map)
  "Keymap used in Verilog mode.")

(defvar verilog-mode-abbrev-table nil
  "Abbrev table in use in Verilog-mode buffers.")

;;
;;  Macros
;;

(defsubst verilog-within-string-p ()
  (nth 3 (syntax-ppss)))

(defsubst verilog-string-match-fold (regexp string &optional start)
  "Like `string-match', but use `verilog-case-fold'.
Return index of start of first match for REGEXP in STRING, or nil.
Matching ignores case if `verilog-case-fold' is non-nil.
If third arg START is non-nil, start search at that index in STRING."
  (let ((case-fold-search verilog-case-fold))
    (string-match regexp string start)))

(defsubst verilog-string-replace-matches (from-string to-string fixedcase literal string)
  "Replace occurrences of FROM-STRING with TO-STRING.
FIXEDCASE and LITERAL as in `replace-match'.  STRING is what to replace.
The case (verilog-string-replace-matches \"o\" \"oo\" nil nil \"foobar\")
will break, as the o's continuously replace.  xa -> x works ok though."
  ;; Hopefully soon to an Emacs built-in
  ;; Also note \ in the replacement prevent multiple replacements; IE
  ;;   (verilog-string-replace-matches "@" "\\\\([0-9]+\\\\)" nil nil "wire@_@")
  ;;   Gives "wire\([0-9]+\)_@" not "wire\([0-9]+\)_\([0-9]+\)"
  (let ((start 0))
    (while (string-match from-string string start)
      (setq string (replace-match to-string fixedcase literal string)
            start (min (length string) (+ (match-beginning 0) (length to-string)))))
    string))

(defsubst verilog-re-search-forward (REGEXP BOUND NOERROR)
  ;; checkdoc-params: (REGEXP BOUND NOERROR)
  "Like `re-search-forward', but skips over match in comments or strings."
  (let ((mdata '(nil nil)))  ; So match-end will return nil if no matches found
    (while (and (re-search-forward REGEXP BOUND NOERROR)
                (setq mdata (match-data))
                (and (verilog-skip-forward-comment-or-string)
                     (progn
                       (setq mdata '(nil nil))
                       (if BOUND
                           (< (point) BOUND)
                         t)))))
    (store-match-data mdata)
    (match-end 0)))

(defsubst verilog-re-search-backward (REGEXP BOUND NOERROR)
  ;; checkdoc-params: (REGEXP BOUND NOERROR)
  "Like `re-search-backward', but skips over match in comments or strings."
  (let ((mdata '(nil nil)))  ; So match-end will return nil if no matches found
    (while (and
            (re-search-backward REGEXP BOUND NOERROR)
            (setq mdata (match-data))
            (and (verilog-skip-backward-comment-or-string)
                 (progn
                   (setq mdata '(nil nil))
                   (if BOUND
                       (> (point) BOUND)
                     t)))))
    (store-match-data mdata)
    (match-end 0)))

(defsubst verilog-re-search-forward-quick (regexp bound noerror)
  "Like `verilog-re-search-forward', including use of REGEXP BOUND and NOERROR,
but trashes match data and is faster for REGEXP that doesn't match often.
This uses `verilog-scan' and text properties to ignore comments,
so there may be a large up front penalty for the first search."
  (let (pt)
    (while (and (not pt)
                (re-search-forward regexp bound noerror))
      (if (verilog-inside-comment-or-string-p (match-beginning 0))
          (re-search-forward "[/\"\n]" nil t)  ; Only way a comment or quote can end
        (setq pt (match-end 0))))
    pt))

(defsubst verilog-re-search-backward-quick (regexp bound noerror)
  ;; checkdoc-params: (REGEXP BOUND NOERROR)
  "Like `verilog-re-search-backward', including use of REGEXP BOUND and NOERROR,
but trashes match data and is faster for REGEXP that doesn't match often.
This uses `verilog-scan' and text properties to ignore comments,
so there may be a large up front penalty for the first search."
  (let (pt)
    (while (and (not pt)
                (re-search-backward regexp bound noerror))
      (if (verilog-inside-comment-or-string-p (match-beginning 0))
          (re-search-backward "[/\"]" nil t)  ; Only way a comment or quote can begin
        (setq pt (match-beginning 0))))
    pt))

(defsubst verilog-re-search-forward-substr (substr regexp bound noerror)
  "Like `re-search-forward', but first search for SUBSTR constant.
Then searched for the normal REGEXP (which contains SUBSTR), with given
BOUND and NOERROR.  The REGEXP must fit within a single line.
This speeds up complicated regexp matches."
  ;; Problem with overlap: search-forward BAR then FOOBARBAZ won't match.
  ;; thus require matches to be on one line, and use beginning-of-line.
  (let (done)
    (while (and (not done)
                (search-forward substr bound noerror))
      (save-excursion
        (beginning-of-line)
        (setq done (re-search-forward regexp (point-at-eol) noerror)))
      (unless (and (<= (match-beginning 0) (point))
                   (>= (match-end 0) (point)))
        (setq done nil)))
    (when done (goto-char done))
    done))
;;(verilog-re-search-forward-substr "-end" "get-end-of" nil t)  ; -end (test bait)

(defsubst verilog-re-search-backward-substr (substr regexp bound noerror)
  "Like `re-search-backward', but first search for SUBSTR constant.
Then searched for the normal REGEXP (which contains SUBSTR), with given
BOUND and NOERROR.  The REGEXP must fit within a single line.
This speeds up complicated regexp matches."
  ;; Problem with overlap: search-backward BAR then FOOBARBAZ won't match.
  ;; thus require matches to be on one line, and use beginning-of-line.
  (let (done)
    (while (and (not done)
                (search-backward substr bound noerror))
      (save-excursion
        (end-of-line)
        (setq done (re-search-backward regexp (point-at-bol) noerror)))
      (unless (and (<= (match-beginning 0) (point))
                   (>= (match-end 0) (point)))
        (setq done nil)))
    (when done (goto-char done))
    done))
;;(verilog-re-search-backward-substr "-end" "get-end-of" nil t)  ; -end (test bait)

(defun verilog-delete-trailing-whitespace ()
  "Delete trailing spaces or tabs, but not newlines nor linefeeds.
Also add missing final newline.

To call this from the command line, see \\[verilog-batch-diff-auto].

To call on \\[verilog-auto], set `verilog-auto-delete-trailing-whitespace'."
  ;; Similar to `delete-trailing-whitespace' but that's not present in XEmacs
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "[ \t]+$" nil t)  ; Not syntactic WS as no formfeed
      (replace-match "" nil nil))
    (goto-char (point-max))
    (unless (bolp) (insert "\n"))))

(defvar compile-command)
(defvar create-lockfiles)  ; Emacs 24

(defun verilog-expand-command (command)
  "Replace meta-information in COMMAND and return it.
Where __FLAGS__ appears in the string `verilog-current-flags'
will be substituted.  Where __FILE__ appears in the string, the
current buffer's file-name, without the directory portion, will
be substituted."
  (setq command	(verilog-string-replace-matches
                 ;; Note \\b only works if under verilog syntax table
                 "\\b__FLAGS__\\b" (verilog-current-flags)
                 t t command))
  (setq command	(verilog-string-replace-matches
                 "\\b__FILE__\\b" (file-name-nondirectory
                                   (or (buffer-file-name) ""))
                 t t command))
  command)

;; Eliminate compile warning
(defvar verilog-compile-command-pre-mod)
(defvar verilog-compile-command-post-mod)

(defun verilog-modify-compile-command ()
  "Update `compile-command' using `verilog-expand-command'."
  ;; Entry into verilog-mode a call to this before Local Variables exist
  ;; Likewise user may have hook or something that changes the flags.
  ;; So, remember we're responsible for the expansion and on re-entry
  ;; recompute __FLAGS__ on each reentry.
  (when (stringp compile-command)
    (when (and
           (boundp 'verilog-compile-command-post-mod)
           (equal compile-command verilog-compile-command-post-mod))
      (setq compile-command verilog-compile-command-pre-mod))
    (when (and
           (string-match "\\b\\(__FLAGS__\\|__FILE__\\)\\b" compile-command))
      (set (make-local-variable 'verilog-compile-command-pre-mod)
           compile-command)
      (set (make-local-variable 'compile-command)
           (verilog-expand-command compile-command))
      (set (make-local-variable 'verilog-compile-command-post-mod)
           compile-command))))

(defconst verilog-compiler-directives
  (eval-when-compile
    '(
      ;; compiler directives, from IEEE 1800-2012 section 22.1
      "`__FILE__" "`__LINE" "`begin_keywords" "`celldefine" "`default_nettype"
      "`define" "`else" "`elsif" "`end_keywords" "`endcelldefine" "`endif"
      "`ifdef" "`ifndef" "`include" "`line" "`nounconnected_drive" "`pragma"
      "`resetall" "`timescale" "`unconnected_drive" "`undef" "`undefineall"
      ;; compiler directives not covered by IEEE 1800
      "`case" "`default" "`endfor" "`endprotect" "`endswitch" "`endwhile" "`for"
      "`format" "`if" "`let" "`protect" "`switch" "`timescale" "`time_scale"
      "`while"
      ))
  "List of Verilog compiler directives.")

(defconst verilog-directive-re
  (verilog-regexp-words verilog-compiler-directives))

(defconst verilog-directive-re-1
  (concat "[ \t]*"  verilog-directive-re))

(defconst verilog-directive-begin
  "\\<`\\(for\\|i\\(f\\|fdef\\|fndef\\)\\|switch\\|while\\)\\>")

(defconst verilog-directive-middle
  "\\<`\\(else\\|elsif\\|default\\|case\\)\\>")

(defconst verilog-directive-end
  "`\\(endfor\\|endif\\|endswitch\\|endwhile\\)\\>")

(defconst verilog-ovm-begin-re
  (eval-when-compile
    (regexp-opt
     '(
       "`ovm_component_utils_begin"
       "`ovm_component_param_utils_begin"
       "`ovm_field_utils_begin"
       "`ovm_object_utils_begin"
       "`ovm_object_param_utils_begin"
       "`ovm_sequence_utils_begin"
       "`ovm_sequencer_utils_begin"
       ) nil )))

(defconst verilog-ovm-end-re
  (eval-when-compile
    (regexp-opt
     '(
       "`ovm_component_utils_end"
       "`ovm_field_utils_end"
       "`ovm_object_utils_end"
       "`ovm_sequence_utils_end"
       "`ovm_sequencer_utils_end"
       ) nil )))

(defconst verilog-uvm-begin-re
  (eval-when-compile
    (regexp-opt
     '(
       "`uvm_component_utils_begin"
       "`uvm_component_param_utils_begin"
       "`uvm_field_utils_begin"
       "`uvm_object_utils_begin"
       "`uvm_object_param_utils_begin"
       "`uvm_sequence_utils_begin"
       "`uvm_sequencer_utils_begin"
       ) nil )))

(defconst verilog-uvm-end-re
  (eval-when-compile
    (regexp-opt
     '(
       "`uvm_component_utils_end"
       "`uvm_field_utils_end"
       "`uvm_object_utils_end"
       "`uvm_sequence_utils_end"
       "`uvm_sequencer_utils_end"
       ) nil )))

(defconst verilog-vmm-begin-re
  (eval-when-compile
    (regexp-opt
     '(
       "`vmm_data_member_begin"
       "`vmm_env_member_begin"
       "`vmm_scenario_member_begin"
       "`vmm_subenv_member_begin"
       "`vmm_xactor_member_begin"
       ) nil ) ) )

(defconst verilog-vmm-end-re
  (eval-when-compile
    (regexp-opt
     '(
       "`vmm_data_member_end"
       "`vmm_env_member_end"
       "`vmm_scenario_member_end"
       "`vmm_subenv_member_end"
       "`vmm_xactor_member_end"
       ) nil ) ) )

(defconst verilog-vmm-statement-re
  (eval-when-compile
    (regexp-opt
     '(
       "`vmm_\\(data\\|env\\|scenario\\|subenv\\|xactor\\)_member_\\(scalar\\|string\\|enum\\|vmm_data\\|channel\\|xactor\\|subenv\\|user_defined\\)\\(_array\\)?"
       ;; "`vmm_xactor_member_enum_array"
       ;; "`vmm_xactor_member_scalar_array"
       ;; "`vmm_xactor_member_scalar"
       ) nil )))

(defconst verilog-ovm-statement-re
  (eval-when-compile
    (regexp-opt
     '(
       ;; Statements
       "`DUT_ERROR"
       "`MESSAGE"
       "`dut_error"
       "`message"
       "`ovm_analysis_imp_decl"
       "`ovm_blocking_get_imp_decl"
       "`ovm_blocking_get_peek_imp_decl"
       "`ovm_blocking_master_imp_decl"
       "`ovm_blocking_peek_imp_decl"
       "`ovm_blocking_put_imp_decl"
       "`ovm_blocking_slave_imp_decl"
       "`ovm_blocking_transport_imp_decl"
       "`ovm_component_registry"
       "`ovm_component_registry_param"
       "`ovm_component_utils"
       "`ovm_create"
       "`ovm_create_seq"
       "`ovm_declare_sequence_lib"
       "`ovm_do"
       "`ovm_do_seq"
       "`ovm_do_seq_with"
       "`ovm_do_with"
       "`ovm_error"
       "`ovm_fatal"
       "`ovm_field_aa_int_byte"
       "`ovm_field_aa_int_byte_unsigned"
       "`ovm_field_aa_int_int"
       "`ovm_field_aa_int_int_unsigned"
       "`ovm_field_aa_int_integer"
       "`ovm_field_aa_int_integer_unsigned"
       "`ovm_field_aa_int_key"
       "`ovm_field_aa_int_longint"
       "`ovm_field_aa_int_longint_unsigned"
       "`ovm_field_aa_int_shortint"
       "`ovm_field_aa_int_shortint_unsigned"
       "`ovm_field_aa_int_string"
       "`ovm_field_aa_object_int"
       "`ovm_field_aa_object_string"
       "`ovm_field_aa_string_int"
       "`ovm_field_aa_string_string"
       "`ovm_field_array_int"
       "`ovm_field_array_object"
       "`ovm_field_array_string"
       "`ovm_field_enum"
       "`ovm_field_event"
       "`ovm_field_int"
       "`ovm_field_object"
       "`ovm_field_queue_int"
       "`ovm_field_queue_object"
       "`ovm_field_queue_string"
       "`ovm_field_sarray_int"
       "`ovm_field_string"
       "`ovm_field_utils"
       "`ovm_file"
       "`ovm_get_imp_decl"
       "`ovm_get_peek_imp_decl"
       "`ovm_info"
       "`ovm_info1"
       "`ovm_info2"
       "`ovm_info3"
       "`ovm_info4"
       "`ovm_line"
       "`ovm_master_imp_decl"
       "`ovm_msg_detail"
       "`ovm_non_blocking_transport_imp_decl"
       "`ovm_nonblocking_get_imp_decl"
       "`ovm_nonblocking_get_peek_imp_decl"
       "`ovm_nonblocking_master_imp_decl"
       "`ovm_nonblocking_peek_imp_decl"
       "`ovm_nonblocking_put_imp_decl"
       "`ovm_nonblocking_slave_imp_decl"
       "`ovm_object_registry"
       "`ovm_object_registry_param"
       "`ovm_object_utils"
       "`ovm_peek_imp_decl"
       "`ovm_phase_func_decl"
       "`ovm_phase_task_decl"
       "`ovm_print_aa_int_object"
       "`ovm_print_aa_string_int"
       "`ovm_print_aa_string_object"
       "`ovm_print_aa_string_string"
       "`ovm_print_array_int"
       "`ovm_print_array_object"
       "`ovm_print_array_string"
       "`ovm_print_object_queue"
       "`ovm_print_queue_int"
       "`ovm_print_string_queue"
       "`ovm_put_imp_decl"
       "`ovm_rand_send"
       "`ovm_rand_send_with"
       "`ovm_send"
       "`ovm_sequence_utils"
       "`ovm_slave_imp_decl"
       "`ovm_transport_imp_decl"
       "`ovm_update_sequence_lib"
       "`ovm_update_sequence_lib_and_item"
       "`ovm_warning"
       "`static_dut_error"
       "`static_message") nil )))

(defconst verilog-uvm-statement-re
  (eval-when-compile
    (regexp-opt
     '(
       ;; Statements
       "`uvm_analysis_imp_decl"
       "`uvm_blocking_get_imp_decl"
       "`uvm_blocking_get_peek_imp_decl"
       "`uvm_blocking_master_imp_decl"
       "`uvm_blocking_peek_imp_decl"
       "`uvm_blocking_put_imp_decl"
       "`uvm_blocking_slave_imp_decl"
       "`uvm_blocking_transport_imp_decl"
       "`uvm_component_param_utils"
       "`uvm_component_registry"
       "`uvm_component_registry_param"
       "`uvm_component_utils"
       "`uvm_create"
       "`uvm_create_on"
       "`uvm_create_seq"                ; Undocumented in 1.1
       "`uvm_declare_p_sequencer"
       "`uvm_declare_sequence_lib"      ; Deprecated in 1.1
       "`uvm_do"
       "`uvm_do_callbacks"
       "`uvm_do_callbacks_exit_on"
       "`uvm_do_obj_callbacks"
       "`uvm_do_obj_callbacks_exit_on"
       "`uvm_do_on"
       "`uvm_do_on_pri"
       "`uvm_do_on_pri_with"
       "`uvm_do_on_with"
       "`uvm_do_pri"
       "`uvm_do_pri_with"
       "`uvm_do_seq"                    ; Undocumented in 1.1
       "`uvm_do_seq_with"               ; Undocumented in 1.1
       "`uvm_do_with"
       "`uvm_error"
       "`uvm_error_context"
       "`uvm_fatal"
       "`uvm_fatal_context"
       "`uvm_field_aa_int_byte"
       "`uvm_field_aa_int_byte_unsigned"
       "`uvm_field_aa_int_enum"
       "`uvm_field_aa_int_int"
       "`uvm_field_aa_int_int_unsigned"
       "`uvm_field_aa_int_integer"
       "`uvm_field_aa_int_integer_unsigned"
       "`uvm_field_aa_int_key"
       "`uvm_field_aa_int_longint"
       "`uvm_field_aa_int_longint_unsigned"
       "`uvm_field_aa_int_shortint"
       "`uvm_field_aa_int_shortint_unsigned"
       "`uvm_field_aa_int_string"
       "`uvm_field_aa_object_int"
       "`uvm_field_aa_object_string"
       "`uvm_field_aa_string_int"
       "`uvm_field_aa_string_string"
       "`uvm_field_array_enum"
       "`uvm_field_array_int"
       "`uvm_field_array_object"
       "`uvm_field_array_string"
       "`uvm_field_enum"
       "`uvm_field_event"
       "`uvm_field_int"
       "`uvm_field_object"
       "`uvm_field_queue_enum"
       "`uvm_field_queue_int"
       "`uvm_field_queue_object"
       "`uvm_field_queue_string"
       "`uvm_field_real"
       "`uvm_field_sarray_enum"
       "`uvm_field_sarray_int"
       "`uvm_field_sarray_object"
       "`uvm_field_sarray_string"
       "`uvm_field_string"
       "`uvm_field_utils"
       "`uvm_file"              ; Undocumented in 1.1, use `__FILE__
       "`uvm_get_imp_decl"
       "`uvm_get_peek_imp_decl"
       "`uvm_info"
       "`uvm_info_context"
       "`uvm_line"              ; Undocumented in 1.1, use `__LINE__
       "`uvm_master_imp_decl"
       "`uvm_non_blocking_transport_imp_decl"   ; Deprecated in 1.1
       "`uvm_nonblocking_get_imp_decl"
       "`uvm_nonblocking_get_peek_imp_decl"
       "`uvm_nonblocking_master_imp_decl"
       "`uvm_nonblocking_peek_imp_decl"
       "`uvm_nonblocking_put_imp_decl"
       "`uvm_nonblocking_slave_imp_decl"
       "`uvm_nonblocking_transport_imp_decl"
       "`uvm_object_param_utils"
       "`uvm_object_registry"
       "`uvm_object_registry_param"     ; Undocumented in 1.1
       "`uvm_object_utils"
       "`uvm_pack_array"
       "`uvm_pack_arrayN"
       "`uvm_pack_enum"
       "`uvm_pack_enumN"
       "`uvm_pack_int"
       "`uvm_pack_intN"
       "`uvm_pack_queue"
       "`uvm_pack_queueN"
       "`uvm_pack_real"
       "`uvm_pack_sarray"
       "`uvm_pack_sarrayN"
       "`uvm_pack_string"
       "`uvm_peek_imp_decl"
       "`uvm_put_imp_decl"
       "`uvm_rand_send"
       "`uvm_rand_send_pri"
       "`uvm_rand_send_pri_with"
       "`uvm_rand_send_with"
       "`uvm_record_attribute"
       "`uvm_record_field"
       "`uvm_register_cb"
       "`uvm_send"
       "`uvm_send_pri"
       "`uvm_sequence_utils"            ; Deprecated in 1.1
       "`uvm_set_super_type"
       "`uvm_slave_imp_decl"
       "`uvm_transport_imp_decl"
       "`uvm_unpack_array"
       "`uvm_unpack_arrayN"
       "`uvm_unpack_enum"
       "`uvm_unpack_enumN"
       "`uvm_unpack_int"
       "`uvm_unpack_intN"
       "`uvm_unpack_queue"
       "`uvm_unpack_queueN"
       "`uvm_unpack_real"
       "`uvm_unpack_sarray"
       "`uvm_unpack_sarrayN"
       "`uvm_unpack_string"
       "`uvm_update_sequence_lib"               ; Deprecated in 1.1
       "`uvm_update_sequence_lib_and_item"      ; Deprecated in 1.1
       "`uvm_warning"
       "`uvm_warning_context") nil )))


;;
;; Regular expressions used to calculate indent, etc.
;;
(defconst verilog-symbol-re      "\\<[a-zA-Z_][a-zA-Z_0-9.]*\\>")
;; Want to match
;; aa :
;; aa,bb :
;; a[34:32] :
;; a,
;;   b :
(defconst verilog-assignment-operator-re
  (eval-when-compile
    (regexp-opt
     `(
       ;; blocking assignment_operator
       "=" "+=" "-=" "*=" "/=" "%=" "&=" "|=" "^=" "<<=" ">>=" "<<<=" ">>>="
       ;; non blocking assignment operator
       "<="
       ;; comparison
       "==" "!=" "===" "!==" "<=" ">=" "==?" "!=?" "<->"
       ;; event_trigger
       "->" "->>"
       ;; property_expr
       "|->" "|=>" "#-#" "#=#"
       ;; distribution weighting
       ":=" ":/"
       ) 't
     )))
(defconst verilog-assignment-operation-re
  (concat
   ;; "\\(^\\s-*[A-Za-z0-9_]+\\(\\[\\([A-Za-z0-9_]+\\)\\]\\)*\\s-*\\)"
   ;; "\\(^\\s-*[^=<>+-*/%&|^:\\s-]+[^=<>+-*/%&|^\n]*?\\)"
   "\\(^.*?\\)" "\\B" verilog-assignment-operator-re "\\B" ))

(defconst verilog-label-re (concat verilog-symbol-re "\\s-*:\\s-*"))
(defconst verilog-property-re
  (concat "\\(" verilog-label-re "\\)?"
          ;; "\\(assert\\|assume\\|cover\\)\\s-+property\\>"
          "\\(\\(assert\\|assume\\|cover\\)\\>\\s-+\\<property\\>\\)\\|\\(assert\\)"))

(defconst verilog-no-indent-begin-re
  (eval-when-compile
    (verilog-regexp-words
     '("always" "always_comb" "always_ff" "always_latch" "initial" "final"  ; procedural blocks
       "if" "else"                                                          ; conditional statements
       "while" "for" "foreach" "repeat" "do" "forever" ))))                 ; loop statements

(defconst verilog-ends-re
  ;; Parenthesis indicate type of keyword found
  (concat
   "\\(\\<else\\>\\)\\|"		; 1
   "\\(\\<if\\>\\)\\|"			; 2
   "\\(\\<assert\\>\\)\\|"              ; 3
   "\\(\\<end\\>\\)\\|"			; 3.1
   "\\(\\<endcase\\>\\)\\|"		; 4
   "\\(\\<endfunction\\>\\)\\|"		; 5
   "\\(\\<endtask\\>\\)\\|"		; 6
   "\\(\\<endspecify\\>\\)\\|"		; 7
   "\\(\\<endtable\\>\\)\\|"		; 8
   "\\(\\<endgenerate\\>\\)\\|"         ; 9
   "\\(\\<join\\(_any\\|_none\\)?\\>\\)\\|" ; 10
   "\\(\\<endclass\\>\\)\\|"            ; 11
   "\\(\\<endgroup\\>\\)\\|"            ; 12
   ;; VMM
   "\\(\\<`vmm_data_member_end\\>\\)\\|"
   "\\(\\<`vmm_env_member_end\\>\\)\\|"
   "\\(\\<`vmm_scenario_member_end\\>\\)\\|"
   "\\(\\<`vmm_subenv_member_end\\>\\)\\|"
   "\\(\\<`vmm_xactor_member_end\\>\\)\\|"
   ;; OVM
   "\\(\\<`ovm_component_utils_end\\>\\)\\|"
   "\\(\\<`ovm_field_utils_end\\>\\)\\|"
   "\\(\\<`ovm_object_utils_end\\>\\)\\|"
   "\\(\\<`ovm_sequence_utils_end\\>\\)\\|"
   "\\(\\<`ovm_sequencer_utils_end\\>\\)"
   ;; UVM
   "\\(\\<`uvm_component_utils_end\\>\\)\\|"
   "\\(\\<`uvm_field_utils_end\\>\\)\\|"
   "\\(\\<`uvm_object_utils_end\\>\\)\\|"
   "\\(\\<`uvm_sequence_utils_end\\>\\)\\|"
   "\\(\\<`uvm_sequencer_utils_end\\>\\)"
   ))

(defconst verilog-auto-end-comment-lines-re
  ;; Matches to names in this list cause auto-end-commenting
  (concat "\\("
          verilog-directive-re "\\)\\|\\("
          (eval-when-compile
            (verilog-regexp-words
             `( "begin"
                "else"
                "end"
                "endcase"
                "endclass"
                "endclocking"
                "endgroup"
                "endfunction"
                "endmodule"
                "endprogram"
                "endprimitive"
                "endinterface"
                "endpackage"
                "endsequence"
                "endproperty"
                "endspecify"
                "endtable"
                "endtask"
                "join"
                "join_any"
                "join_none"
                "module"
                "macromodule"
                "primitive"
                "interface"
                "package")))
          "\\)"))

;; NOTE: verilog-leap-to-head expects that verilog-end-block-re and
;; verilog-end-block-ordered-re matches exactly the same strings.
(defconst verilog-end-block-ordered-re
  ;; Parenthesis indicate type of keyword found
  (concat "\\(\\<endcase\\>\\)\\|" ; 1
          "\\(\\<end\\>\\)\\|"     ; 2
          "\\(\\<end"              ; 3, but not used
          "\\("                    ; 4, but not used
          "\\(function\\)\\|"      ; 5
          "\\(task\\)\\|"          ; 6
          "\\(module\\)\\|"        ; 7
          "\\(primitive\\)\\|"     ; 8
          "\\(interface\\)\\|"     ; 9
          "\\(package\\)\\|"       ; 10
          "\\(class\\)\\|"         ; 11
          "\\(group\\)\\|"         ; 12
          "\\(program\\)\\|"	   ; 13
          "\\(sequence\\)\\|"	   ; 14
          "\\(clocking\\)\\|"      ; 15
          "\\(property\\)\\|"      ; 16
          "\\)\\>\\)"))
(defconst verilog-end-block-re
  (eval-when-compile
    (verilog-regexp-words

     `("end"      ; closes begin
       "endcase"  ; closes any of case, casex casez or randcase
       "join" "join_any" "join_none"  ; closes fork
       "endclass"
       "endtable"
       "endspecify"
       "endfunction"
       "endgenerate"
       "endtask"
       "endgroup"
       "endproperty"
       "endsequence"
       "endclocking"
       ;; OVM
       "`ovm_component_utils_end"
       "`ovm_field_utils_end"
       "`ovm_object_utils_end"
       "`ovm_sequence_utils_end"
       "`ovm_sequencer_utils_end"
       ;; UVM
       "`uvm_component_utils_end"
       "`uvm_field_utils_end"
       "`uvm_object_utils_end"
       "`uvm_sequence_utils_end"
       "`uvm_sequencer_utils_end"
       ;; VMM
       "`vmm_data_member_end"
       "`vmm_env_member_end"
       "`vmm_scenario_member_end"
       "`vmm_subenv_member_end"
       "`vmm_xactor_member_end"
       ))))


(defconst verilog-endcomment-reason-re
  ;; Parenthesis indicate type of keyword found
  (concat
   "\\(\\<begin\\>\\)\\|"		         ; 1
   "\\(\\<else\\>\\)\\|"		         ; 2
   "\\(\\<end\\>\\s-+\\<else\\>\\)\\|"	         ; 3
   "\\(\\<always\\(?:_ff\\)?\\>\\(?:[ \t]*@\\)\\)\\|"    ; 4 (matches always or always_ff w/ @...)
   "\\(\\<always\\(?:_comb\\|_latch\\)?\\>\\)\\|"  ; 5 (matches always, always_comb, always_latch w/o @...)
   "\\(\\<fork\\>\\)\\|"			 ; 7
   "\\(\\<if\\>\\)\\|"
   verilog-property-re "\\|"
   "\\(\\(" verilog-label-re "\\)?\\<assert\\>\\)\\|"
   "\\(\\<clocking\\>\\)\\|"
   "\\(\\<task\\>\\)\\|"
   "\\(\\<function\\>\\)\\|"
   "\\(\\<initial\\>\\)\\|"
   "\\(\\<interface\\>\\)\\|"
   "\\(\\<package\\>\\)\\|"
   "\\(\\<final\\>\\)\\|"
   "\\(@\\)\\|"
   "\\(\\<while\\>\\)\\|\\(\\<do\\>\\)\\|"
   "\\(\\<for\\(ever\\|each\\)?\\>\\)\\|"
   "\\(\\<repeat\\>\\)\\|\\(\\<wait\\>\\)\\|"
   "#"))

(defconst verilog-named-block-re  "begin[ \t]*:")

;; These words begin a block which can occur inside a module which should be indented,
;; and closed with the respective word from the end-block list

(defconst verilog-beg-block-re
  (eval-when-compile
    (verilog-regexp-words
     `("begin"
       "case" "casex" "casez" "randcase"
       "clocking"
       "generate"
       "fork"
       "function"
       "property"
       "specify"
       "table"
       "task"
       ;; OVM
       "`ovm_component_utils_begin"
       "`ovm_component_param_utils_begin"
       "`ovm_field_utils_begin"
       "`ovm_object_utils_begin"
       "`ovm_object_param_utils_begin"
       "`ovm_sequence_utils_begin"
       "`ovm_sequencer_utils_begin"
       ;; UVM
       "`uvm_component_utils_begin"
       "`uvm_component_param_utils_begin"
       "`uvm_field_utils_begin"
       "`uvm_object_utils_begin"
       "`uvm_object_param_utils_begin"
       "`uvm_sequence_utils_begin"
       "`uvm_sequencer_utils_begin"
       ;; VMM
       "`vmm_data_member_begin"
       "`vmm_env_member_begin"
       "`vmm_scenario_member_begin"
       "`vmm_subenv_member_begin"
       "`vmm_xactor_member_begin"
       ))))
;; These are the same words, in a specific order in the regular
;; expression so that matching will work nicely for
;; verilog-forward-sexp and verilog-calc-indent
(defconst verilog-beg-block-re-ordered
  ( concat "\\(\\<begin\\>\\)"		;1
           "\\|\\(\\<randcase\\>\\|\\(\\<unique0?\\s-+\\|priority\\s-+\\)?case[xz]?\\>\\)" ; 2,3
           "\\|\\(\\(\\<disable\\>\\s-+\\|\\<wait\\>\\s-+\\)?fork\\>\\)" ;4,5
           "\\|\\(\\<class\\>\\)"		;6
           "\\|\\(\\<table\\>\\)"		;7
           "\\|\\(\\<specify\\>\\)"		;8
           "\\|\\(\\<function\\>\\)"		;9
           "\\|\\(\\(?:\\<\\(?:virtual\\|protected\\|static\\)\\>\\s-+\\)*\\<function\\>\\)"  ;10
           "\\|\\(\\<task\\>\\)"                ;11
           "\\|\\(\\(?:\\<\\(?:virtual\\|protected\\|static\\)\\>\\s-+\\)*\\<task\\>\\)"      ;12
           "\\|\\(\\<generate\\>\\)"            ;13
           "\\|\\(\\<covergroup\\>\\)"          ;14
           "\\|\\(\\(?:\\(?:\\<cover\\>\\s-+\\)\\|\\(?:\\<assert\\>\\s-+\\)\\)*\\<property\\>\\)" ;15
           "\\|\\(\\<\\(?:rand\\)?sequence\\>\\)" ;16
           "\\|\\(\\<clocking\\>\\)"              ;17
           "\\|\\(\\<`[ou]vm_[a-z_]+_begin\\>\\)" ;18
           "\\|\\(\\<`vmm_[a-z_]+_member_begin\\>\\)"
           ;;
           ))

(defconst verilog-end-block-ordered-rry
  [ "\\(\\<begin\\>\\)\\|\\(\\<end\\>\\)\\|\\(\\<endcase\\>\\)\\|\\(\\<join\\(_any\\|_none\\)?\\>\\)"
    "\\(\\<randcase\\>\\|\\<case[xz]?\\>\\)\\|\\(\\<endcase\\>\\)"
    "\\(\\<fork\\>\\)\\|\\(\\<join\\(_any\\|_none\\)?\\>\\)"
    "\\(\\<class\\>\\)\\|\\(\\<endclass\\>\\)"
    "\\(\\<table\\>\\)\\|\\(\\<endtable\\>\\)"
    "\\(\\<specify\\>\\)\\|\\(\\<endspecify\\>\\)"
    "\\(\\<function\\>\\)\\|\\(\\<endfunction\\>\\)"
    "\\(\\<generate\\>\\)\\|\\(\\<endgenerate\\>\\)"
    "\\(\\<task\\>\\)\\|\\(\\<endtask\\>\\)"
    "\\(\\<covergroup\\>\\)\\|\\(\\<endgroup\\>\\)"
    "\\(\\<property\\>\\)\\|\\(\\<endproperty\\>\\)"
    "\\(\\<\\(rand\\)?sequence\\>\\)\\|\\(\\<endsequence\\>\\)"
    "\\(\\<clocking\\>\\)\\|\\(\\<endclocking\\>\\)"
    ] )

(defconst verilog-nameable-item-re
  (eval-when-compile
    (verilog-regexp-words
     `("begin"
       "fork"
       "join" "join_any" "join_none"
       "end"
       "endcase"
       "endchecker"
       "endclass"
       "endclocking"
       "endconfig"
       "endfunction"
       "endgenerate"
       "endgroup"
       "endmodule"
       "endprimitive"
       "endinterface"
       "endpackage"
       "endprogram"
       "endproperty"
       "endsequence"
       "endspecify"
       "endtable"
       "endtask" )
     )))

(defconst verilog-declaration-opener
  (eval-when-compile
    (verilog-regexp-words
     `("module" "begin" "task" "function"))))

(defconst verilog-declaration-prefix-re
  (eval-when-compile
    (verilog-regexp-words
     `(
       ;; port direction
       "inout" "input" "output" "ref"
       ;; changeableness
       "const" "static" "protected" "local"
       ;; parameters
       "localparam" "parameter" "var"
       ;; type creation
       "typedef"
       ;; randomness
       "rand"
       ))))
(defconst verilog-declaration-core-re
  (eval-when-compile
    (verilog-regexp-words
     `(
       ;; port direction (by themselves)
       "inout" "input" "output"
       ;; integer_atom_type
       "byte" "shortint" "int" "longint" "integer" "time"
       ;; integer_vector_type
       "bit" "logic" "reg"
       ;; non_integer_type
       "shortreal" "real" "realtime"
       ;; net_type
       "supply0" "supply1" "tri" "triand" "trior" "trireg" "tri0" "tri1" "uwire" "wire" "wand" "wor"
       ;; misc
       "string" "event" "chandle" "virtual" "enum" "genvar"
       "struct" "union"
       ;; builtin classes
       "mailbox" "semaphore"
       ))))
(defconst verilog-declaration-re
  (concat "\\(" verilog-declaration-prefix-re "\\s-*\\)?" verilog-declaration-core-re))
(defconst verilog-range-re "\\(\\[[^]]*\\]\\s-*\\)+")
(defconst verilog-optional-signed-re "\\s-*\\(\\(un\\)?signed\\)?")
(defconst verilog-optional-signed-range-re
  (concat
   "\\s-*\\(\\<\\(reg\\|wire\\)\\>\\s-*\\)?\\(\\<\\(un\\)?signed\\>\\s-*\\)?\\(" verilog-range-re "\\)?"))
(defconst verilog-macroexp-re "`\\sw+")

(defconst verilog-delay-re "#\\s-*\\(\\([0-9_]+\\('s?[hdxbo][0-9a-fA-F_xz]+\\)?\\)\\|\\(([^()]*)\\)\\|\\(\\sw+\\)\\)")
(defconst verilog-declaration-re-2-no-macro
  (concat "\\s-*" verilog-declaration-re
          "\\s-*\\(\\(" verilog-optional-signed-range-re "\\)\\|\\(" verilog-delay-re "\\)"
          "\\)?"))
(defconst verilog-declaration-re-2-macro
  (concat "\\s-*" verilog-declaration-re
          "\\s-*\\(\\(" verilog-optional-signed-range-re "\\)\\|\\(" verilog-delay-re "\\)"
          "\\|\\(" verilog-macroexp-re "\\)"
          "\\)?"))
(defconst verilog-declaration-re-1-macro
  (concat "^" verilog-declaration-re-2-macro))

(defconst verilog-declaration-re-1-no-macro (concat "^" verilog-declaration-re-2-no-macro))

(defconst verilog-defun-re
  (eval-when-compile (verilog-regexp-words `("macromodule" "module" "program" "interface" "package" "primitive" "config"))))
(defconst verilog-end-defun-re
  (eval-when-compile (verilog-regexp-words `("endmodule" "endprogram" "endinterface" "endpackage" "endprimitive" "endconfig"))))
(defconst verilog-zero-indent-re
  (concat verilog-defun-re "\\|" verilog-end-defun-re))
(defconst verilog-inst-comment-re
  (eval-when-compile (verilog-regexp-words `("Outputs" "Inouts" "Inputs" "Interfaces" "Interfaced"))))

(defconst verilog-behavioral-block-beg-re
  (eval-when-compile (verilog-regexp-words `("initial" "final" "always" "always_comb" "always_latch" "always_ff"
                                             "function" "task"))))
(defconst verilog-coverpoint-re "\\w+\\s*:\\s*\\(coverpoint\\|cross\\constraint\\)"  )
(defconst verilog-in-constraint-re  ; keywords legal in constraint blocks starting a statement/block
  (eval-when-compile (verilog-regexp-words `("if" "else" "solve" "foreach"))))

(defconst verilog-indent-re
  (eval-when-compile
    (verilog-regexp-words
     `(
       "{"
       "always" "always_latch" "always_ff" "always_comb"
       "begin" "end"
       ;; "unique" "priority"
       "case" "casex" "casez" "randcase" "endcase"
       "class" "endclass"
       "clocking" "endclocking"
       "config" "endconfig"
       "covergroup" "endgroup"
       "fork" "join" "join_any" "join_none"
       "function" "endfunction"
       "final"
       "generate" "endgenerate"
       "initial"
       "interface" "endinterface"
       "module" "macromodule" "endmodule"
       "package" "endpackage"
       "primitive" "endprimitive"
       "program" "endprogram"
       "property" "endproperty"
       "sequence" "randsequence" "endsequence"
       "specify" "endspecify"
       "table" "endtable"
       "task" "endtask"
       "virtual"
       "`case"
       "`default"
       "`define" "`undef"
       "`if" "`ifdef" "`ifndef" "`else" "`elsif" "`endif"
       "`while" "`endwhile"
       "`for" "`endfor"
       "`format"
       "`include"
       "`let"
       "`protect" "`endprotect"
       "`switch" "`endswitch"
       "`timescale"
       "`time_scale"
       ;; OVM Begin tokens
       "`ovm_component_utils_begin"
       "`ovm_component_param_utils_begin"
       "`ovm_field_utils_begin"
       "`ovm_object_utils_begin"
       "`ovm_object_param_utils_begin"
       "`ovm_sequence_utils_begin"
       "`ovm_sequencer_utils_begin"
       ;; OVM End tokens
       "`ovm_component_utils_end"
       "`ovm_field_utils_end"
       "`ovm_object_utils_end"
       "`ovm_sequence_utils_end"
       "`ovm_sequencer_utils_end"
       ;; UVM Begin tokens
       "`uvm_component_utils_begin"
       "`uvm_component_param_utils_begin"
       "`uvm_field_utils_begin"
       "`uvm_object_utils_begin"
       "`uvm_object_param_utils_begin"
       "`uvm_sequence_utils_begin"
       "`uvm_sequencer_utils_begin"
       ;; UVM End tokens
       "`uvm_component_utils_end"       ; Typo in spec, it's not uvm_component_end
       "`uvm_field_utils_end"
       "`uvm_object_utils_end"
       "`uvm_sequence_utils_end"
       "`uvm_sequencer_utils_end"
       ;; VMM Begin tokens
       "`vmm_data_member_begin"
       "`vmm_env_member_begin"
       "`vmm_scenario_member_begin"
       "`vmm_subenv_member_begin"
       "`vmm_xactor_member_begin"
       ;; VMM End tokens
       "`vmm_data_member_end"
       "`vmm_env_member_end"
       "`vmm_scenario_member_end"
       "`vmm_subenv_member_end"
       "`vmm_xactor_member_end"
       ))))

(defconst verilog-defun-level-not-generate-re
  (eval-when-compile
    (verilog-regexp-words
     `( "module" "macromodule" "primitive" "class" "program"
        "interface" "package" "config"))))

(defconst verilog-defun-level-re
  (eval-when-compile
    (verilog-regexp-words
     (append
      `( "module" "macromodule" "primitive" "class" "program"
         "interface" "package" "config")
      `( "initial" "final" "always" "always_comb" "always_ff"
         "always_latch" "endtask" "endfunction" )))))

(defconst verilog-defun-level-generate-only-re
  (eval-when-compile
    (verilog-regexp-words
     `( "initial" "final" "always" "always_comb" "always_ff"
        "always_latch" "endtask" "endfunction" ))))

(defconst verilog-cpp-level-re
  (eval-when-compile
    (verilog-regexp-words
     `(
       "endmodule" "endprimitive" "endinterface" "endpackage" "endprogram" "endclass"
       ))))

(defconst verilog-dpi-import-export-re
  (eval-when-compile
    "\\(\\<\\(import\\|export\\)\\>\\s-+\"DPI\\(-C\\)?\"\\s-+\\(\\<\\(context\\|pure\\)\\>\\s-+\\)?\\([A-Za-z_][A-Za-z0-9_]*\\s-*=\\s-*\\)?\\<\\(function\\|task\\)\\>\\)"
    ))

(defconst verilog-default-clocking-re "\\<default\\s-+clocking\\>")
(defconst verilog-disable-fork-re "\\(disable\\|wait\\)\\s-+fork\\>")
(defconst verilog-extended-case-re "\\(\\(unique0?\\s-+\\|priority\\s-+\\)?case[xz]?\\|randcase\\)")
(defconst verilog-extended-complete-re
  ;; verilog-beg-of-statement also looks backward one token to extend this match
  (concat "\\(\\(\\<extern\\s-+\\|\\<\\(\\<\\(pure\\|context\\)\\>\\s-+\\)?virtual\\s-+\\|\\<protected\\s-+\\|\\<static\\s-+\\)*\\(\\<function\\>\\|\\<task\\>\\)\\)"
          "\\|\\(\\(\\<typedef\\>\\s-+\\)*\\(\\<struct\\>\\|\\<union\\>\\|\\<class\\>\\)\\)"
          "\\|\\(\\(\\<\\(import\\|export\\)\\>\\s-+\\)?\\(\"DPI\\(-C\\)?\"\\s-+\\)?\\(\\<\\(pure\\|context\\)\\>\\s-+\\)?\\([A-Za-z_][A-Za-z0-9_]*\\s-*=\\s-*\\)?\\(function\\>\\|task\\>\\)\\)"
          "\\|" verilog-extended-case-re ))
(defconst verilog-basic-complete-re
  (eval-when-compile
    (verilog-regexp-words
     `(
       "always" "assign" "always_latch" "always_ff" "always_comb" "constraint"
       "import" "initial" "final" "module" "macromodule" "repeat" "randcase" "while"
       "if" "for" "forever" "foreach" "else" "parameter" "do" "localparam" "assert"
       ))))
(defconst verilog-complete-reg
  (concat
   verilog-extended-complete-re "\\|\\(" verilog-basic-complete-re "\\)"))

(defconst verilog-end-statement-re
  (concat "\\(" verilog-beg-block-re "\\)\\|\\("
          verilog-end-block-re "\\)"))

(defconst verilog-endcase-re
  (concat verilog-extended-case-re "\\|"
          "\\(endcase\\)\\|"
          verilog-defun-re
          ))

(defconst verilog-exclude-str-start "/* -----\\/----- EXCLUDED -----\\/-----"
  "String used to mark beginning of excluded text.")
(defconst verilog-exclude-str-end " -----/\\----- EXCLUDED -----/\\----- */"
  "String used to mark end of excluded text.")
(defconst verilog-preprocessor-re
  (eval-when-compile
    (concat
     ;; single words
     "\\(?:"
     (verilog-regexp-words
      `("`__FILE__"
        "`__LINE__"
        "`celldefine"
        "`else"
        "`end_keywords"
        "`endcelldefine"
        "`endif"
        "`nounconnected_drive"
        "`resetall"
        "`unconnected_drive"
        "`undefineall"))
     "\\)\\|\\(?:"
     ;; two words: i.e. `ifdef DEFINE
     "\\<\\(`elsif\\|`ifn?def\\|`undef\\|`default_nettype\\|`begin_keywords\\)\\>\\s-"
     "\\)\\|\\(?:"
     ;; `line number "filename" level
     "\\<\\(`line\\)\\>\\s-+[0-9]+\\s-+\"[^\"]+\"\\s-+[012]"
     "\\)\\|\\(?:"
     ;;`include "file" or `include <file>
     "\\<\\(`include\\)\\>\\s-+\\(?:\"[^\"]+\"\\|<[^>]+>\\)"
     "\\)\\|\\(?:"
     ;; `pragma <stuff> (no mention in IEEE 1800-2012 that pragma can span multiple lines
     "\\<\\(`pragma\\)\\>\\s-+.+$"
     "\\)\\|\\(?:"
     ;; `timescale time_unit / time_precision
     "\\<\\(`timescale\\)\\>\\s-+10\\{0,2\\}\\s-*[munpf]?s\\s-*\\/\\s-*10\\{0,2\\}\\s-*[munpf]?s"
     "\\)\\|\\(?:"
     ;; `define and `if can span multiple lines if line ends in '\'. NOTE: `if is not IEEE 1800-2012
     ;; from http://www.emacswiki.org/emacs/MultilineRegexp
     (concat "\\<\\(`define\\|`if\\)\\>"  ; directive
             "\\s-+"  ; separator
             "\\(?:.*?\\(?:\n.*\\)*?\\)"  ; definition: to end of line, then maybe more lines (excludes any trailing \n)
             "\\(?:\n\\s-*\n\\|\\'\\)")  ; blank line or EOF
     "\\)\\|\\(?:"
     ;; `<macro>() : i.e. `uvm_info(a,b,c) or any other pre-defined macro
     ;; Since parameters inside the macro can have parentheses, and
     ;; the macro can span multiple lines, just look for the opening
     ;; parentheses and then continue to the end of the first
     ;; non-escaped EOL
     (concat "\\<`\\w+\\>\\s-*("
             "\\(?:.*?\\(?:\n.*\\)*?\\)"  ; definition: to end of line, then maybe more lines (excludes any trailing \n)
             "\\(?:\n\\s-*\n\\|\\'\\)")   ; blank line or EOF
     "\\)"
     )))

(defconst verilog-keywords
  (append verilog-compiler-directives
          '(
            "after" "alias" "always" "always_comb" "always_ff" "always_latch" "and"
            "assert" "assign" "assume" "automatic" "before" "begin" "bind"
            "bins" "binsof" "bit" "break" "buf" "bufif0" "bufif1" "byte"
            "case" "casex" "casez" "cell" "chandle" "class" "clocking" "cmos"
            "config" "const" "constraint" "context" "continue" "cover"
            "covergroup" "coverpoint" "cross" "deassign" "default" "defparam"
            "design" "disable" "dist" "do" "edge" "else" "end" "endcase"
            "endclass" "endclocking" "endconfig" "endfunction" "endgenerate"
            "endgroup" "endinterface" "endmodule" "endpackage" "endprimitive"
            "endprogram" "endproperty" "endspecify" "endsequence" "endtable"
            "endtask" "enum" "event" "expect" "export" "extends" "extern"
            "final" "first_match" "for" "force" "foreach" "forever" "fork"
            "forkjoin" "function" "generate" "genvar" "highz0" "highz1" "if"
            "iff" "ifnone" "ignore_bins" "illegal_bins" "import" "incdir"
            "include" "initial" "inout" "input" "inside" "instance" "int"
            "integer" "interface" "intersect" "join" "join_any" "join_none"
            "large" "liblist" "library" "local" "localparam" "logic"
            "longint" "macromodule" "mailbox" "matches" "medium" "modport" "module"
            "nand" "negedge" "new" "nmos" "nor" "noshowcancelled" "not"
            "notif0" "notif1" "null" "or" "output" "package" "packed"
            "parameter" "pmos" "posedge" "primitive" "priority" "program"
            "property" "protected" "pull0" "pull1" "pulldown" "pullup"
            "pulsestyle_onevent" "pulsestyle_ondetect" "pure" "rand" "randc"
            "randcase" "randsequence" "rcmos" "real" "realtime" "ref" "reg"
            "release" "repeat" "return" "rnmos" "rpmos" "rtran" "rtranif0"
            "rtranif1" "scalared" "semaphore" "sequence" "shortint" "shortreal"
            "showcancelled" "signed" "small" "solve" "specify" "specparam"
            "static" "string" "strong0" "strong1" "struct" "super" "supply0"
            "supply1" "table" "tagged" "task" "this" "throughout" "time"
            "timeprecision" "timeunit" "tran" "tranif0" "tranif1" "tri"
            "tri0" "tri1" "triand" "trior" "trireg" "type" "typedef" "union"
            "unique" "unsigned" "use" "uwire" "var" "vectored" "virtual" "void"
            "wait" "wait_order" "wand" "weak0" "weak1" "while" "wildcard"
            "wire" "with" "within" "wor" "xnor" "xor"
            ;; 1800-2009
            "accept_on" "checker" "endchecker" "eventually" "global" "implies"
            "let" "nexttime" "reject_on" "restrict" "s_always" "s_eventually"
            "s_nexttime" "s_until" "s_until_with" "strong" "sync_accept_on"
            "sync_reject_on" "unique0" "until" "until_with" "untyped" "weak"
            ;; 1800-2012
            "implements" "interconnect" "nettype" "soft"
            ))
  "List of Verilog keywords.")

(defconst verilog-comment-start-regexp "//\\|/\\*"
  "Dual comment value for `comment-start-regexp'.")

(defvar verilog-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; Populate the syntax TABLE.
    (modify-syntax-entry ?\\ "\\" table)
    (modify-syntax-entry ?+ "." table)
    (modify-syntax-entry ?- "." table)
    (modify-syntax-entry ?= "." table)
    (modify-syntax-entry ?% "." table)
    (modify-syntax-entry ?< "." table)
    (modify-syntax-entry ?> "." table)
    (modify-syntax-entry ?& "." table)
    (modify-syntax-entry ?| "." table)
    (modify-syntax-entry ?` "w" table)  ; ` is part of definition symbols in Verilog
    (modify-syntax-entry ?_ "w" table)
    (modify-syntax-entry ?\' "." table)

    ;; Set up TABLE to handle block and line style comments.
    (modify-syntax-entry ?/  ". 124b" table)
    (modify-syntax-entry ?*  ". 23"   table)
    (modify-syntax-entry ?\n "> b"    table)
    table)
  "Syntax table used in Verilog mode buffers.")

(defvar verilog-font-lock-keywords nil
  "Default highlighting for Verilog mode.")

(defvar verilog-font-lock-keywords-1 nil
  "Subdued level highlighting for Verilog mode.")

(defvar verilog-font-lock-keywords-2 nil
  "Medium level highlighting for Verilog mode.
See also `verilog-font-lock-extra-types'.")

(defvar verilog-font-lock-keywords-3 nil
  "Gaudy level highlighting for Verilog mode.
See also `verilog-font-lock-extra-types'.")

(defvar verilog-font-lock-translate-off-face
  'verilog-font-lock-translate-off-face
  "Font to use for translated off regions.")
(defface verilog-font-lock-translate-off-face
  '((((class color)
      (background light))
     (:background "gray90" :italic t ))
    (((class color)
      (background dark))
     (:background "gray10" :italic t ))
    (((class grayscale) (background light))
     (:foreground "DimGray" :italic t))
    (((class grayscale) (background dark))
     (:foreground "LightGray" :italic t))
    (t (:italis t)))
  "Font lock mode face used to background highlight translate-off regions."
  :group 'font-lock-highlighting-faces)

(defvar verilog-font-lock-p1800-face
  'verilog-font-lock-p1800-face
  "Font to use for p1800 keywords.")
(defface verilog-font-lock-p1800-face
  '((((class color)
      (background light))
     (:foreground "DarkOrange3" :bold t ))
    (((class color)
      (background dark))
     (:foreground "orange1" :bold t ))
    (t (:italic t)))
  "Font lock mode face used to highlight P1800 keywords."
  :group 'font-lock-highlighting-faces)

(defvar verilog-font-lock-ams-face
  'verilog-font-lock-ams-face
  "Font to use for Analog/Mixed Signal keywords.")
(defface verilog-font-lock-ams-face
  '((((class color)
      (background light))
     (:foreground "Purple" :bold t ))
    (((class color)
      (background dark))
     (:foreground "orange1" :bold t ))
    (t (:italic t)))
  "Font lock mode face used to highlight AMS keywords."
  :group 'font-lock-highlighting-faces)

(defvar verilog-font-lock-grouping-keywords-face
  'verilog-font-lock-grouping-keywords-face
  "Font to use for Verilog Grouping Keywords (such as begin..end).")
(defface verilog-font-lock-grouping-keywords-face
  '((((class color)
      (background light))
     (:foreground "Purple" :bold t ))
    (((class color)
      (background dark))
     (:foreground "orange1" :bold t ))
    (t (:italic t)))
  "Font lock mode face used to highlight verilog grouping keywords."
  :group 'font-lock-highlighting-faces)

(let* ((verilog-type-font-keywords
        (eval-when-compile
          (regexp-opt
           '(
             "and" "bit" "buf" "bufif0" "bufif1" "cmos" "defparam"
             "event" "genvar" "inout" "input" "integer" "localparam"
             "logic" "mailbox" "nand" "nmos" "nor" "not" "notif0" "notif1" "or"
             "output" "parameter" "pmos" "pull0" "pull1" "pulldown" "pullup"
             "rcmos" "real" "realtime" "reg" "rnmos" "rpmos" "rtran"
             "rtranif0" "rtranif1" "semaphore" "signed" "struct" "supply"
             "supply0" "supply1" "time" "tran" "tranif0" "tranif1"
             "tri" "tri0" "tri1" "triand" "trior" "trireg" "typedef"
             "uwire" "vectored" "wand" "wire" "wor" "xnor" "xor"
             ) nil  )))

       (verilog-pragma-keywords
        (eval-when-compile
          (regexp-opt
           '("surefire" "auto" "synopsys" "rtl_synthesis" "verilint" "leda" "0in"
             ) nil  )))

       (verilog-1800-2005-keywords
        (eval-when-compile
          (regexp-opt
           '("alias" "assert" "assume" "automatic" "before" "bind"
             "bins" "binsof" "break" "byte" "cell" "chandle" "class"
             "clocking" "config" "const" "constraint" "context" "continue"
             "cover" "covergroup" "coverpoint" "cross" "deassign" "design"
             "dist" "do" "edge" "endclass" "endclocking" "endconfig"
             "endgroup" "endprogram" "endproperty" "endsequence" "enum"
             "expect" "export" "extends" "extern" "first_match" "foreach"
             "forkjoin" "genvar" "highz0" "highz1" "ifnone" "ignore_bins"
             "illegal_bins" "import" "incdir" "include" "inside" "instance"
             "int" "intersect" "large" "liblist" "library" "local" "longint"
             "matches" "medium" "modport" "new" "noshowcancelled" "null"
             "packed" "program" "property" "protected" "pull0" "pull1"
             "pulsestyle_onevent" "pulsestyle_ondetect" "pure" "rand" "randc"
             "randcase" "randsequence" "ref" "release" "return" "scalared"
             "sequence" "shortint" "shortreal" "showcancelled" "small" "solve"
             "specparam" "static" "string" "strong0" "strong1" "struct"
             "super" "tagged" "this" "throughout" "timeprecision" "timeunit"
             "type" "union" "unsigned" "use" "var" "virtual" "void"
             "wait_order" "weak0" "weak1" "wildcard" "with" "within"
             ) nil )))

       (verilog-1800-2009-keywords
        (eval-when-compile
          (regexp-opt
           '("accept_on" "checker" "endchecker" "eventually" "global"
             "implies" "let" "nexttime" "reject_on" "restrict" "s_always"
             "s_eventually" "s_nexttime" "s_until" "s_until_with" "strong"
             "sync_accept_on" "sync_reject_on" "unique0" "until"
             "until_with" "untyped" "weak" ) nil )))

       (verilog-1800-2012-keywords
        (eval-when-compile
          (regexp-opt
           '("implements" "interconnect" "nettype" "soft" ) nil )))

       (verilog-ams-keywords
        (eval-when-compile
          (regexp-opt
           '("above" "abs" "absdelay" "acos" "acosh" "ac_stim"
             "aliasparam" "analog" "analysis" "asin" "asinh" "atan" "atan2" "atanh"
             "branch" "ceil" "connectmodule" "connectrules" "cos" "cosh" "ddt"
             "ddx" "discipline" "driver_update" "enddiscipline" "endconnectrules"
             "endnature" "endparamset" "exclude" "exp" "final_step" "flicker_noise"
             "floor" "flow" "from" "ground" "hypot" "idt" "idtmod" "inf"
             "initial_step" "laplace_nd" "laplace_np" "laplace_zd" "laplace_zp"
             "last_crossing" "limexp" "ln" "log" "max" "min" "nature"
             "net_resolution" "noise_table" "paramset" "potential" "pow" "sin"
             "sinh" "slew" "sqrt" "tan" "tanh" "timer" "transition" "white_noise"
             "wreal" "zi_nd" "zi_np" "zi_zd" ) nil )))

       (verilog-font-keywords
        (eval-when-compile
          (regexp-opt
           '(
             "assign" "case" "casex" "casez" "randcase" "deassign"
             "default" "disable" "else" "endcase" "endfunction"
             "endgenerate" "endinterface" "endmodule" "endprimitive"
             "endspecify" "endtable" "endtask" "final" "for" "force" "return" "break"
             "continue" "forever" "fork" "function" "generate" "if" "iff" "initial"
             "interface" "join" "join_any" "join_none" "macromodule" "module" "negedge"
             "package" "endpackage" "always" "always_comb" "always_ff"
             "always_latch" "posedge" "primitive" "priority" "release"
             "repeat" "specify" "table" "task" "unique" "wait" "while"
             "class" "program" "endclass" "endprogram"
             ) nil  )))

       (verilog-font-grouping-keywords
        (eval-when-compile
          (regexp-opt
           '( "begin" "end" ) nil  ))))

  (setq verilog-font-lock-keywords
        (list
         ;; Fontify all builtin keywords
         (concat "\\<\\(" verilog-font-keywords "\\|"
                 ;; And user/system tasks and functions
                 "\\$[a-zA-Z][a-zA-Z0-9_\\$]*"
                 "\\)\\>")
         ;; Fontify all types
         (if verilog-highlight-grouping-keywords
             (cons (concat "\\<\\(" verilog-font-grouping-keywords "\\)\\>")
                   'verilog-font-lock-grouping-keywords-face)
           (cons (concat "\\<\\(" verilog-font-grouping-keywords "\\)\\>")
                 'font-lock-type-face))
         (cons (concat "\\<\\(" verilog-type-font-keywords "\\)\\>")
               'font-lock-type-face)
         ;; Fontify IEEE-1800-2005 keywords appropriately
         (if verilog-highlight-p1800-keywords
             (cons (concat "\\<\\(" verilog-1800-2005-keywords "\\)\\>")
                   'verilog-font-lock-p1800-face)
           (cons (concat "\\<\\(" verilog-1800-2005-keywords "\\)\\>")
                 'font-lock-type-face))
         ;; Fontify IEEE-1800-2009 keywords appropriately
         (if verilog-highlight-p1800-keywords
             (cons (concat "\\<\\(" verilog-1800-2009-keywords "\\)\\>")
                   'verilog-font-lock-p1800-face)
           (cons (concat "\\<\\(" verilog-1800-2009-keywords "\\)\\>")
                 'font-lock-type-face))
         ;; Fontify IEEE-1800-2012 keywords appropriately
         (if verilog-highlight-p1800-keywords
             (cons (concat "\\<\\(" verilog-1800-2012-keywords "\\)\\>")
                   'verilog-font-lock-p1800-face)
           (cons (concat "\\<\\(" verilog-1800-2012-keywords "\\)\\>")
                 'font-lock-type-face))
         ;; Fontify Verilog-AMS keywords
         (cons (concat "\\<\\(" verilog-ams-keywords "\\)\\>")
               'verilog-font-lock-ams-face)))

  (setq verilog-font-lock-keywords-1
        (append verilog-font-lock-keywords
                (list
                 ;; Fontify module definitions
                 (list
                  "\\<\\(\\(macro\\)?module\\|primitive\\|class\\|program\\|interface\\|package\\|task\\)\\>\\s-*\\(\\sw+\\)"
                  '(1 font-lock-keyword-face)
                  '(3 font-lock-function-name-face 'prepend))
                 ;; Fontify function definitions
                 (list
                  (concat "\\<function\\>\\s-+\\(integer\\|real\\(time\\)?\\|time\\)\\s-+\\(\\sw+\\)" )
                  '(1 font-lock-keyword-face)
                  '(3 font-lock-constant-face prepend))
                 '("\\<function\\>\\s-+\\(\\[[^]]+\\]\\)\\s-+\\(\\sw+\\)"
                   (1 font-lock-keyword-face)
                   (2 font-lock-constant-face append))
                 '("\\<function\\>\\s-+\\(\\sw+\\)"
                   1 'font-lock-constant-face append))))

  (setq verilog-font-lock-keywords-2
        (append verilog-font-lock-keywords-1
                (list
                 ;; Fontify pragmas
                 (concat "\\(//\\s-*\\(" verilog-pragma-keywords "\\)\\s-.*\\)")
                 ;; Fontify escaped names
                 '("\\(\\\\\\S-*\\s-\\)"  0 font-lock-function-name-face)
                 ;; Fontify macro definitions/ uses
                 '("`\\s-*[A-Za-z][A-Za-z0-9_]*" 0 (if (boundp 'font-lock-preprocessor-face)
                                                       'font-lock-preprocessor-face
                                                     'font-lock-type-face))
                 ;; Fontify delays/numbers
                 '("\\(@\\)\\|\\([ \t\n\f\r]#\\s-*\\(\\([0-9_.]+\\('s?[hdxbo][0-9a-fA-F_xz]*\\)?\\)\\|\\(([^()]+)\\|\\sw+\\)\\)\\)"
                   0 font-lock-type-face append)
                 ;; Fontify property/sequence cycle delays - these start with '##'
                 '("\\(##\\(\\sw+\\|\\[[^]]+\\]\\)\\)"
                   0 font-lock-type-face append)
                 ;; Fontify instantiation names
                 '("\\([A-Za-z][A-Za-z0-9_]*\\)\\s-*(" 1 font-lock-function-name-face)
                 )))

  (setq verilog-font-lock-keywords-3
        (append verilog-font-lock-keywords-2
                (when verilog-highlight-translate-off
                  (list
                   ;; Fontify things in translate off regions
                   '(verilog-match-translate-off
                     (0 'verilog-font-lock-translate-off-face prepend))
                   )))))

;;
;; Buffer state preservation

(defmacro verilog-save-buffer-state (&rest body)
  "Execute BODY forms, saving state around insignificant change.
Changes in text properties like `face' or `syntax-table' are
considered insignificant.  This macro allows text properties to
be changed, even in a read-only buffer.

A change is considered significant if it affects the buffer text
in any way that isn't completely restored again.  Any
user-visible changes to the buffer must not be within a
`verilog-save-buffer-state'."
  `(let ((inhibit-point-motion-hooks t)
         (verilog-no-change-functions t))
     ,(if (fboundp 'with-silent-modifications)
          `(with-silent-modifications ,@body)
        ;; Backward compatible version of with-silent-modifications
        `(let* ((modified (buffer-modified-p))
                (buffer-undo-list t)
                (inhibit-read-only t)
                (inhibit-modification-hooks t)
                ;; XEmacs ignores inhibit-modification-hooks.
                before-change-functions after-change-functions
                deactivate-mark
                buffer-file-name        ; Prevent primitives checking
                buffer-file-truename)	; for file modification
           (unwind-protect
               (progn ,@body)
             (and (not modified)
                  (buffer-modified-p)
                  (restore-buffer-modified-p nil)))))))


(defvar verilog-save-font-mod-hooked nil
  "Local variable when inside a `verilog-save-font-no-change-functions' block.")
(make-variable-buffer-local 'verilog-save-font-mod-hooked)

(defmacro verilog-save-font-no-change-functions (&rest body)
  "Execute BODY forms, disabling all change hooks in BODY.
Includes temporary disabling of `font-lock' to restore the buffer
to full text form for parsing.  Additional actions may be specified with
`verilog-before-save-font-hook' and `verilog-after-save-font-hook'.
For insignificant changes, see instead `verilog-save-buffer-state'."
  `(if verilog-save-font-mod-hooked ; Short-circuit a recursive call
       (progn ,@body)
     ;; Before version 20, match-string with font-lock returns a
     ;; vector that is not equal to the string.  IE if on "input"
     ;; nil==(equal "input" (progn (looking-at "input") (match-string 0)))
     ;; Therefore we must remove and restore font-lock mode
     (verilog-run-hooks 'verilog-before-save-font-hook)
     (let* ((verilog-save-font-mod-hooked (- (point-max) (point-min)))
            ;; Significant speed savings with no font-lock properties
            (fontlocked (when (and (boundp 'font-lock-mode) font-lock-mode)
                          (font-lock-mode 0)
                          t)))
       (run-hook-with-args 'before-change-functions (point-min) (point-max))
       (unwind-protect
           ;; Must inhibit and restore hooks before restoring font-lock
           (let* ((inhibit-point-motion-hooks t)
                  (inhibit-modification-hooks t)
                  (verilog-no-change-functions t)
                  ;; XEmacs and pre-Emacs 21 ignore inhibit-modification-hooks.
                  before-change-functions after-change-functions)
             (progn ,@body))
         ;; Unwind forms
         (run-hook-with-args 'after-change-functions (point-min) (point-max)
                             verilog-save-font-mod-hooked) ; old length
         (when fontlocked (font-lock-mode t))
         (verilog-run-hooks 'verilog-after-save-font-hook)))))

;;
;; Comment detection and caching

(defvar verilog-scan-cache-preserving nil
  "If true, the specified buffer's comment properties are static.
Buffer changes will be ignored.  See `verilog-inside-comment-or-string-p'
and `verilog-scan'.")

(defvar verilog-scan-cache-tick nil
  "Modification tick at which `verilog-scan' was last completed.")
(make-variable-buffer-local 'verilog-scan-cache-tick)

(defun verilog-scan-cache-flush ()
  "Flush the `verilog-scan' cache."
  (setq verilog-scan-cache-tick nil))

(defun verilog-scan-cache-ok-p ()
  "Return t if the scan cache is up to date."
  (or (and verilog-scan-cache-preserving
           (eq verilog-scan-cache-preserving (current-buffer))
           verilog-scan-cache-tick)
      (equal verilog-scan-cache-tick (buffer-chars-modified-tick))))

(defmacro verilog-save-scan-cache (&rest body)
  "Execute the BODY forms, allowing scan cache preservation within BODY.
This requires that insertions must use `verilog-insert'."
  ;; If the buffer is out of date, trash it, as we'll not check later the tick
  ;; Note this must work properly if there's multiple layers of calls
  ;; to verilog-save-scan-cache even with differing ticks.
  `(progn
     (unless (verilog-scan-cache-ok-p)   ; Must be before let
       (setq verilog-scan-cache-tick nil))
     (let* ((verilog-scan-cache-preserving (current-buffer)))
       (progn ,@body))))

(defun verilog-scan-region (beg end)
  "Parse between BEG and END for `verilog-inside-comment-or-string-p'.
This creates v-cmts properties where comments are in force."
  ;; Why properties and not overlays?  Overlays have much slower non O(1)
  ;; lookup times.
  ;; This function is warm - called on every verilog-insert
  (save-excursion
    (save-match-data
      (verilog-save-buffer-state
       (let (pt)
         (goto-char beg)
         (while (< (point) end)
           (cond ((looking-at "//")
                  (setq pt (point))
                  (or (search-forward "\n" end t)
                      (goto-char end))
                  ;; "1+": The leading // or /* itself isn't considered as
                  ;; being "inside" the comment, so that a (search-backward)
                  ;; that lands at the start of the // won't mis-indicate
                  ;; it's inside a comment.  Also otherwise it would be
                  ;; hard to find a commented out /*AS*/ vs one that isn't
                  (put-text-property (1+ pt) (point) 'v-cmts t))
                 ((looking-at "/\\*")
                  (setq pt (point))
                  (or (search-forward "*/" end t)
                      ;; No error - let later code indicate it so we can
                      ;; use inside functions on-the-fly
                      ;;(error "%s: Unmatched /* */, at char %d"
                      ;;       (verilog-point-text) (point))
                      (goto-char end))
                  (put-text-property (1+ pt) (point) 'v-cmts t))
                 ((looking-at "\"")
                  (setq pt (point))
                  (or (re-search-forward "[^\\]\"" end t)  ; don't forward-char first, since we look for a non backslash first
                      ;; No error - let later code indicate it so we can
                      (goto-char end))
                  (put-text-property (1+ pt) (point) 'v-cmts t))
                 (t
                  (forward-char 1)
                  (if (re-search-forward "[/\"]" end t)
                      (backward-char 1)
                    (goto-char end))))))))))

(defun verilog-scan ()
  "Parse the buffer, marking all comments with properties.
Also assumes any text inserted since `verilog-scan-cache-tick'
either is ok to parse as a non-comment, or `verilog-insert' was used."
  ;; See also `verilog-scan-debug' and `verilog-scan-and-debug'
  (unless (verilog-scan-cache-ok-p)
    (save-excursion
      (verilog-save-buffer-state
       (when verilog-debug
         (message "Scanning %s cache=%s cachetick=%S tick=%S" (current-buffer)
                  verilog-scan-cache-preserving verilog-scan-cache-tick
                  (buffer-chars-modified-tick)))
       (remove-text-properties (point-min) (point-max) '(v-cmts nil))
       (verilog-scan-region (point-min) (point-max))
       (setq verilog-scan-cache-tick (buffer-chars-modified-tick))
       (when verilog-debug (message "Scanning... done"))))))

(defun verilog-scan-debug ()
  "For debugging, show with display face results of `verilog-scan'."
  (font-lock-mode 0)
  ;;(if dbg (setq dbg (concat dbg (format "verilog-scan-debug\n"))))
  (save-excursion
    (goto-char (point-min))
    (remove-text-properties (point-min) (point-max) '(face nil))
    (while (not (eobp))
      (cond ((get-text-property (point) 'v-cmts)
             (put-text-property (point) (1+ (point)) `face 'underline)
             ;;(if dbg (setq dbg (concat dbg (format "  v-cmts at %S\n" (point)))))
             (forward-char 1))
            (t
             (goto-char (or (next-property-change (point)) (point-max))))))))

(defun verilog-scan-and-debug ()
  "For debugging, run `verilog-scan' and `verilog-scan-debug'."
  (let (verilog-scan-cache-preserving
        verilog-scan-cache-tick)
    (goto-char (point-min))
    (verilog-scan)
    (verilog-scan-debug)))

(defun verilog-inside-comment-or-string-p (&optional pos)
  "Check if optional point POS is inside a comment.
This may require a slow pre-parse of the buffer with `verilog-scan'
to establish comment properties on all text."
  ;; This function is very hot
  (verilog-scan)
  (if pos
      (and (>= pos (point-min))
           (get-text-property pos 'v-cmts))
    (get-text-property (point) 'v-cmts)))

(defun verilog-insert (&rest stuff)
  "Insert STUFF arguments, tracking for `verilog-inside-comment-or-string-p'.
Any insert that includes a comment must have the entire comment
inserted using a single call to `verilog-insert'."
  (let ((pt (point)))
    (while stuff
      (insert (car stuff))
      (setq stuff (cdr stuff)))
    (verilog-scan-region pt (point))))

;; More searching

(defun verilog-declaration-end ()
  (search-forward ";"))

(defun verilog-point-text (&optional pointnum)
  "Return text describing where POINTNUM or current point is (for errors).
Use filename, if current buffer being edited shorten to just buffer name."
  (concat (or (and (equal (window-buffer) (current-buffer))
                   (buffer-name))
              buffer-file-name
              (buffer-name))
          ":" (int-to-string (1+ (count-lines (point-min) (or pointnum (point)))))))

(defun electric-verilog-backward-sexp ()
  "Move backward over one balanced expression."
  (interactive)
  ;; before that see if we are in a comment
  (verilog-backward-sexp))

(defun electric-verilog-forward-sexp ()
  "Move forward over one balanced expression."
  (interactive)
  ;; before that see if we are in a comment
  (verilog-forward-sexp))

(defun verilog-forward-sexp-function (arg)
  "Move forward ARG sexps."
  ;; Used by hs-minor-mode
  (if (< arg 0)
      (verilog-backward-sexp)
    (verilog-forward-sexp)))

(defun verilog-backward-sexp ()
  (let ((reg)
        (elsec 1)
        (found nil)
        (st (point)))
    (if (not (looking-at "\\<"))
        (forward-word-strictly -1))
    (cond
     ((verilog-skip-backward-comment-or-string))
     ((looking-at "\\<else\\>")
      (setq reg (concat
                 verilog-end-block-re
                 "\\|\\(\\<else\\>\\)"
                 "\\|\\(\\<if\\>\\)"))
      (while (and (not found)
                  (verilog-re-search-backward reg nil 'move))
        (cond
         ((match-end 1) ; matched verilog-end-block-re
          ;; try to leap back to matching outward block by striding across
          ;; indent level changing tokens then immediately
          ;; previous line governs indentation.
          (verilog-leap-to-head))
         ((match-end 2) ; else, we're in deep
          (setq elsec (1+ elsec)))
         ((match-end 3) ; found it
          (setq elsec (1- elsec))
          (if (= 0 elsec)
              ;; Now previous line describes syntax
              (setq found 't))))))
     ((looking-at verilog-end-block-re)
      (verilog-leap-to-head))
     ((looking-at "\\(endmodule\\>\\)\\|\\(\\<endprimitive\\>\\)\\|\\(\\<endclass\\>\\)\\|\\(\\<endprogram\\>\\)\\|\\(\\<endinterface\\>\\)\\|\\(\\<endpackage\\>\\)")
      (cond
       ((match-end 1)
        (verilog-re-search-backward "\\<\\(macro\\)?module\\>" nil 'move))
       ((match-end 2)
        (verilog-re-search-backward "\\<primitive\\>" nil 'move))
       ((match-end 3)
        (verilog-re-search-backward "\\<class\\>" nil 'move))
       ((match-end 4)
        (verilog-re-search-backward "\\<program\\>" nil 'move))
       ((match-end 5)
        (verilog-re-search-backward "\\<interface\\>" nil 'move))
       ((match-end 6)
        (verilog-re-search-backward "\\<package\\>" nil 'move))
       (t
        (goto-char st)
        (backward-sexp 1))))
     (t
      (goto-char st)
      (backward-sexp)))))

(defun verilog-forward-sexp ()
  (let ((reg)
        (md 2)
        (st (point))
        (nest 'yes))
    (if (not (looking-at "\\<"))
        (forward-word-strictly -1))
    (cond
     ((verilog-skip-forward-comment-or-string)
      (verilog-forward-syntactic-ws))
     ((looking-at verilog-beg-block-re-ordered)
      (cond
       ((match-end 1);
        ;; Search forward for matching end
        (setq reg "\\(\\<begin\\>\\)\\|\\(\\<end\\>\\)" ))
       ((match-end 2)
        ;; Search forward for matching endcase
        (setq reg "\\(\\<randcase\\>\\|\\(\\<unique0?\\>\\s-+\\|\\<priority\\>\\s-+\\)?\\<case[xz]?\\>[^:]\\)\\|\\(\\<endcase\\>\\)" )
        (setq md 3)  ; ender is third item in regexp
        )
       ((match-end 4)
        ;; might be "disable fork" or "wait fork"
        (let
            (here)
          (if (or
               (looking-at verilog-disable-fork-re)
               (and (looking-at "fork")
                    (progn
                      (setq here (point))  ; sometimes a fork is just a fork
                      (forward-word-strictly -1)
                      (looking-at verilog-disable-fork-re))))
              (progn  ; it is a disable fork; ignore it
                (goto-char (match-end 0))
                (forward-word-strictly 1)
                (setq reg nil))
            (progn  ; it is a nice simple fork
              (goto-char here)   ; return from looking for "disable fork"
              ;; Search forward for matching join
              (setq reg "\\(\\<fork\\>\\)\\|\\(\\<join\\(_any\\|_none\\)?\\>\\)" )))))
       ((match-end 6)
        ;; Search forward for matching endclass
        (setq reg "\\(\\<class\\>\\)\\|\\(\\<endclass\\>\\)" ))

       ((match-end 7)
        ;; Search forward for matching endtable
        (setq reg "\\<endtable\\>" )
        (setq nest 'no))
       ((match-end 8)
        ;; Search forward for matching endspecify
        (setq reg "\\(\\<specify\\>\\)\\|\\(\\<endspecify\\>\\)" ))
       ((match-end 9)
        ;; Search forward for matching endfunction
        (setq reg "\\<endfunction\\>" )
        (setq nest 'no))
       ((match-end 10)
        ;; Search forward for matching endfunction
        (setq reg "\\<endfunction\\>" )
        (setq nest 'no))
       ((match-end 11)
        ;; Search forward for matching endtask
        (setq reg "\\<endtask\\>" )
        (setq nest 'no))
       ((match-end 12)
        ;; Search forward for matching endtask
        (setq reg "\\<endtask\\>" )
        (setq nest 'no))
       ((match-end 12)
        ;; Search forward for matching endgenerate
        (setq reg "\\(\\<generate\\>\\)\\|\\(\\<endgenerate\\>\\)" ))
       ((match-end 13)
        ;; Search forward for matching endgroup
        (setq reg "\\(\\<covergroup\\>\\)\\|\\(\\<endgroup\\>\\)" ))
       ((match-end 14)
        ;; Search forward for matching endproperty
        (setq reg "\\(\\<property\\>\\)\\|\\(\\<endproperty\\>\\)" ))
       ((match-end 15)
        ;; Search forward for matching endsequence
        (setq reg "\\(\\<\\(rand\\)?sequence\\>\\)\\|\\(\\<endsequence\\>\\)" )
        (setq md 3)) ; 3 to get to endsequence in the reg above
       ((match-end 17)
        ;; Search forward for matching endclocking
        (setq reg "\\(\\<clocking\\>\\)\\|\\(\\<endclocking\\>\\)" )))
      (if (and reg
               (forward-word-strictly 1))
          (catch 'skip
            (if (eq nest 'yes)
                (let ((depth 1)
                      here)
                  (while (verilog-re-search-forward reg nil 'move)
                    (cond
                     ((match-end md) ; a closer in regular expression, so we are climbing out
                      (setq depth (1- depth))
                      (if (= 0 depth) ; we are out!
                          (throw 'skip 1)))
                     ((match-end 1) ; an opener in the r-e, so we are in deeper now
                      (setq here (point)) ; remember where we started
                      (goto-char (match-beginning 1))
                      (cond
                       ((if (or
                             (looking-at verilog-disable-fork-re)
                             (and (looking-at "fork")
                                  (progn
                                    (forward-word-strictly -1)
                                    (looking-at verilog-disable-fork-re))))
                            (progn  ; it is a disable fork; another false alarm
                              (goto-char (match-end 0)))
                          (progn  ; it is a simple fork (or has nothing to do with fork)
                            (goto-char here)
                            (setq depth (1+ depth))))))))))
              (if (verilog-re-search-forward reg nil 'move)
                  (throw 'skip 1))))))

     ((looking-at (concat
                   "\\(\\<\\(macro\\)?module\\>\\)\\|"
                   "\\(\\<primitive\\>\\)\\|"
                   "\\(\\<class\\>\\)\\|"
                   "\\(\\<program\\>\\)\\|"
                   "\\(\\<interface\\>\\)\\|"
                   "\\(\\<package\\>\\)"))
      (cond
       ((match-end 1)
        (verilog-re-search-forward "\\<endmodule\\>" nil 'move))
       ((match-end 2)
        (verilog-re-search-forward "\\<endprimitive\\>" nil 'move))
       ((match-end 3)
        (verilog-re-search-forward "\\<endclass\\>" nil 'move))
       ((match-end 4)
        (verilog-re-search-forward "\\<endprogram\\>" nil 'move))
       ((match-end 5)
        (verilog-re-search-forward "\\<endinterface\\>" nil 'move))
       ((match-end 6)
        (verilog-re-search-forward "\\<endpackage\\>" nil 'move))
       (t
        (goto-char st)
        (if (= (following-char) ?\) )
            (forward-char 1)
          (forward-sexp 1)))))
     (t
      (goto-char st)
      (if (= (following-char) ?\) )
          (forward-char 1)
        (forward-sexp 1))))))

(defun verilog-declaration-beg ()
  (verilog-re-search-backward verilog-declaration-re (bobp) t))

;;
;;
;;  Mode
;;
(defvar verilog-which-tool 1)
;;;###autoload
(define-derived-mode verilog-mode prog-mode "Verilog"
  "Major mode for editing Verilog code.
\\<verilog-mode-map>
See \\[describe-function] verilog-auto (\\[verilog-auto]) for details on how
AUTOs can improve coding efficiency.

Use \\[verilog-faq] for a pointer to frequently asked questions.

NEWLINE, TAB indents for Verilog code.
Delete converts tabs to spaces as it moves back.

Supports highlighting.

Turning on Verilog mode calls the value of the variable `verilog-mode-hook'
with no args, if that value is non-nil.

Variables controlling indentation/edit style:

 variable `verilog-indent-level'      (default 3)
   Indentation of Verilog statements with respect to containing block.
 `verilog-indent-level-module'        (default 3)
   Absolute indentation of Module level Verilog statements.
   Set to 0 to get initial and always statements lined up
   on the left side of your screen.
 `verilog-indent-level-declaration'   (default 3)
   Indentation of declarations with respect to containing block.
   Set to 0 to get them list right under containing block.
 `verilog-indent-level-behavioral'    (default 3)
   Indentation of first begin in a task or function block
   Set to 0 to get such code to lined up underneath the task or
   function keyword.
 `verilog-indent-level-directive'     (default 1)
   Indentation of \\=`ifdef/\\=`endif blocks.
 `verilog-cexp-indent'              (default 1)
   Indentation of Verilog statements broken across lines i.e.:
      if (a)
        begin
 `verilog-case-indent'              (default 2)
   Indentation for case statements.
 `verilog-auto-newline'             (default nil)
   Non-nil means automatically newline after semicolons and the punctuation
   mark after an end.
 `verilog-indent-on-newline'   (default t)
   Non-nil means automatically indent line after newline.
 `verilog-tab-always-indent'        (default t)
   Non-nil means TAB in Verilog mode should always reindent the current line,
   regardless of where in the line point is when the TAB command is used.
 `verilog-indent-begin-after-if'    (default t)
   Non-nil means to indent begin statements following a preceding
   if, else, while, for and repeat statements, if any.  Otherwise,
   the begin is lined up with the preceding token.  If t, you get:
      if (a)
         begin // amount of indent based on `verilog-cexp-indent'
   otherwise you get:
      if (a)
      begin
 `verilog-auto-endcomments'         (default t)
   Non-nil means a comment /* ... */ is set after the ends which ends
   cases, tasks, functions and modules.
   The type and name of the object will be set between the braces.
 `verilog-minimum-comment-distance' (default 10)
   Minimum distance (in lines) between begin and end required before a comment
   will be inserted.  Setting this variable to zero results in every
   end acquiring a comment; the default avoids too many redundant
   comments in tight quarters.
 `verilog-auto-lineup'              (default `declarations')
   List of contexts where auto lineup of code should be done.

Variables controlling other actions:

   Unix program to call to run the lint checker.  This is the default
   command for \\[compile-command] and \\[verilog-auto-save-compile].

See \\[customize] for the complete list of variables.

AUTO expansion functions are, in part:

    \\[verilog-auto]  Expand AUTO statements.
    \\[verilog-delete-auto]  Remove the AUTOs.
    \\[verilog-inject-auto]  Insert AUTOs for the first time.

Some other functions are:

    \\[completion-at-point]    Complete word with appropriate possibilities.
    \\[verilog-mark-defun]  Mark function.
    \\[verilog-beg-of-defun]  Move to beginning of current function.
    \\[verilog-end-of-defun]  Move to end of current function.
    \\[verilog-label-be]  Label matching begin ... end, fork ... join, etc statements.

    \\[verilog-comment-region]  Put marked area in a comment.
    \\[verilog-uncomment-region]  Uncomment an area commented with \\[verilog-comment-region].
    \\[verilog-insert-block]  Insert begin ... end.
    \\[verilog-star-comment]    Insert /* ... */.

    \\[verilog-sk-always]  Insert an always @(AS) begin .. end block.
    \\[verilog-sk-begin]  Insert a begin .. end block.
    \\[verilog-sk-case]  Insert a case block, prompting for details.
    \\[verilog-sk-for]  Insert a for (...) begin .. end block, prompting for details.
    \\[verilog-sk-generate]  Insert a generate .. endgenerate block.
    \\[verilog-sk-header]  Insert a header block at the top of file.
    \\[verilog-sk-initial]  Insert an initial begin .. end block.
    \\[verilog-sk-fork]  Insert a fork begin .. end .. join block.
    \\[verilog-sk-module]  Insert a module .. (/*AUTOARG*/);.. endmodule block.
    \\[verilog-sk-ovm-class]  Insert an OVM Class block.
    \\[verilog-sk-uvm-object]  Insert an UVM Object block.
    \\[verilog-sk-uvm-component]  Insert an UVM Component block.
    \\[verilog-sk-primitive]  Insert a primitive .. (.. );.. endprimitive block.
    \\[verilog-sk-repeat]  Insert a repeat (..) begin .. end block.
    \\[verilog-sk-specify]  Insert a specify .. endspecify block.
    \\[verilog-sk-task]  Insert a task .. begin .. end endtask block.
    \\[verilog-sk-while]  Insert a while (...) begin .. end block, prompting for details.
    \\[verilog-sk-casex]  Insert a casex (...) item: begin.. end endcase block, prompting for details.
    \\[verilog-sk-casez]  Insert a casez (...) item: begin.. end endcase block, prompting for details.
    \\[verilog-sk-if]  Insert an if (..) begin .. end block.
    \\[verilog-sk-else-if]  Insert an else if (..) begin .. end block.
    \\[verilog-sk-comment]  Insert a comment block.
    \\[verilog-sk-assign]  Insert an assign .. = ..; statement.
    \\[verilog-sk-function]  Insert a function .. begin .. end endfunction block.
    \\[verilog-sk-input]  Insert an input declaration, prompting for details.
    \\[verilog-sk-output]  Insert an output declaration, prompting for details.
    \\[verilog-sk-state-machine]  Insert a state machine definition, prompting for details.
    \\[verilog-sk-inout]  Insert an inout declaration, prompting for details.
    \\[verilog-sk-wire]  Insert a wire declaration, prompting for details.
    \\[verilog-sk-reg]  Insert a register declaration, prompting for details.
    \\[verilog-sk-define-signal]  Define signal under point as a register at the top of the module.

All key bindings can be seen in a Verilog-buffer with \\[describe-bindings].
Key bindings specific to `verilog-mode-map' are:

\\{verilog-mode-map}"
  (set (make-local-variable 'beginning-of-defun-function)
       'verilog-beg-of-defun)
  (set (make-local-variable 'end-of-defun-function)
       'verilog-end-of-defun)
  (set-syntax-table verilog-mode-syntax-table)
  (set (make-local-variable 'indent-line-function)
       #'verilog-indent-line-relative)
  (set (make-local-variable 'comment-indent-function) 'verilog-comment-indent)
  (set (make-local-variable 'parse-sexp-ignore-comments) nil)
  (set (make-local-variable 'comment-start) "// ")
  (set (make-local-variable 'comment-end) "")
  (set (make-local-variable 'comment-start-skip) "/\\*+ *\\|// *")
  (set (make-local-variable 'comment-multi-line) nil)
  ;; Set up for compilation
  (setq verilog-which-tool 1)
  (when (boundp 'hack-local-variables-hook)  ; Also modify any file-local-variables
    (add-hook 'hack-local-variables-hook 'verilog-modify-compile-command t))

  ;; Stuff for GNU Emacs
  (set (make-local-variable 'font-lock-defaults)
       `((verilog-font-lock-keywords
          verilog-font-lock-keywords-1
          verilog-font-lock-keywords-2
          verilog-font-lock-keywords-3)
         nil nil nil
         ,(if (functionp 'syntax-ppss)
              ;; verilog-beg-of-defun uses syntax-ppss, and syntax-ppss uses
              ;; font-lock-beginning-of-syntax-function, so
              ;; font-lock-beginning-of-syntax-function, can't use
              ;; verilog-beg-of-defun.
              nil
            'verilog-beg-of-defun)))
  ;;------------------------------------------------------------
  ;; now hook in 'verilog-highlight-include-files (eldo-mode.el&spice-mode.el)
  ;; all buffer local:
  (unless noninteractive  ; Else can't see the result, and change hooks are slow
    (add-hook 'font-lock-mode-hook 'verilog-highlight-buffer t t)
    (add-hook 'font-lock-after-fontify-buffer-hook 'verilog-highlight-buffer t t) ; not in Emacs
    (add-hook 'after-change-functions 'verilog-highlight-region t t))

  ;; Tell imenu how to handle Verilog.
  (set (make-local-variable 'imenu-generic-expression)
       verilog-imenu-generic-expression)
  ;; Tell which-func-modes that imenu knows about verilog
  (when (and (boundp 'which-func-modes) (listp which-func-modes))
    (add-to-list 'which-func-modes 'verilog-mode))
  ;; hideshow support
  (when (boundp 'hs-special-modes-alist)
    (unless (assq 'verilog-mode hs-special-modes-alist)
      (setq hs-special-modes-alist
            (cons '(verilog-mode "\\<begin\\>" "\\<end\\>" nil
                                 verilog-forward-sexp-function)
                  hs-special-modes-alist))))

  (add-hook 'completion-at-point-functions
            #'verilog-completion-at-point nil 'local)

  ;; Stuff for autos
  (add-hook (if (boundp 'write-contents-hooks) 'write-contents-hooks
              'write-contents-functions) ; Emacs >= 22.1
            'verilog-auto-save-check nil 'local)
  ;; verilog-mode-hook call added by define-derived-mode
  )


;;; Electric functions:
;;

(defun electric-verilog-terminate-line (&optional arg)
  "Terminate line and indent next line.
With optional ARG, remove existing end of line comments."
  (interactive)
  ;; before that see if we are in a comment
  (let ((state (save-excursion (verilog-syntax-ppss))))
    (cond
     ((nth 7 state)			; Inside // comment
      (if (eolp)
          (progn
            (delete-horizontal-space)
            (newline))
        (progn
          (newline)
          (insert "// ")
          (beginning-of-line)))
      (verilog-indent-line))
     ((nth 4 state)			; Inside any comment (hence /**/)
      (newline)
      (verilog-more-comment))
     ((eolp)
      ;; First, check if current line should be indented
      (if (save-excursion
            (delete-horizontal-space)
            (beginning-of-line)
            (skip-chars-forward " \t")
            (if (looking-at verilog-auto-end-comment-lines-re)
                (let ((indent-str (verilog-indent-line)))
                  ;; Maybe we should set some endcomments
                  (if verilog-auto-endcomments
                      (verilog-set-auto-endcomments indent-str arg))
                  (end-of-line)
                  (delete-horizontal-space)
                  (if arg
                      ()
                    (newline))
                  nil)
              (progn
                (end-of-line)
                (delete-horizontal-space)
                't)))
          ;; see if we should line up assignments
          (progn
            (if (or (eq 'all verilog-auto-lineup)
                    (eq 'assignments verilog-auto-lineup))
                (verilog-pretty-expr :quiet))
            (newline))
        (forward-line 1))
      ;; Indent next line
      (if verilog-indent-on-newline
          (verilog-indent-line)))
     (t
      (newline)))))

(defun electric-verilog-terminate-and-indent ()
  "Insert a newline and indent for the next statement."
  (interactive)
  (electric-verilog-terminate-line 1))

(defun electric-verilog-semi ()
  "Insert `;' character and reindent the line."
  (interactive)
  (verilog-insert-last-command-event)

  (if (or (verilog-in-comment-or-string-p)
          (verilog-in-escaped-name-p))
      ()
    (save-excursion
      (beginning-of-line)
      (verilog-forward-ws&directives)
      (verilog-indent-line))
    (if (and verilog-auto-newline
             (not (verilog-parenthesis-depth)))
        (electric-verilog-terminate-line))))

(defun electric-verilog-semi-with-comment ()
  "Insert `;' character, reindent the line and indent for comment."
  (interactive)
  (insert ";")
  (save-excursion
    (beginning-of-line)
    (verilog-indent-line))
  (indent-for-comment))

(defun electric-verilog-colon ()
  "Insert `:' and do all indentations except line indent on this line."
  (interactive)
  (verilog-insert-last-command-event)
  ;; Do nothing if within string.
  (if (or
       (verilog-within-string-p)
       (not (verilog-in-case-region-p)))
      ()
    (save-excursion
      (let ((p (point))
            (lim (progn (verilog-beg-of-statement) (point))))
        (goto-char p)
        (verilog-backward-case-item lim)
        (verilog-indent-line)))
    ;; (let ((verilog-tab-always-indent nil))
    ;;   (verilog-indent-line))
    ))

;;(defun electric-verilog-equal ()
;;  "Insert `=', and do indentation if within block."
;;  (interactive)
;;  (verilog-insert-last-command-event)
;; Could auto line up expressions, but not yet
;;  (if (eq (car (verilog-calculate-indent)) 'block)
;;      (let ((verilog-tab-always-indent nil))
;;	(verilog-indent-command)))
;;  )

(defun electric-verilog-tick ()
  "Insert back-tick, and indent to column 0 if this is a CPP directive."
  (interactive)
  (verilog-insert-last-command-event)
  (save-excursion
    (if (verilog-in-directive-p)
        (verilog-indent-line))))

(defun electric-verilog-tab ()
  "Function called when TAB is pressed in Verilog mode."
  (interactive)
  ;; If verilog-tab-always-indent, indent the beginning of the line.
  (cond
   ;; The region is active, indent it.
   ((and (region-active-p)
         (not (eq (region-beginning) (region-end))))
    (indent-region (region-beginning) (region-end) nil))
   ((or verilog-tab-always-indent
        (save-excursion
          (skip-chars-backward " \t")
          (bolp)))
    (let* ((oldpnt (point))
           (boi-point
            (save-excursion
              (beginning-of-line)
              (skip-chars-forward " \t")
              (verilog-indent-line)
              (back-to-indentation)
              (point))))
      (if (< (point) boi-point)
          (back-to-indentation)
        (cond ((not verilog-tab-to-comment))
              ((not (eolp))
               (end-of-line))
              (t
               (indent-for-comment)
               (when (and (eolp) (= oldpnt (point)))
                 ;; kill existing comment
                 (beginning-of-line)
                 (re-search-forward comment-start-skip oldpnt 'move)
                 (goto-char (match-beginning 0))
                 (skip-chars-backward " \t")
                 (kill-region (point) oldpnt)))))))
   (t (progn (insert "\t")))))


;;; Interactive functions:
;;

(defun verilog-indent-buffer ()
  "Indent-region the entire buffer as Verilog code.
To call this from the command line, see \\[verilog-batch-indent]."
  (interactive)
  (verilog-mode)
  (verilog-auto-reeval-locals)
  (indent-region (point-min) (point-max) nil))

(defun verilog-insert-block ()
  "Insert Verilog begin ... end; block in the code with right indentation."
  (interactive)
  (verilog-indent-line)
  (insert "begin")
  (electric-verilog-terminate-line)
  (save-excursion
    (electric-verilog-terminate-line)
    (insert "end")
    (beginning-of-line)
    (verilog-indent-line)))

(defun verilog-star-comment ()
  "Insert Verilog star comment at point."
  (interactive)
  (verilog-indent-line)
  (insert "/*")
  (save-excursion
    (newline)
    (insert " */"))
  (newline)
  (insert " * "))

(defun verilog-insert-1 (fmt max)
  "Use format string FMT to insert integers 0 to MAX - 1.
Inserts one integer per line, at the current column.  Stops early
if it reaches the end of the buffer."
  (let ((col (current-column))
        (n 0))
    (save-excursion
      (while (< n max)
        (insert (format fmt n))
        (forward-line 1)
        ;; Note that this function does not bother to check for lines
        ;; shorter than col.
        (if (eobp)
            (setq n max)
          (setq n (1+ n))
          (move-to-column col))))))

(defun verilog-insert-indices (max)
  "Insert a set of indices into a rectangle.
The upper left corner is defined by point.  Indices begin with 0
and extend to the MAX - 1.  If no prefix arg is given, the user
is prompted for a value.  The indices are surrounded by square
brackets [].  For example, the following code with the point
located after the first `a' gives:

    a = b                           a[  0] = b
    a = b                           a[  1] = b
    a = b                           a[  2] = b
    a = b                           a[  3] = b
    a = b   ==> insert-indices ==>  a[  4] = b
    a = b                           a[  5] = b
    a = b                           a[  6] = b
    a = b                           a[  7] = b
    a = b                           a[  8] = b"

  (interactive "NMAX: ")
  (verilog-insert-1 "[%3d]" max))

(defun verilog-generate-numbers (max)
  "Insert a set of generated numbers into a rectangle.
The upper left corner is defined by point.  The numbers are padded to three
digits, starting with 000 and extending to (MAX - 1).  If no prefix argument
is supplied, then the user is prompted for the MAX number.  Consider the
following code fragment:

    buf buf                             buf buf000
    buf buf                             buf buf001
    buf buf                             buf buf002
    buf buf                             buf buf003
    buf buf   ==> generate-numbers ==>  buf buf004
    buf buf                             buf buf005
    buf buf                             buf buf006
    buf buf                             buf buf007
    buf buf                             buf buf008"

  (interactive "NMAX: ")
  (verilog-insert-1 "%3.3d" max))

(defun verilog-mark-defun ()
  "Mark the current Verilog function (or procedure).
This puts the mark at the end, and point at the beginning."
  (interactive)
  (mark-defun))

(defun verilog-comment-region (start end)
  ;; checkdoc-params: (start end)
  "Put the region into a Verilog comment.
The comments that are in this area are \"deformed\":
`*)' becomes `!(*' and `}' becomes `!{'.
These deformed comments are returned to normal if you use
\\[verilog-uncomment-region] to undo the commenting.

The commented area starts with `verilog-exclude-str-start', and ends with
`verilog-exclude-str-end'.  But if you change these variables,
\\[verilog-uncomment-region] won't recognize the comments."
  (interactive "r")
  (save-excursion
    ;; Insert start and endcomments
    (goto-char end)
    (if (and (save-excursion (skip-chars-forward " \t") (eolp))
             (not (save-excursion (skip-chars-backward " \t") (bolp))))
        (forward-line 1)
      (beginning-of-line))
    (insert verilog-exclude-str-end)
    (setq end (point))
    (newline)
    (goto-char start)
    (beginning-of-line)
    (insert verilog-exclude-str-start)
    (newline)
    ;; Replace end-comments within commented area
    (goto-char end)
    (save-excursion
      (while (re-search-backward "\\*/" start t)
        (replace-match "*-/" t t)))
    (save-excursion
      (let ((s+1 (1+ start)))
        (while (re-search-backward "/\\*" s+1 t)
          (replace-match "/-*" t t))))))

(defun verilog-uncomment-region ()
  "Uncomment a commented area; change deformed comments back to normal.
This command does nothing if the pointer is not in a commented
area.  See also `verilog-comment-region'."
  (interactive)
  (save-excursion
    (let ((start (point))
          (end (point)))
      ;; Find the boundaries of the comment
      (save-excursion
        (setq start (progn (search-backward verilog-exclude-str-start nil t)
                           (point)))
        (setq end (progn (search-forward verilog-exclude-str-end nil t)
                         (point))))
      ;; Check if we're really inside a comment
      (if (or (equal start (point)) (<= end (point)))
          (message "Not standing within commented area.")
        (progn
          ;; Remove endcomment
          (goto-char end)
          (beginning-of-line)
          (let ((pos (point)))
            (end-of-line)
            (delete-region pos (1+ (point))))
          ;; Change comments back to normal
          (save-excursion
            (while (re-search-backward "\\*-/" start t)
              (replace-match "*/" t t)))
          (save-excursion
            (while (re-search-backward "/-\\*" start t)
              (replace-match "/*" t t)))
          ;; Remove start comment
          (goto-char start)
          (beginning-of-line)
          (let ((pos (point)))
            (end-of-line)
            (delete-region pos (1+ (point)))))))))

(defun verilog-beg-of-defun ()
  "Move backward to the beginning of the current function or procedure."
  (interactive)
  (verilog-re-search-backward verilog-defun-re nil 'move))

(defun verilog-beg-of-defun-quick ()
  "Move backward to the beginning of the current function or procedure.
Uses `verilog-scan' cache."
  (interactive)
  (verilog-re-search-backward-quick verilog-defun-re nil 'move))

(defun verilog-end-of-defun ()
  "Move forward to the end of the current function or procedure."
  (interactive)
  (verilog-re-search-forward verilog-end-defun-re nil 'move))

(defun verilog-get-end-of-defun ()
  (save-excursion
    (cond ((verilog-re-search-forward-quick verilog-end-defun-re nil t)
           (point))
          (t
           (error "%s: Can't find endmodule" (verilog-point-text))
           (point-max)))))

(defun verilog-label-be ()
  "Label matching begin ... end, fork ... join and case ... endcase statements."
  (interactive)
  (let ((cnt 0)
        (case-fold-search nil)
        (oldpos (point))
        (b (progn
             (verilog-beg-of-defun)
             (point-marker)))
        (e (progn
             (verilog-end-of-defun)
             (point-marker))))
    (goto-char (marker-position b))
    (if (> (- e b) 200)
        (message "Relabeling module..."))
    (while (and
            (> (marker-position e) (point))
            (verilog-re-search-forward
             verilog-auto-end-comment-lines-re
             nil 'move))
      (goto-char (match-beginning 0))
      (let ((indent-str (verilog-indent-line)))
        (verilog-set-auto-endcomments indent-str 't)
        (end-of-line)
        (delete-horizontal-space))
      (setq cnt (1+ cnt))
      (if (= 9 (% cnt 10))
          (message "%d..." cnt)))
    (goto-char oldpos)
    (if (or
         (> (- e b) 200)
         (> cnt 20))
        (message "%d lines auto commented" cnt))))

(defun verilog-beg-of-statement ()
  "Move backward to beginning of statement."
  (interactive)
  ;; Move back token by token until we see the end
  ;; of some earlier line.
  (let (h)
    (while
        ;; If the current point does not begin a new
        ;; statement, as in the character ahead of us is a ';', or SOF
        ;; or the string after us unambiguously starts a statement,
        ;; or the token before us unambiguously ends a statement,
        ;; then move back a token and test again.
        (not (or
              ;; stop if beginning of buffer
              (bobp)
              ;; stop if looking at a pre-processor directive
              (looking-at "`\\w+")
              ;; stop if we find a ;
              (= (preceding-char) ?\;)
              ;; stop if we see a named coverpoint
              (looking-at "\\w+\\W*:\\W*\\(coverpoint\\|cross\\|constraint\\)")
              ;; keep going if we are in the middle of a word
              (not (or (looking-at "\\<") (forward-word-strictly -1)))
              ;; stop if we see an assertion (perhaps labeled)
              (and
               (looking-at "\\(\\w+\\W*:\\W*\\)?\\(\\<\\(assert\\|assume\\|cover\\)\\>\\s-+\\<property\\>\\)\\|\\(\\<assert\\>\\)")
               (progn
                 (setq h (point))
                 (save-excursion
                   (verilog-backward-token)
                   (if (and (looking-at verilog-label-re)
                            (not (looking-at verilog-end-block-re)))
                       (setq h (point))))
                 (goto-char h)))
              ;; stop if we see an extended complete reg, perhaps a complete one
              (and
               (looking-at verilog-complete-reg)
               (let* ((p (point)))
                 (while (and (looking-at verilog-extended-complete-re)
                             (progn (setq p (point))
                                    (verilog-backward-token)
                                    (/= p (point)))))
                 (goto-char p)))
              ;; stop if we see a complete reg (previous found extended ones)
              (looking-at verilog-basic-complete-re)
              ;; stop if previous token is an ender
              (save-excursion
                (verilog-backward-token)
                (looking-at verilog-end-block-re))))
      (verilog-backward-syntactic-ws)
      (verilog-backward-token))
    ;; Now point is where the previous line ended.
    (verilog-forward-syntactic-ws)
    ;; Skip forward over any preprocessor directives, as they have wacky indentation
    (if (looking-at verilog-preprocessor-re)
        (progn (goto-char (match-end 0))
               (verilog-forward-syntactic-ws)))))

(defun verilog-beg-of-statement-1 ()
  "Move backward to beginning of statement."
  (interactive)
  (if (verilog-in-comment-p)
      (verilog-backward-syntactic-ws))
  (let ((pt (point)))
    (catch 'done
      (while (not (looking-at verilog-complete-reg))
        (setq pt (point))
        (verilog-backward-syntactic-ws)
        (if (or (bolp)
                (= (preceding-char) ?\;)
                (progn
                  (verilog-backward-token)
                  (looking-at verilog-ends-re)))
            (progn
              (goto-char pt)
              (throw 'done t)))))
    (verilog-forward-syntactic-ws)))
;;
;;      (while (and
;;              (not (looking-at verilog-complete-reg))
;;              (not (bolp))
;;              (not (= (preceding-char) ?\;)))
;;        (verilog-backward-token)
;;        (verilog-backward-syntactic-ws)
;;        (setq pt (point)))
;;      (goto-char pt)
;;   ;(verilog-forward-syntactic-ws)

(defun verilog-end-of-statement ()
  "Move forward to end of current statement."
  (interactive)
  (let ((nest 0) pos)
    (cond
     ((verilog-in-directive-p)
      (forward-line 1)
      (backward-char 1))

     ((looking-at verilog-beg-block-re)
      (verilog-forward-sexp))

     ((equal (char-after) ?\})
      (forward-char))

     ;; Skip to end of statement
     ((condition-case nil
          (setq pos
                (catch 'found
                  (while t
                    (forward-sexp 1)
                    (verilog-skip-forward-comment-or-string)
                    (if (eolp)
                        (forward-line 1))
                    (cond ((looking-at "[ \t]*;")
                           (skip-chars-forward "^;")
                           (forward-char 1)
                           (throw 'found (point)))
                          ((save-excursion
                             (forward-sexp -1)
                             (looking-at verilog-beg-block-re))
                           (goto-char (match-beginning 0))
                           (throw 'found nil))
                          ((looking-at "[ \t]*)")
                           (throw 'found (point)))
                          ((eobp)
                           (throw 'found (point)))
                          )))

                )
        (error nil))
      (if (not pos)
          ;; Skip a whole block
          (catch 'found
            (while t
              (verilog-re-search-forward verilog-end-statement-re nil 'move)
              (setq nest (if (match-end 1)
                             (1+ nest)
                           (1- nest)))
              (cond ((eobp)
                     (throw 'found (point)))
                    ((= 0 nest)
                     (throw 'found (verilog-end-of-statement))))))
        pos)))))

(defun verilog-in-case-region-p ()
  "Return true if in a case region.
More specifically, point @ in the line foo : @ begin"
  (interactive)
  (save-excursion
    (if (and
         (progn (verilog-forward-syntactic-ws)
                (looking-at "\\<begin\\>"))
         (progn (verilog-backward-syntactic-ws)
                (= (preceding-char) ?\:)))
        (catch 'found
          (let ((nest 1))
            (while t
              (verilog-re-search-backward
               (concat "\\(\\<module\\>\\)\\|\\(\\<randcase\\>\\|\\<case[xz]?\\>[^:]\\)\\|"
                       "\\(\\<endcase\\>\\)\\>")
               nil 'move)
              (cond
               ((match-end 3)
                (setq nest (1+ nest)))
               ((match-end 2)
                (if (= nest 1)
                    (throw 'found 1))
                (setq nest (1- nest)))
               (t
                (throw 'found (= nest 0)))))))
      nil)))

(defun verilog-backward-up-list (arg)
  "Call `backward-up-list' ARG, ignoring comments."
  (let ((parse-sexp-ignore-comments t))
    (backward-up-list arg)))

(defun verilog-forward-sexp-cmt (arg)
  "Call `forward-sexp' ARG, inside comments."
  (let ((parse-sexp-ignore-comments nil))
    (forward-sexp arg)))

(defun verilog-forward-sexp-ign-cmt (arg)
  "Call `forward-sexp' ARG, ignoring comments."
  (let ((parse-sexp-ignore-comments t))
    (forward-sexp arg)))

(defun verilog-in-generate-region-p ()
  "Return true if in a generate region.
More specifically, after a generate and before an endgenerate."
  (interactive)
  (let ((nest 1))
    (save-excursion
      (catch 'done
        (while (and
                (/= nest 0)
                (verilog-re-search-backward
                 "\\<\\(module\\)\\|\\(generate\\)\\|\\(endgenerate\\)\\>" nil 'move)
                (cond
                 ((match-end 1) ; module - we have crawled out
                  (throw 'done 1))
                 ((match-end 2) ; generate
                  (setq nest (1- nest)))
                 ((match-end 3) ; endgenerate
                  (setq nest (1+ nest))))))))
    (= nest 0) )) ; return nest

(defun verilog-in-fork-region-p ()
  "Return true if between a fork and join."
  (interactive)
  (let ((lim (save-excursion (verilog-beg-of-defun)  (point)))
        (nest 1))
    (save-excursion
      (while (and
              (/= nest 0)
              (verilog-re-search-backward "\\<\\(fork\\)\\|\\(join\\(_any\\|_none\\)?\\)\\>" lim 'move)
              (cond
               ((match-end 1) ; fork
                (setq nest (1- nest)))
               ((match-end 2) ; join
                (setq nest (1+ nest)))))))
    (= nest 0) )) ; return nest

(defun verilog-in-deferred-immediate-final-p ()
  "Return true if inside an `assert/assume/cover final' statement."
  (interactive)
  (and (looking-at "final")
       (looking-back "\\<\\(?:assert\\|assume\\|cover\\)\\>\\s-+" nil))
  )

(defun verilog-backward-case-item (lim)
  "Skip backward to nearest enclosing case item.
Limit search to point LIM."
  (interactive)
  (let ((str 'nil)
        (lim1
         (progn
           (save-excursion
             (verilog-re-search-backward verilog-endcomment-reason-re
                                         lim 'move)
             (point)))))
    ;; Try to find the real :
    (if (save-excursion (search-backward ":" lim1 t))
        (let ((colon 0)
              b e )
          (while
              (and
               (< colon 1)
               (verilog-re-search-backward "\\(\\[\\)\\|\\(\\]\\)\\|\\(:\\)"
                                           lim1 'move))
            (cond
             ((match-end 1)  ; [
              (setq colon (1+ colon))
              (if (>= colon 0)
                  (error "%s: unbalanced [" (verilog-point-text))))
             ((match-end 2)  ; ]
              (setq colon (1- colon)))

             ((match-end 3)  ; :
              (setq colon (1+ colon)))))
          ;; Skip back to beginning of case item
          (skip-chars-backward "\t ")
          (verilog-skip-backward-comment-or-string)
          (setq e (point))
          (setq b
                (progn
                  (if
                      (verilog-re-search-backward
                       "\\<\\(randcase\\|case[zx]?\\)\\>\\|;\\|\\<end\\>" nil 'move)
                      (progn
                        (cond
                         ((match-end 1)
                          (goto-char (match-end 1))
                          (verilog-forward-ws&directives)
                          (if (looking-at "(")
                              (progn
                                (forward-sexp)
                                (verilog-forward-ws&directives)))
                          (point))
                         (t
                          (goto-char (match-end 0))
                          (verilog-forward-ws&directives)
                          (point))))
                    (error "Malformed case item"))))
          (setq str (buffer-substring b e))
          (if
              (setq e
                    (string-match
                     "[ \t]*\\(\\(\n\\)\\|\\(//\\)\\|\\(/\\*\\)\\)" str))
              (setq str (concat (substring str 0 e) "...")))
          str)
      'nil)))

;;; Other functions:
;;

(defun verilog-kill-existing-comment ()
  "Kill auto comment on this line."
  (save-excursion
    (let* (
           (e (progn
                (end-of-line)
                (point)))
           (b (progn
                (beginning-of-line)
                (search-forward "//" e t))))
      (if b
          (delete-region (- b 2) e)))))

(defconst verilog-directive-nest-re
  (concat "\\(`else\\>\\)\\|"
          "\\(`endif\\>\\)\\|"
          "\\(`if\\>\\)\\|"
          "\\(`ifdef\\>\\)\\|"
          "\\(`ifndef\\>\\)\\|"
          "\\(`elsif\\>\\)"))

(defun verilog-set-auto-endcomments (indent-str kill-existing-comment)
  "Add ending comment with given INDENT-STR.
With KILL-EXISTING-COMMENT, remove what was there before.
Insert `// case: 7 ' or `// NAME ' on this line if appropriate.
Insert `// case expr ' if this line ends a case block.
Insert `// ifdef FOO ' if this line ends code conditional on FOO.
Insert `// NAME ' if this line ends a function, task, module,
primitive or interface named NAME."
  (save-excursion
    (cond
     (; Comment close preprocessor directives
      (and
       (looking-at "\\(`endif\\)\\|\\(`else\\)")
       (or  kill-existing-comment
            (not (save-excursion
                   (end-of-line)
                   (search-backward "//" (point-at-bol) t)))))
      (let ((nest 1) b e
            m
            (else (if (match-end 2) "!" " ")))
        (end-of-line)
        (if kill-existing-comment
            (verilog-kill-existing-comment))
        (delete-horizontal-space)
        (save-excursion
          (backward-sexp 1)
          (while (and (/= nest 0)
                      (verilog-re-search-backward verilog-directive-nest-re nil 'move))
            (cond
             ((match-end 1) ; `else
              (if (= nest 1)
                  (setq else "!")))
             ((match-end 2) ; `endif
              (setq nest (1+ nest)))
             ((match-end 3) ; `if
              (setq nest (1- nest)))
             ((match-end 4) ; `ifdef
              (setq nest (1- nest)))
             ((match-end 5) ; `ifndef
              (setq nest (1- nest)))
             ((match-end 6) ; `elsif
              (if (= nest 1)
                  (progn
                    (setq else "!")
                    (setq nest 0))))))
          (if (match-end 0)
              (setq
               m (buffer-substring
                  (match-beginning 0)
                  (match-end 0))
               b (progn
                   (skip-chars-forward "^ \t")
                   (verilog-forward-syntactic-ws)
                   (point))
               e (progn
                   (skip-chars-forward "a-zA-Z0-9_")
                   (point)))))
        (if b
            (if (> (count-lines (point) b) verilog-minimum-comment-distance)
                (insert (concat " // " else m " " (buffer-substring b e))))
          (progn
            (insert " // unmatched `else, `elsif or `endif")
            (ding 't)))))

     (; Comment close case/class/function/task/module and named block
      (and (looking-at "\\<end")
           (or kill-existing-comment
               (not (save-excursion
                      (end-of-line)
                      (search-backward "//" (point-at-bol) t)))))
      (let ((type (car indent-str)))
        (unless (eq type 'declaration)
          (unless (looking-at (concat "\\(" verilog-end-block-ordered-re "\\)[ \t]*:"))  ; ignore named ends
            (if (looking-at verilog-end-block-ordered-re)
                (cond
                 (;- This is a case block; search back for the start of this case
                  (match-end 1)  ; of verilog-end-block-ordered-re

                  (let ((err 't)
                        (str "UNMATCHED!!"))
                    (save-excursion
                      (verilog-leap-to-head)
                      (cond
                       ((looking-at "\\<randcase\\>")
                        (setq str "randcase")
                        (setq err nil))
                       ((looking-at "\\(\\(unique0?\\s-+\\|priority\\s-+\\)?case[xz]?\\)")
                        (goto-char (match-end 0))
                        (setq str (concat (match-string 0) " " (verilog-get-expr)))
                        (setq err nil))
                       ))
                    (end-of-line)
                    (if kill-existing-comment
                        (verilog-kill-existing-comment))
                    (delete-horizontal-space)
                    (insert (concat " // " str ))
                    (if err (ding 't))))

                 (;- This is a begin..end block
                  (match-end 2)  ; of verilog-end-block-ordered-re
                  (let ((str " // UNMATCHED !!")
                        (err 't)
                        (here (point))
                        there
                        cntx)
                    (save-excursion
                      (verilog-leap-to-head)
                      (setq there (point))
                      (if (not (match-end 0))
                          (progn
                            (goto-char here)
                            (end-of-line)
                            (if kill-existing-comment
                                (verilog-kill-existing-comment))
                            (delete-horizontal-space)
                            (insert str)
                            (ding 't))
                        (let ((lim
                               (save-excursion (verilog-beg-of-defun) (point)))
                              (here (point)))
                          (cond
                           (;-- handle named block differently
                            (looking-at verilog-named-block-re)
                            (search-forward ":")
                            (setq there (point))
                            (setq str (verilog-get-expr))
                            (setq err nil)
                            (setq str (concat " // block: " str )))

                           ((verilog-in-case-region-p) ;-- handle case item differently
                            (goto-char here)
                            (setq str (verilog-backward-case-item lim))
                            (setq there (point))
                            (setq err nil)
                            (setq str (concat " // case: " str )))

                           (;- try to find "reason" for this begin
                            (cond
                             (;
                              (eq here (progn
                                         ;;   (verilog-backward-token)
                                         (verilog-beg-of-statement)
                                         (point)))
                              (setq err nil)
                              (setq str ""))
                             ((looking-at verilog-endcomment-reason-re)
                              (setq there (match-end 0))
                              (setq cntx (concat (match-string 0) " "))
                              (cond
                               (;- begin
                                (match-end 1)
                                (setq err nil)
                                (save-excursion
                                  (if (and (verilog-continued-line)
                                           (looking-at "\\<repeat\\>\\|\\<wait\\>\\|\\<always\\>"))
                                      (progn
                                        (goto-char (match-end 0))
                                        (setq there (point))
                                        (setq str
                                              (concat " // " (match-string 0) " " (verilog-get-expr))))
                                    (setq str ""))))

                               (;- else
                                (match-end 2)
                                (let ((nest 0)
                                      ( reg "\\(\\<begin\\>\\)\\|\\(\\<end\\>\\)\\|\\(\\<if\\>\\)\\|\\(assert\\)"))
                                  (catch 'skip
                                    (while (verilog-re-search-backward reg nil 'move)
                                      (cond
                                       ((match-end 1) ; begin
                                        (setq nest (1- nest)))
                                       ((match-end 2)                       ; end
                                        (setq nest (1+ nest)))
                                       ((match-end 3)
                                        (if (= 0 nest)
                                            (progn
                                              (goto-char (match-end 0))
                                              (setq there (point))
                                              (setq err nil)
                                              (setq str (verilog-get-expr))
                                              (setq str (concat " // else: !if" str ))
                                              (throw 'skip 1))))
                                       ((match-end 4)
                                        (if (= 0 nest)
                                            (progn
                                              (goto-char (match-end 0))
                                              (setq there (point))
                                              (setq err nil)
                                              (setq str (verilog-get-expr))
                                              (setq str (concat " // else: !assert " str ))
                                              (throw 'skip 1)))))))))
                               (;- end else
                                (match-end 3)
                                (goto-char there)
                                (let ((nest 0)
                                      (reg "\\(\\<begin\\>\\)\\|\\(\\<end\\>\\)\\|\\(\\<if\\>\\)\\|\\(assert\\)"))
                                  (catch 'skip
                                    (while (verilog-re-search-backward reg nil 'move)
                                      (cond
                                       ((match-end 1) ; begin
                                        (setq nest (1- nest)))
                                       ((match-end 2)                       ; end
                                        (setq nest (1+ nest)))
                                       ((match-end 3)
                                        (if (= 0 nest)
                                            (progn
                                              (goto-char (match-end 0))
                                              (setq there (point))
                                              (setq err nil)
                                              (setq str (verilog-get-expr))
                                              (setq str (concat " // else: !if" str ))
                                              (throw 'skip 1))))
                                       ((match-end 4)
                                        (if (= 0 nest)
                                            (progn
                                              (goto-char (match-end 0))
                                              (setq there (point))
                                              (setq err nil)
                                              (setq str (verilog-get-expr))
                                              (setq str (concat " // else: !assert " str ))
                                              (throw 'skip 1)))))))))

                               (; always, always_comb, always_latch w/o @...
                                (match-end 5)
                                (goto-char (match-end 0))
                                (setq there (point))
                                (setq err nil)
                                (setq str (concat " // " cntx )))

                               (;- task/function/initial et cetera
                                t
                                (match-end 0)
                                (goto-char (match-end 0))
                                (setq there (point))
                                (setq err nil)
                                (setq str (concat " // " cntx (verilog-get-expr))))

                               (;-- otherwise...
                                (setq str " // auto-endcomment confused "))))

                             ((and
                               (verilog-in-case-region-p) ;-- handle case item differently
                               (progn
                                 (setq there (point))
                                 (goto-char here)
                                 (setq str (verilog-backward-case-item lim))))
                              (setq err nil)
                              (setq str (concat " // case: " str )))

                             ((verilog-in-fork-region-p)
                              (setq err nil)
                              (setq str " // fork branch" ))

                             ((looking-at "\\<end\\>")
                              ;; HERE
                              (forward-word-strictly 1)
                              (verilog-forward-syntactic-ws)
                              (setq err nil)
                              (setq str (verilog-get-expr))
                              (setq str (concat " // " cntx str )))

                             ))))
                        (goto-char here)
                        (end-of-line)
                        (if kill-existing-comment
                            (verilog-kill-existing-comment))
                        (delete-horizontal-space)
                        (if (or err
                                (> (count-lines here there) verilog-minimum-comment-distance))
                            (insert str))
                        (if err (ding 't))
                        ))))
                 (;- this is endclass, which can be nested
                  (match-end 11)  ; of verilog-end-block-ordered-re
                  ;;(goto-char there)
                  (let ((nest 0)
                        (reg "\\<\\(\\(class\\)\\|\\(endclass\\)\\|\\(package\\|primitive\\|\\(macro\\)?module\\)\\)\\>")
                        string)
                    (save-excursion
                      (catch 'skip
                        (while (verilog-re-search-backward reg nil 'move)
                          (cond
                           ((match-end 4)       ; endclass
                            (ding 't)
                            (setq string "unmatched endclass")
                            (throw 'skip 1))

                           ((match-end 3)       ; endclass
                            (setq nest (1+ nest)))

                           ((match-end 2) ; class
                            (setq nest (1- nest))
                            (if (< nest 0)
                                (progn
                                  (goto-char (match-end 0))
                                  (let (b e)
                                    (setq b (progn
                                              (skip-chars-forward "^ \t")
                                              (verilog-forward-ws&directives)
                                              (point))
                                          e (progn
                                              (skip-chars-forward "a-zA-Z0-9_")
                                              (point)))
                                    (setq string (buffer-substring b e)))
                                  (throw 'skip 1))))
                           ))))
                    (end-of-line)
                    (if kill-existing-comment
                        (verilog-kill-existing-comment))
                    (delete-horizontal-space)
                    (insert (concat " // " string ))))

                 (;  - this is end{function,generate,task,module,primitive,table,generate}
                  ;; - which can not be nested.
                  t
                  (let (string reg (name-re nil))
                    (end-of-line)
                    (if kill-existing-comment
                        (save-match-data
                          (verilog-kill-existing-comment)))
                    (delete-horizontal-space)
                    (backward-sexp)
                    (cond
                     ((match-end 5)  ; of verilog-end-block-ordered-re
                      (setq reg "\\(\\<function\\>\\)\\|\\(\\<\\(endfunction\\|task\\|\\(macro\\)?module\\|primitive\\)\\>\\)")
                      (setq name-re "\\w+\\(?:\n\\|\\s-\\)*[(;]"))
                     ((match-end 6)  ; of verilog-end-block-ordered-re
                      (setq reg "\\(\\<task\\>\\)\\|\\(\\<\\(endtask\\|function\\|\\(macro\\)?module\\|primitive\\)\\>\\)")
                      (setq name-re "\\w+\\(?:\n\\|\\s-\\)*[(;]"))
                     ((match-end 7)  ; of verilog-end-block-ordered-re
                      (setq reg "\\(\\<\\(macro\\)?module\\>\\)\\|\\<endmodule\\>"))
                     ((match-end 8)  ; of verilog-end-block-ordered-re
                      (setq reg "\\(\\<primitive\\>\\)\\|\\(\\<\\(endprimitive\\|package\\|interface\\|\\(macro\\)?module\\)\\>\\)"))
                     ((match-end 9)  ; of verilog-end-block-ordered-re
                      (setq reg "\\(\\<interface\\>\\)\\|\\(\\<\\(endinterface\\|package\\|primitive\\|\\(macro\\)?module\\)\\>\\)"))
                     ((match-end 10)  ; of verilog-end-block-ordered-re
                      (setq reg "\\(\\<package\\>\\)\\|\\(\\<\\(endpackage\\|primitive\\|interface\\|\\(macro\\)?module\\)\\>\\)"))
                     ((match-end 11)  ; of verilog-end-block-ordered-re
                      (setq reg "\\(\\<class\\>\\)\\|\\(\\<\\(endclass\\|primitive\\|interface\\|\\(macro\\)?module\\)\\>\\)"))
                     ((match-end 12)  ; of verilog-end-block-ordered-re
                      (setq reg "\\(\\<covergroup\\>\\)\\|\\(\\<\\(endcovergroup\\|primitive\\|interface\\|\\(macro\\)?module\\)\\>\\)"))
                     ((match-end 13)  ; of verilog-end-block-ordered-re
                      (setq reg "\\(\\<program\\>\\)\\|\\(\\<\\(endprogram\\|primitive\\|interface\\|\\(macro\\)?module\\)\\>\\)"))
                     ((match-end 14)  ; of verilog-end-block-ordered-re
                      (setq reg "\\(\\<\\(rand\\)?sequence\\>\\)\\|\\(\\<\\(endsequence\\|primitive\\|interface\\|\\(macro\\)?module\\)\\>\\)"))
                     ((match-end 15)  ; of verilog-end-block-ordered-re
                      (setq reg "\\(\\<clocking\\>\\)\\|\\<endclocking\\>"))
                     ((match-end 16)  ; of verilog-end-block-ordered-re
                      (setq reg "\\(\\<property\\>\\)\\|\\<endproperty\\>"))

                     (t (error "Problem in verilog-set-auto-endcomments")))
                    (let (b e)
                      (save-excursion
                        (verilog-re-search-backward reg nil 'move)
                        (cond
                         ((match-end 1)
                          (setq b (progn
                                    (skip-chars-forward "^ \t")
                                    (verilog-forward-ws&directives)
                                    (if (looking-at "static\\|automatic")
                                        (progn
                                          (goto-char (match-end 0))
                                          (verilog-forward-ws&directives)))
                                    (if (and name-re (verilog-re-search-forward name-re nil 'move))
                                        (progn
                                          (goto-char (match-beginning 0))
                                          (verilog-forward-ws&directives)))
                                    (point))
                                e (progn
                                    (skip-chars-forward "a-zA-Z0-9_")
                                    (point)))
                          (setq string (buffer-substring b e)))
                         (t
                          (ding 't)
                          (setq string "unmatched end(function|task|module|primitive|interface|package|class|clocking)")))))
                    (end-of-line)
                    (insert (concat " // " string )))
                  ))))))))))

(defun verilog-get-expr()
  "Grab expression at point, e.g., case ( a | b & (c ^d))."
  (let* ((b (progn
              (verilog-forward-syntactic-ws)
              (skip-chars-forward " \t")
              (point)))
         (e (let ((par 1))
              (cond
               ((looking-at "@")
                (forward-char 1)
                (verilog-forward-syntactic-ws)
                (if (looking-at "(")
                    (progn
                      (forward-char 1)
                      (while (and (/= par 0)
                                  (verilog-re-search-forward "\\((\\)\\|\\()\\)" nil 'move))
                        (cond
                         ((match-end 1)
                          (setq par (1+ par)))
                         ((match-end 2)
                          (setq par (1- par)))))))
                (point))
               ((looking-at "(")
                (forward-char 1)
                (while (and (/= par 0)
                            (verilog-re-search-forward "\\((\\)\\|\\()\\)" nil 'move))
                  (cond
                   ((match-end 1)
                    (setq par (1+ par)))
                   ((match-end 2)
                    (setq par (1- par)))))
                (point))
               ((looking-at "\\[")
                (forward-char 1)
                (while (and (/= par 0)
                            (verilog-re-search-forward "\\(\\[\\)\\|\\(\\]\\)" nil 'move))
                  (cond
                   ((match-end 1)
                    (setq par (1+ par)))
                   ((match-end 2)
                    (setq par (1- par)))))
                (verilog-forward-syntactic-ws)
                (skip-chars-forward "^ \t\n\f")
                (point))
               ((looking-at "/[/\\*]")
                b)
               ('t
                (skip-chars-forward "^: \t\n\f")
                (point)))))
         (str (buffer-substring b e)))
    (if (setq e (string-match "[ \t]*\\(\\(\n\\)\\|\\(//\\)\\|\\(/\\*\\)\\)" str))
        (setq str (concat (substring str 0 e) "...")))
    str))

(defun verilog-expand-vector ()
  "Take a signal vector on the current line and expand it to multiple lines.
Useful for creating tri's and other expanded fields."
  (interactive)
  (verilog-expand-vector-internal "[" "]"))

(defun verilog-expand-vector-internal (bra ket)
  "Given BRA, the start brace and KET, the end brace, expand one line into many lines."
  (save-excursion
    (forward-line 0)
    (let ((signal-string (buffer-substring (point)
                                           (progn
                                             (end-of-line) (point)))))
      (if (string-match
           (concat "\\(.*\\)"
                   (regexp-quote bra)
                   "\\([0-9]*\\)\\(:[0-9]*\\|\\)\\(::[0-9---]*\\|\\)"
                   (regexp-quote ket)
                   "\\(.*\\)$") signal-string)
          (let* ((sig-head (match-string 1 signal-string))
                 (vec-start (string-to-number (match-string 2 signal-string)))
                 (vec-end (if (= (match-beginning 3) (match-end 3))
                              vec-start
                            (string-to-number
                             (substring signal-string (1+ (match-beginning 3))
                                        (match-end 3)))))
                 (vec-range
                  (if (= (match-beginning 4) (match-end 4))
                      1
                    (string-to-number
                     (substring signal-string (+ 2 (match-beginning 4))
                                (match-end 4)))))
                 (sig-tail (match-string 5 signal-string))
                 vec)
            ;; Decode vectors
            (setq vec nil)
            (if (< vec-range 0)
                (let ((tmp vec-start))
                  (setq vec-start vec-end
                        vec-end tmp
                        vec-range (- vec-range))))
            (if (< vec-end vec-start)
                (while (<= vec-end vec-start)
                  (setq vec (append vec (list vec-start)))
                  (setq vec-start (- vec-start vec-range)))
              (while (<= vec-start vec-end)
                (setq vec (append vec (list vec-start)))
                (setq vec-start (+ vec-start vec-range))))
            ;;
            ;; Delete current line
            (delete-region (point) (progn (forward-line 0) (point)))
            ;;
            ;; Expand vector
            (while vec
              (insert (concat sig-head bra
                              (int-to-string (car vec)) ket sig-tail "\n"))
              (setq vec (cdr vec)))
            (delete-char -1)
            ;;
            )))))

(defun verilog-strip-comments ()
  "Strip all comments from the Verilog code."
  (interactive)
  (goto-char (point-min))
  (while (re-search-forward "//" nil t)
    (if (verilog-within-string-p)
        (re-search-forward "\"" nil t)
      (if (verilog-in-star-comment-p)
          (re-search-forward "\\*/" nil t)
        (let ((bpt (- (point) 2)))
          (end-of-line)
          (delete-region bpt (point))))))
  ;;
  (goto-char (point-min))
  (while (re-search-forward "/\\*" nil t)
    (if (verilog-within-string-p)
        (re-search-forward "\"" nil t)
      (let ((bpt (- (point) 2)))
        (re-search-forward "\\*/")
        (delete-region bpt (point))))))

(defun verilog-one-line ()
  "Convert structural Verilog instances to occupy one line."
  (interactive)
  (goto-char (point-min))
  (while (re-search-forward "\\([^;]\\)[ \t]*\n[ \t]*" nil t)
    (replace-match "\\1 " nil nil)))

(defvar compilation-last-buffer)
(defvar next-error-last-buffer)

(defun verilog-surelint-off ()
  "Convert a SureLint warning line into a disable statement.
Run from Verilog source window; assumes there is a *compile* buffer
with point set appropriately.

For example:
  WARNING [STD-UDDONX]: xx.v, line 8: output out is never assigned.
becomes:
  // surefire lint_line_off UDDONX"
  (interactive)
  (let ((buff (if (boundp 'next-error-last-buffer)
                  next-error-last-buffer
                compilation-last-buffer)))
    (when (buffer-live-p buff)
      (save-excursion
        (switch-to-buffer buff)
        (beginning-of-line)
        (when
            (looking-at "\\(INFO\\|WARNING\\|ERROR\\) \\[[^-]+-\\([^]]+\\)\\]: \\([^,]+\\), line \\([0-9]+\\): \\(.*\\)$")
          (let* ((code (match-string 2))
                 (file (match-string 3))
                 (line (match-string 4))
                 (buffer (get-file-buffer file))
                 dir filename)
            (unless buffer
              (progn
                (setq buffer
                      (and (file-exists-p file)
                           (find-file-noselect file)))
                (or buffer
                    (let* ((pop-up-windows t))
                      (let ((name (expand-file-name
                                   (read-file-name
                                    (format "Find this error in: (default %s) "
                                            file)
                                    dir file t))))
                        (if (file-directory-p name)
                            (setq name (expand-file-name filename name)))
                        (setq buffer
                              (and (file-exists-p name)
                                   (find-file-noselect name))))))))
            (switch-to-buffer buffer)
            (goto-char (point-min))
            (forward-line (- (string-to-number line)))
            (end-of-line)
            (catch 'already
              (cond
               ((verilog-in-slash-comment-p)
                (re-search-backward "//")
                (cond
                 ((looking-at "// surefire lint_off_line ")
                  (goto-char (match-end 0))
                  (let ((lim (point-at-eol)))
                    (if (re-search-forward code lim 'move)
                        (throw 'already t)
                      (insert (concat " " code)))))
                 (t
                  )))
               ((verilog-in-star-comment-p)
                (re-search-backward "/\\*")
                (insert (format " // surefire lint_off_line %6s" code )))
               (t
                (insert (format " // surefire lint_off_line %6s" code ))
                )))))))))

(defun verilog-verilint-off ()
  "Convert a Verilint warning line into a disable statement.

For example:
  (W240)  pci_bfm_null.v, line  46: Unused input: pci_rst_
becomes:
  //Verilint 240 off // WARNING: Unused input"
  (interactive)
  (save-excursion
    (beginning-of-line)
    (when (looking-at "\\(.*\\)([WE]\\([0-9A-Z]+\\)).*,\\s +line\\s +[0-9]+:\\s +\\([^:\n]+\\):?.*$")
      (replace-match (format
                      ;; %3s makes numbers 1-999 line up nicely
                      "\\1//Verilint %3s off // WARNING: \\3"
                      (match-string 2)))
      (beginning-of-line)
      (verilog-indent-line))))


;;; Indentation:
;;
(defconst verilog-indent-alist
  '((block       . (+ ind verilog-indent-level))
    (case        . (+ ind verilog-case-indent))
    (cparenexp   . (+ ind verilog-indent-level))
    (cexp        . (+ ind verilog-cexp-indent))
    (defun       . verilog-indent-level-module)
    (declaration . verilog-indent-level-declaration)
    (directive   . (verilog-calculate-indent-directive))
    (tf          . verilog-indent-level)
    (behavioral  . (+ verilog-indent-level-behavioral verilog-indent-level-module))
    (statement   . ind)
    (cpp         . 0)
    (comment     . (verilog-comment-indent))
    (unknown     . 3)
    (string      . 0)))

(defun verilog-continued-line-1 (lim)
  "Return true if this is a continued line.
Set point to where line starts.  Limit search to point LIM."
  (let ((continued 't))
    (if (eq 0 (forward-line -1))
        (progn
          (end-of-line)
          (verilog-backward-ws&directives lim)
          (if (bobp)
              (setq continued nil)
            (setq continued (verilog-backward-token))))
      (setq continued nil))
    continued))

(defun verilog-calculate-indent ()
  "Calculate the indent of the current Verilog line.
Examine previous lines.  Once a line is found that is definitive as to the
type of the current line, return that lines' indent level and its type.
Return a list of two elements: (INDENT-TYPE INDENT-LEVEL)."
  (save-excursion
    (let* ((starting_position (point))
           (case-fold-search nil)
           (par 0)
           (begin (looking-at "[ \t]*begin\\>"))
           (lim (save-excursion (verilog-re-search-backward "\\(\\<begin\\>\\)\\|\\(\\<module\\>\\)" nil t)))
           (structres nil)
           (type (catch 'nesting
                   ;; Keep working backwards until we can figure out
                   ;; what type of statement this is.
                   ;; Basically we need to figure out
                   ;; 1) if this is a continuation of the previous line;
                   ;; 2) are we in a block scope (begin..end)

                   ;; if we are in a comment, done.
                   (if (verilog-in-star-comment-p)
                       (throw 'nesting 'comment))

                   ;; if we have a directive, done.
                   (if (save-excursion (beginning-of-line)
                                       (and (looking-at verilog-directive-re-1)
                                            (not (or (looking-at "[ \t]*`[ou]vm_")
                                                     (looking-at "[ \t]*`vmm_")))))
                       (throw 'nesting 'directive))
                   ;; indent structs as if there were module level
                   (setq structres (verilog-in-struct-nested-p))
                   (cond ((not structres) nil)
                         ;;((and structres (equal (char-after) ?\})) (throw 'nesting 'struct-close))
                         ((> structres 0) (throw 'nesting 'nested-struct))
                         ((= structres 0) (throw 'nesting 'block))
                         (t nil))

                   ;; if we are in a parenthesized list, and the user likes to indent these, return.
                   ;; unless we are in the newfangled coverpoint or constraint blocks
                   (if (and
                        verilog-indent-lists
                        (verilog-in-paren)
                        (not (verilog-in-coverage-p)))
                       (progn (setq par 1)
                              (throw 'nesting 'block)))

                   ;; See if we are continuing a previous line
                   (while t
                     ;; trap out if we crawl off the top of the buffer
                     (if (bobp) (throw 'nesting 'cpp))

                     (if (and (verilog-continued-line-1 lim)
                              (or (not (verilog-in-coverage-p))
                                  (looking-at verilog-in-constraint-re) ))  ; may still get hosed if concat in constraint
                         (let ((sp (point)))
                           (if (and (not (looking-at verilog-complete-reg))
                                    (verilog-continued-line-1 lim))
                               (progn (goto-char sp)
                                      (throw 'nesting 'cexp))

                             (goto-char sp))
                           (if (and (verilog-in-coverage-p)
                                    (looking-at verilog-in-constraint-re))
                               (progn
                                 (beginning-of-line)
                                 (skip-chars-forward " \t")
                                 (throw 'nesting 'constraint)))
                           (if (and begin
                                    (not verilog-indent-begin-after-if)
                                    (looking-at verilog-no-indent-begin-re))
                               (progn
                                 (beginning-of-line)
                                 (skip-chars-forward " \t")
                                 (throw 'nesting 'statement))
                             (forward-line)
                             (if (looking-at "^\\s-*import\\s-+")
                                 (throw 'nesting 'defun)
                               (forward-line -1)
                               (throw 'nesting 'cexp))))
                       ;; not a continued line
                       (goto-char starting_position))

                     (if (looking-at "\\<else\\>")
                         ;; search back for governing if, striding across begin..end pairs
                         ;; appropriately
                         (let ((elsec 1))
                           (while (verilog-re-search-backward verilog-ends-re nil 'move)
                             (cond
                              ((match-end 1) ; else, we're in deep
                               (setq elsec (1+ elsec)))
                              ((match-end 2) ; if
                               (setq elsec (1- elsec))
                               (if (= 0 elsec)
                                   (if verilog-align-ifelse
                                       (throw 'nesting 'statement)
                                     (progn  ; back up to first word on this line
                                       (beginning-of-line)
                                       (verilog-forward-syntactic-ws)
                                       (throw 'nesting 'statement)))))
                              ((match-end 3) ; assert block
                               (setq elsec (1- elsec))
                               (verilog-beg-of-statement)  ; doesn't get to beginning
                               (if (looking-at verilog-property-re)
                                   (throw 'nesting 'statement)  ; We don't need an endproperty for these
                                 (throw 'nesting 'block)	; We still need an endproperty
                                 ))
                              (t ; endblock
                               ;; try to leap back to matching outward block by striding across
                               ;; indent level changing tokens then immediately
                               ;; previous line governs indentation.
                               (let (( reg) (nest 1))
                                 ;;	 verilog-ends =>  else|if|end|join(_any|_none|)|endcase|endclass|endtable|endspecify|endfunction|endtask|endgenerate|endgroup
                                 (cond
                                  ((match-end 4) ; end
                                   ;; Search back for matching begin
                                   (setq reg "\\(\\<begin\\>\\)\\|\\(\\<end\\>\\)" ))
                                  ((match-end 5) ; endcase
                                   ;; Search back for matching case
                                   (setq reg "\\(\\<randcase\\>\\|\\<case[xz]?\\>[^:]\\)\\|\\(\\<endcase\\>\\)" ))
                                  ((match-end 6) ; endfunction
                                   ;; Search back for matching function
                                   (setq reg "\\(\\<function\\>\\)\\|\\(\\<endfunction\\>\\)" ))
                                  ((match-end 7) ; endtask
                                   ;; Search back for matching task
                                   (setq reg "\\(\\<task\\>\\)\\|\\(\\<endtask\\>\\)" ))
                                  ((match-end 8) ; endspecify
                                   ;; Search back for matching specify
                                   (setq reg "\\(\\<specify\\>\\)\\|\\(\\<endspecify\\>\\)" ))
                                  ((match-end 9) ; endtable
                                   ;; Search back for matching table
                                   (setq reg "\\(\\<table\\>\\)\\|\\(\\<endtable\\>\\)" ))
                                  ((match-end 10) ; endgenerate
                                   ;; Search back for matching generate
                                   (setq reg "\\(\\<generate\\>\\)\\|\\(\\<endgenerate\\>\\)" ))
                                  ((match-end 11) ; joins
                                   ;; Search back for matching fork
                                   (setq reg "\\(\\<fork\\>\\)\\|\\(\\<join\\(_any\\|none\\)?\\>\\)" ))
                                  ((match-end 12) ; class
                                   ;; Search back for matching class
                                   (setq reg "\\(\\<class\\>\\)\\|\\(\\<endclass\\>\\)" ))
                                  ((match-end 13) ; covergroup
                                   ;; Search back for matching covergroup
                                   (setq reg "\\(\\<covergroup\\>\\)\\|\\(\\<endgroup\\>\\)" )))
                                 (catch 'skip
                                   (while (verilog-re-search-backward reg nil 'move)
                                     (cond
                                      ((match-end 1) ; begin
                                       (setq nest (1- nest))
                                       (if (= 0 nest)
                                           (throw 'skip 1)))
                                      ((match-end 2) ; end
                                       (setq nest (1+ nest)))))
                                   )))))))
                     (throw 'nesting (verilog-calc-1)))
                   )  ; catch nesting
                 ) ; type
           )
      ;; Return type of block and indent level.
      (if (not type)
          (setq type 'cpp))
      (if (> par 0)			; Unclosed Parenthesis
          (list 'cparenexp par)
        (cond
         ((eq type 'case)
          (list type (verilog-case-indent-level)))
         ((eq type 'statement)
          (list type (current-column)))
         ((eq type 'defun)
          (list type 0))
         ((eq type 'constraint)
          (list 'block (current-column)))
         ((eq type 'nested-struct)
          (list 'block structres))
         (t
          (list type (verilog-current-indent-level))))))))

(defun verilog-wai ()
  "Show matching nesting block for debugging."
  (interactive)
  (save-excursion
    (let* ((type (verilog-calc-1))
           depth)
      ;; Return type of block and indent level.
      (if (not type)
          (setq type 'cpp))
      (if (and
           verilog-indent-lists
           (not(or (verilog-in-coverage-p)
                   (verilog-in-struct-p)))
           (verilog-in-paren))
          (setq depth 1)
        (cond
         ((eq type 'case)
          (setq depth (verilog-case-indent-level)))
         ((eq type 'statement)
          (setq depth (current-column)))
         ((eq type 'defun)
          (setq depth 0))
         (t
          (setq depth (verilog-current-indent-level)))))
      (message "You are at nesting %s depth %d" type depth))))

(defun verilog-calc-1 ()
  (catch 'nesting
    (let ((re (concat "\\({\\|}\\|" verilog-indent-re "\\)"))
          (inconstraint (verilog-in-coverage-p)))
      (while (verilog-re-search-backward re nil 'move)
        (catch 'continue
          (cond
           ((equal (char-after) ?\{)
            ;; block type returned based on outer constraint { or inner
            (if (verilog-at-constraint-p)
                (cond (inconstraint
                       (beginning-of-line nil)
                       (skip-chars-forward " \t")
                       (throw 'nesting 'constraint))
                      (t
                       (throw 'nesting 'statement)))))
           ((equal (char-after) ?\})
            (let (par-pos
                  (there (verilog-at-close-constraint-p)))
              (if there  ; we are at the } that closes a constraint.  Find the { that opens it
                  (progn
                    (if (> (verilog-in-paren-count) 0)
                        (forward-char 1))
                    (setq par-pos (verilog-parenthesis-depth))
                    (cond (par-pos
                           (goto-char par-pos)
                           (forward-char 1))
                          (t
                           (backward-char 1)))))))

           ((looking-at verilog-beg-block-re-ordered)
            (cond
             ((match-end 2)  ; *sigh* could be "unique case" or "priority casex"
              (let ((here (point)))
                (verilog-beg-of-statement)
                (if (looking-at verilog-extended-case-re)
                    (throw 'nesting 'case)
                  (goto-char here)))
              (throw 'nesting 'case))

             ((match-end 4)  ; *sigh* could be "disable fork"
              (let ((here (point)))
                (verilog-beg-of-statement)
                (if (looking-at verilog-disable-fork-re)
                    t ; this is a normal statement
                  (progn ; or is fork, starts a new block
                    (goto-char here)
                    (throw 'nesting 'block)))))

             ((match-end 17)  ; *sigh* might be a clocking declaration
              (let ((here (point)))
                (cond ((verilog-in-paren)
                       t) ; this is a normal statement
                      ((save-excursion
                         (verilog-beg-of-statement)
                         (looking-at verilog-default-clocking-re))
                       t) ; default clocking, normal statement
                      (t
                       (goto-char here) ; or is clocking, starts a new block
                       (throw 'nesting 'block)))))

             ((looking-at "\\<class\\|struct\\|function\\|task\\>")
              ;; *sigh* These words have an optional prefix:
              ;; extern {virtual|protected}? function a();
              ;; and we don't want to confuse this with
              ;; function a();
              ;; property
              ;; ...
              ;; endfunction
              (verilog-beg-of-statement)
              (cond
               ((looking-at verilog-dpi-import-export-re)
                (throw 'continue 'foo))
               ((or
                 (looking-at "\\<pure\\>\\s-+\\<virtual\\>\\s-+\\(?:\\<\\(local\\|protected\\|static\\)\\>\\s-+\\)?\\<\\(function\\|task\\)\\>\\s-+")
                 ;; Do not throw 'defun for class typedefs like
                 ;;   typedef class foo;
                 (looking-at "\\<typedef\\>\\s-+\\(?:\\<virtual\\>\\s-+\\)?\\<class\\>\\s-+"))
                (throw 'nesting 'statement))
               ((looking-at verilog-beg-block-re-ordered)
                (throw 'nesting 'block))
               (t
                (throw 'nesting 'defun))))

             ;;
             ((looking-at "\\<property\\>")
              ;; *sigh*
              ;;    {assert|assume|cover} property (); are complete
              ;;   and could also be labeled: - foo: assert property
              ;; but
              ;;    property ID () ... needs end_property
              (verilog-beg-of-statement)
              (if (looking-at verilog-property-re)
                  (throw 'continue 'statement) ; We don't need an endproperty for these
                (throw 'nesting 'block)	;We still need an endproperty
                ))

             (t              (throw 'nesting 'block))))

           ((looking-at verilog-end-block-re)
            (verilog-leap-to-head)
            (if (verilog-in-case-region-p)
                (progn
                  (verilog-leap-to-case-head)
                  (if (looking-at verilog-extended-case-re)
                      (throw 'nesting 'case)))))

           ((looking-at verilog-defun-level-re)
            (if (looking-at verilog-defun-level-generate-only-re)
                (if (or (verilog-in-generate-region-p)
                        (verilog-in-deferred-immediate-final-p))
                    (throw 'continue 'foo)  ; always block in a generate - keep looking
                  (throw 'nesting 'defun))
              (throw 'nesting 'defun)))

           ((looking-at verilog-cpp-level-re)
            (throw 'nesting 'cpp))

           ((bobp)
            (throw 'nesting 'cpp)))))

      (throw 'nesting 'cpp))))

(defun verilog-calculate-indent-directive ()
  "Return indentation level for directive.
For speed, the searcher looks at the last directive, not the indent
of the appropriate enclosing block."
  (let ((base -1)  ; Indent of the line that determines our indentation
        (ind 0))   ; Relative offset caused by other directives (like `endif on same line as `else)
    ;; Start at current location, scan back for another directive

    (save-excursion
      (beginning-of-line)
      (while (and (< base 0)
                  (verilog-re-search-backward verilog-directive-re nil t))
        (cond ((save-excursion (skip-chars-backward " \t") (bolp))
               (setq base (current-indentation))))
        (cond ((and (looking-at verilog-directive-end) (< base 0))  ; Only matters when not at BOL
               (setq ind (- ind verilog-indent-level-directive)))
              ((and (looking-at verilog-directive-middle) (>= base 0))  ; Only matters when at BOL
               (setq ind (+ ind verilog-indent-level-directive)))
              ((looking-at verilog-directive-begin)
               (setq ind (+ ind verilog-indent-level-directive)))))
      ;; Adjust indent to starting indent of critical line
      (setq ind (max 0 (+ ind base))))

    (save-excursion
      (beginning-of-line)
      (skip-chars-forward " \t")
      (cond ((or (looking-at verilog-directive-middle)
                 (looking-at verilog-directive-end))
             (setq ind (max 0 (- ind verilog-indent-level-directive))))))
    ind))

(defun verilog-leap-to-case-head ()
  (let ((nest 1))
    (while (/= 0 nest)
      (verilog-re-search-backward
       (concat
        "\\(\\<randcase\\>\\|\\(\\<unique0?\\s-+\\|priority\\s-+\\)?\\<case[xz]?\\>\\)"
        "\\|\\(\\<endcase\\>\\)" )
       nil 'move)
      (cond
       ((match-end 1)
        (let ((here (point)))
          (verilog-beg-of-statement)
          (unless (looking-at verilog-extended-case-re)
            (goto-char here)))
        (setq nest (1- nest)))
       ((match-end 3)
        (setq nest (1+ nest)))
       ((bobp)
        (ding 't)
        (setq nest 0))))))

(defun verilog-leap-to-head ()
  "Move point to the head of this block.
Jump from end to matching begin, from endcase to matching case, and so on."
  (let ((reg nil)
        snest
        (nesting 'yes)
        (nest 1))
    (cond
     ((looking-at "\\<end\\>")
      ;; 1: Search back for matching begin
      (setq reg (concat "\\(\\<begin\\>\\)\\|\\(\\<end\\>\\)\\|"
                        "\\(\\<endcase\\>\\)\\|\\(\\<join\\(_any\\|_none\\)?\\>\\)" )))
     ((looking-at "\\<endtask\\>")
      ;; 2: Search back for matching task
      (setq reg "\\(\\<task\\>\\)\\|\\(\\(\\<\\(virtual\\|protected\\|static\\)\\>\\s-+\\)+\\<task\\>\\)")
      (setq nesting 'no))
     ((looking-at "\\<endcase\\>")
      (catch 'nesting
        (verilog-leap-to-case-head) )
      (setq reg nil) ; to force skip
      )

     ((looking-at "\\<join\\(_any\\|_none\\)?\\>")
      ;; 4: Search back for matching fork
      (setq reg "\\(\\<fork\\>\\)\\|\\(\\<join\\(_any\\|_none\\)?\\>\\)" ))
     ((looking-at "\\<endclass\\>")
      ;; 5: Search back for matching class
      (setq reg "\\(\\<class\\>\\)\\|\\(\\<endclass\\>\\)" ))
     ((looking-at "\\<endtable\\>")
      ;; 6: Search back for matching table
      (setq reg "\\(\\<table\\>\\)\\|\\(\\<endtable\\>\\)" ))
     ((looking-at "\\<endspecify\\>")
      ;; 7: Search back for matching specify
      (setq reg "\\(\\<specify\\>\\)\\|\\(\\<endspecify\\>\\)" ))
     ((looking-at "\\<endfunction\\>")
      ;; 8: Search back for matching function
      (setq reg "\\(\\<function\\>\\)\\|\\(\\(\\<\\(virtual\\|protected\\|static\\)\\>\\s-+\\)+\\<function\\>\\)")
      (setq nesting 'no))
     ;;(setq reg "\\(\\<function\\>\\)\\|\\(\\<endfunction\\>\\)" ))
     ((looking-at "\\<endgenerate\\>")
      ;; 8: Search back for matching generate
      (setq reg "\\(\\<generate\\>\\)\\|\\(\\<endgenerate\\>\\)" ))
     ((looking-at "\\<endgroup\\>")
      ;; 10: Search back for matching covergroup
      (setq reg "\\(\\<covergroup\\>\\)\\|\\(\\<endgroup\\>\\)" ))
     ((looking-at "\\<endproperty\\>")
      ;; 11: Search back for matching property
      (setq reg "\\(\\<property\\>\\)\\|\\(\\<endproperty\\>\\)" ))
     ((looking-at verilog-uvm-end-re)
      ;; 12: Search back for matching sequence
      (setq reg (concat "\\(" verilog-uvm-begin-re "\\|" verilog-uvm-end-re "\\)")))
     ((looking-at verilog-ovm-end-re)
      ;; 12: Search back for matching sequence
      (setq reg (concat "\\(" verilog-ovm-begin-re "\\|" verilog-ovm-end-re "\\)")))
     ((looking-at verilog-vmm-end-re)
      ;; 12: Search back for matching sequence
      (setq reg (concat "\\(" verilog-vmm-begin-re "\\|" verilog-vmm-end-re "\\)")))
     ((looking-at "\\<endinterface\\>")
      ;; 12: Search back for matching interface
      (setq reg "\\(\\<interface\\>\\)\\|\\(\\<endinterface\\>\\)" ))
     ((looking-at "\\<endsequence\\>")
      ;; 12: Search back for matching sequence
      (setq reg "\\(\\<\\(rand\\)?sequence\\>\\)\\|\\(\\<endsequence\\>\\)" ))
     ((looking-at "\\<endclocking\\>")
      ;; 12: Search back for matching clocking
      (setq reg "\\(\\<clocking\\)\\|\\(\\<endclocking\\>\\)" )))
    (if reg
        (catch 'skip
          (if (eq nesting 'yes)
              (let (sreg)
                (while (verilog-re-search-backward reg nil 'move)
                  (cond
                   ((match-end 1) ; begin
                    (if (looking-at "fork")
                        (let ((here (point)))
                          (verilog-beg-of-statement)
                          (unless (looking-at verilog-disable-fork-re)
                            (goto-char here)
                            (setq nest (1- nest))))
                      (setq nest (1- nest)))
                    (if (= 0 nest)
                        ;; Now previous line describes syntax
                        (throw 'skip 1))
                    (if (and snest
                             (= snest nest))
                        (setq reg sreg)))
                   ((match-end 2) ; end
                    (setq nest (1+ nest)))
                   ((match-end 3)
                    ;; endcase, jump to case
                    (setq snest nest)
                    (setq nest (1+ nest))
                    (setq sreg reg)
                    (setq reg "\\(\\<randcase\\>\\|\\<case[xz]?\\>[^:]\\)\\|\\(\\<endcase\\>\\)" ))
                   ((match-end 4)
                    ;; join, jump to fork
                    (setq snest nest)
                    (setq nest (1+ nest))
                    (setq sreg reg)
                    (setq reg "\\(\\<fork\\>\\)\\|\\(\\<join\\(_any\\|_none\\)?\\>\\)" ))
                   )))
            ;; no nesting
            (if (and
                 (verilog-re-search-backward reg nil 'move)
                 (match-end 1)) ; task -> could be virtual and/or protected
                (progn
                  (verilog-beg-of-statement)
                  (throw 'skip 1))
              (throw 'skip 1)))))))

(defun verilog-continued-line ()
  "Return true if this is a continued line.
Set point to where line starts."
  (let ((continued 't))
    (if (eq 0 (forward-line -1))
        (progn
          (end-of-line)
          (verilog-backward-ws&directives)
          (if (bobp)
              (setq continued nil)
            (while (and continued
                        (save-excursion
                          (skip-chars-backward " \t")
                          (not (bolp))))
              (setq continued (verilog-backward-token)))))
      (setq continued nil))
    continued))

(defun verilog-backward-token ()
  "Step backward token, returning true if this is a continued line."
  (interactive)
  (verilog-backward-syntactic-ws)
  (cond
   ((bolp)
    nil)
   (;-- Anything ending in a ; is complete
    (= (preceding-char) ?\;)
    nil)
   (;  If a "}" is prefixed by a ";", then this is a complete statement
    ;; i.e.: constraint foo { a = b; }
    (= (preceding-char) ?\})
    (progn
      (backward-char)
      (not(verilog-at-close-constraint-p))))
   (;-- constraint foo { a = b }
    ;;  is a complete statement. *sigh*
    (= (preceding-char) ?\{)
    (progn
      (backward-char)
      (not (verilog-at-constraint-p))))
   (;" string "
    (= (preceding-char) ?\")
    (backward-char)
    (verilog-skip-backward-comment-or-string)
    nil)

   (; [3:4]
    (= (preceding-char) ?\])
    (backward-char)
    (verilog-backward-open-bracket)
    t)

   (;-- Could be 'case (foo)' or 'always @(bar)' which is complete
    ;;  also could be simply '@(foo)'
    ;;  or foo u1 #(a=8)
    ;;           (b, ... which ISN'T complete
    ;; Do we need this???
    (= (preceding-char) ?\))
    (progn
      (backward-char)
      (verilog-backward-up-list 1)
      (verilog-backward-syntactic-ws)
      (let ((back (point)))
        (forward-word-strictly -1)
        (cond
         ;;XX
         ((looking-at "\\<\\(always\\(_latch\\|_ff\\|_comb\\)?\\|case\\(\\|[xz]\\)\\|for\\(\\|each\\|ever\\)\\|i\\(f\\|nitial\\)\\|repeat\\|while\\)\\>")
          (not (looking-at "\\<randcase\\>\\|\\<case[xz]?\\>[^:]")))
         ((looking-at verilog-uvm-statement-re)
          nil)
         ((looking-at verilog-uvm-begin-re)
          t)
         ((looking-at verilog-uvm-end-re)
          t)
         ((looking-at verilog-ovm-statement-re)
          nil)
         ((looking-at verilog-ovm-begin-re)
          t)
         ((looking-at verilog-ovm-end-re)
          t)
         ;; JBA find VMM macros
         ((looking-at verilog-vmm-statement-re)
          nil )
         ((looking-at verilog-vmm-begin-re)
          t)
         ((looking-at verilog-vmm-end-re)
          nil)
         ;; JBA trying to catch macro lines with no ; at end
         ((looking-at "\\<`")
          nil)
         (t
          (goto-char back)
          (cond
           ((= (preceding-char) ?\@)
            (backward-char)
            (save-excursion
              (verilog-backward-token)
              (not (looking-at "\\<\\(always\\(_latch\\|_ff\\|_comb\\)?\\|initial\\|while\\)\\>"))))
           ((= (preceding-char) ?\#)
            (backward-char))
           (t t)))))))

   (;-- any of begin|initial|while are complete statements; 'begin : foo' is also complete
    t
    (forward-word-strictly -1)
    (while (or (= (preceding-char) ?\_)
               (= (preceding-char) ?\@)
               (= (preceding-char) ?\.))
      (forward-word-strictly -1))
    (cond
     ((looking-at "\\<else\\>")
      t)
     ((looking-at verilog-behavioral-block-beg-re)
      t)
     ((looking-at verilog-indent-re)
      nil)
     (t
      (let
          ((back (point)))
        (verilog-backward-syntactic-ws)
        (cond
         ((= (preceding-char) ?\:)
          (backward-char)
          (verilog-backward-syntactic-ws)
          (backward-sexp)
          (if (looking-at verilog-nameable-item-re )
              nil
            t))
         ((= (preceding-char) ?\#)
          (backward-char)
          t)
         ((= (preceding-char) ?\`)
          (backward-char)
          t)
         (t
          (goto-char back)
          t))))))))

(defun verilog-assign-statement-p ()
  "Seach assign statement line"
  (unless (verilog-in-comment-or-string-p)
    (beginning-of-line)
    (looking-at "^\\s-*assign\\s-+")))

(defun verilog-align-assign ()
  "Align the assert statements"
  (interactive)
  (let* ((start (save-excursion
                  (beginning-of-line)
                  (setq start (point))
                  (while (progn (forward-line -1)
                                (verilog-assign-statement-p))
                    (setq start (point)))
                  start))
         (end (save-excursion
                (end-of-line)
                (setq end (point))
                (while (progn (forward-line 1)
                              (verilog-assign-statement-p))
                  (end-of-line)
                  (setq end (point)))
                end))
         (assign-regex "^\\(.*\\)\\s-+\\(=\\)\\s-+")
         (ind (verilog-get-lineup-indent-2  assign-regex start end)))
    (message "start: %d, end: %d, ind: %d" start end ind)
    (goto-char start)
    (while (and (> end (point))
                (looking-at assign-regex))
      (goto-char (match-beginning 2))
      (just-one-space)
      (beginning-of-line)
      (looking-at assign-regex)
      (goto-char (match-beginning 2))
      (indent-to ind)
      (forward-line))))

(defun verilog-backward-syntactic-ws ()
  "Move backwards putting point after first non-whitespace non-comment."
  (verilog-skip-backward-comments)
  (forward-comment (- (buffer-size))))

(defun verilog-backward-syntactic-ws-quick ()
  "As with `verilog-backward-syntactic-ws' but use `verilog-scan' cache."
  (while (cond ((bobp)
                nil) ; Done
               ((< (skip-syntax-backward " ") 0)
                t)
               ((eq (preceding-char) ?\n)  ; \n's terminate // so aren't space syntax
                (forward-char -1)
                t)
               ((or (verilog-inside-comment-or-string-p (1- (point)))
                    (verilog-inside-comment-or-string-p (point)))
                (re-search-backward "[/\"]" nil t)  ; Only way a comment or quote can begin
                t))))

(defun verilog-forward-syntactic-ws ()
  (verilog-skip-forward-comment-p)
  (forward-comment (buffer-size)))

(defun verilog-backward-ws&directives (&optional bound)
  "Backward skip over syntactic whitespace and compiler directives for Emacs 19.
Optional BOUND limits search."
  (save-restriction
    (let* ((bound (or bound (point-min)))
           (here bound)
           (p nil) )
      (if (< bound (point))
          (progn
            (let ((state (save-excursion (verilog-syntax-ppss))))
              (cond
               ((nth 7 state)  ; in // comment
                (verilog-re-search-backward "//" nil 'move)
                (skip-chars-backward "/"))
               ((nth 4 state)  ; in /* */ comment
                (verilog-re-search-backward "/\\*" nil 'move))))
            (narrow-to-region bound (point))
            (while (/= here (point))
              (setq here (point))
              (verilog-skip-backward-comments)
              (setq p
                    (save-excursion
                      (beginning-of-line)
                      ;; for as long as we're right after a continued line, keep moving up
                      (while (and (looking-back "\\\\[\n\r\f]" nil)
                                  (forward-line -1)))
                      (cond
                       ((and verilog-highlight-translate-off
                             (verilog-within-translate-off))
                        (verilog-back-to-start-translate-off (point-min)))
                       ((looking-at verilog-directive-re-1)
                        (point))
                       (t
                        nil))))
              (if p (goto-char p))))))))

(defun verilog-forward-ws&directives (&optional bound)
  "Forward skip over syntactic whitespace and compiler directives for Emacs 19.
Optional BOUND limits search."
  (save-restriction
    (let* ((bound (or bound (point-max)))
           (here bound)
           jump)
      (if (> bound (point))
          (progn
            (let ((state (save-excursion (verilog-syntax-ppss))))
              (cond
               ((nth 7 state)  ; in // comment
                (end-of-line)
                (forward-char 1)
                (skip-chars-forward " \t\n\f")
                )
               ((nth 4 state)  ; in /* */ comment
                (verilog-re-search-forward "\\*/\\s-*" nil 'move))))
            (narrow-to-region (point) bound)
            (while (/= here (point))
              (setq here (point)
                    jump nil)
              (forward-comment (buffer-size))
              (and (looking-at "\\s-*(\\*.*\\*)\\s-*")  ; Attribute
                   (goto-char (match-end 0)))
              (save-excursion
                (beginning-of-line)
                (if (looking-at verilog-directive-re-1)
                    (setq jump t)))
              (if jump
                  (beginning-of-line 2))))))))

(defun verilog-in-comment-p ()
  "Return true if in a star or // comment."
  (let ((state (save-excursion (verilog-syntax-ppss))))
    (or (nth 4 state) (nth 7 state))))

(defun verilog-in-star-comment-p ()
  "Return true if in a star comment."
  (let ((state (save-excursion (verilog-syntax-ppss))))
    (and
     (nth 4 state)			; t if in a comment of style a // or b /**/
     (not
      (nth 7 state)			; t if in a comment of style b /**/
      ))))

(defun verilog-in-slash-comment-p ()
  "Return true if in a slash comment."
  (let ((state (save-excursion (verilog-syntax-ppss))))
    (nth 7 state)))

(defun verilog-in-comment-or-string-p ()
  "Return true if in a string or comment."
  (let ((state (save-excursion (verilog-syntax-ppss))))
    (or (nth 3 state) (nth 4 state) (nth 7 state)))) ; Inside string or comment)

(defun verilog-in-attribute-p ()
  "Return true if point is in an attribute (* [] attribute *)."
  (save-match-data
    (save-excursion
      (verilog-re-search-backward "\\((\\*\\)\\|\\(\\*)\\)" nil 'move)
      (cond
       ((match-end 1)
        (progn (goto-char (match-end 1))
               (not (looking-at "\\s-*)")))
        nil)
       ((match-end 2)
        (progn (goto-char (match-beginning 2))
               (not (looking-at "(\\s-*")))
        nil)
       (t nil)))))

(defun verilog-in-parameter-p ()
  "Return true if point is in a parameter assignment #( p1=1, p2=5)."
  (save-match-data
    (save-excursion
      (verilog-re-search-backward "\\(#(\\)\\|\\()\\)" nil 'move)
      (numberp (match-beginning 1)))))

(defun verilog-in-escaped-name-p ()
  "Return true if in an escaped name."
  (save-excursion
    (backward-char)
    (skip-chars-backward "^ \t\n\f")
    (if (equal (char-after (point) ) ?\\ )
        t
      nil)))

(defun verilog-in-directive-p ()
  "Return true if in a directive."
  (save-excursion
    (beginning-of-line)
    (looking-at verilog-directive-re-1)))

(defun verilog-in-parenthesis-p ()
  "Return true if in a ( ) expression (but not { } or [ ])."
  (save-match-data
    (save-excursion
      (verilog-re-search-backward "\\((\\)\\|\\()\\)" nil 'move)
      (numberp (match-beginning 1)))))

(defun verilog-in-paren ()
  "Return true if in a parenthetical expression.
May cache result using `verilog-syntax-ppss'."
  (let ((state (save-excursion (verilog-syntax-ppss))))
    (> (nth 0 state) 0 )))

(defun verilog-in-paren-count ()
  "Return paren depth, floor to 0.
May cache result using `verilog-syntax-ppss'."
  (let ((state (save-excursion (verilog-syntax-ppss))))
    (if (> (nth 0 state) 0)
        (nth 0 state)
      0 )))

(defun verilog-in-paren-quick ()
  "Return true if in a parenthetical expression.
Always starts from `point-min', to allow inserts with hooks disabled."
  ;; The -quick refers to its use alongside the other -quick functions,
  ;; not that it's likely to be faster than verilog-in-paren.
  (let ((state (save-excursion (parse-partial-sexp (point-min) (point)))))
    (> (nth 0 state) 0 )))

(defun verilog-in-struct-p ()
  "Return true if in a struct declaration."
  (interactive)
  (save-excursion
    (if (verilog-in-paren)
        (progn
          (verilog-backward-up-list 1)
          (verilog-at-struct-p)
          )
      nil)))

(defun verilog-in-struct-nested-p ()
  "Return nil for not in struct.
Return 0 for in non-nested struct.
Return >0 for nested struct."
  (interactive)
  (let (col)
    (save-excursion
      (if (verilog-in-paren)
          (progn
            (verilog-backward-up-list 1)
            (setq col (verilog-at-struct-mv-p))
            (if col
                (if (verilog-in-struct-p) (current-column) 0)))
        nil))))

(defun verilog-in-coverage-p ()
  "Return true if in a constraint or coverpoint expression."
  (interactive)
  (save-excursion
    (if (verilog-in-paren)
        (progn
          (verilog-backward-up-list 1)
          (verilog-at-constraint-p)
          )
      nil)))

(defun verilog-at-close-constraint-p ()
  "If at the } that closes a constraint or covergroup, return true."
  (if (and
       (equal (char-after) ?\})
       (verilog-in-coverage-p))

      (save-excursion
        (verilog-backward-ws&directives)
        (if (or (equal (char-before) ?\;)
                (equal (char-before) ?\})  ; can end with inner constraint { } block or ;
                (equal (char-before) ?\{))  ; empty constraint block
            (point)
          nil))))

(defun verilog-at-constraint-p ()
  "If at the { of a constraint or coverpoint definition, return true, moving point to constraint."
  (if (save-excursion
        (let ((p (point)))
          (and
           (equal (char-after) ?\{)
           (ignore-errors (forward-list))
           (progn (backward-char 1)
                  (verilog-backward-ws&directives)
                  (and
                   (or (equal (char-before) ?\{)  ; empty case
                       (equal (char-before) ?\;)
                       (equal (char-before) ?\}))
                   ;; skip what looks like bus repetition operator {#{
                   (not (string-match "^{\\s-*[0-9a-zA-Z_]+\\s-*{" (buffer-substring p (point)))))))))
      (progn
        (let ( (pt (point)) (pass 0))
          (verilog-backward-ws&directives)
          (verilog-backward-token)
          (if (looking-at (concat "\\<constraint\\|coverpoint\\|cross\\|with\\>\\|" verilog-in-constraint-re))
              (progn (setq pass 1)
                     (if (looking-at "\\<with\\>")
                         (progn (verilog-backward-ws&directives)
                                (beginning-of-line)  ; 1
                                (verilog-forward-ws&directives)
                                1 )
                       (verilog-beg-of-statement)
                       ))
            ;; if first word token not keyword, it maybe the instance name
            ;;   check next word token
            (if (looking-at "\\<\\w+\\>\\|\\s-*(\\s-*\\S-+")
                (progn (verilog-beg-of-statement)
                       (if (and
                            (not (string-match verilog-named-block-re (buffer-substring pt (point)))) ;; Abort if 'begin' keyword is found
                            (looking-at (concat "\\<\\(constraint\\|"
                                                "\\(?:\\w+\\s-*:\\s-*\\)?\\(coverpoint\\|cross\\)"
                                                "\\|with\\)\\>\\|" verilog-in-constraint-re)))
                           (setq pass 1)))))
          (if (eq pass 0)
              (progn (goto-char pt) nil) 1)))
    ;; not
    nil))

(defun verilog-at-struct-p ()
  "If at the { of a struct, return true, not moving point."
  (save-excursion
    (if (and (equal (char-after) ?\{)
             (verilog-backward-token))
        (looking-at "\\<struct\\|union\\|packed\\|\\(un\\)?signed\\>")
      nil)))

(defun verilog-at-struct-mv-p ()
  "If at the { of a struct, return true, moving point to struct."
  (let ((pt (point)))
    (if (and (equal (char-after) ?\{)
             (verilog-backward-token))
        (if (looking-at "\\<struct\\|union\\|packed\\|\\(un\\)?signed\\>")
            (progn (verilog-beg-of-statement) (point))
          (progn (goto-char pt) nil))
      (progn (goto-char pt) nil))))

(defun verilog-at-close-struct-p ()
  "If at the } that closes a struct, return true."
  (if (and
       (equal (char-after) ?\})
       (verilog-in-struct-p))
      ;; true
      (save-excursion
        (if (looking-at "}\\(?:\\s-*\\w+\\s-*\\)?;") 1))
    ;; false
    nil))

(defun verilog-parenthesis-depth ()
  "Return non zero if in parenthetical-expression."
  (save-excursion (nth 1 (verilog-syntax-ppss))))


(defun verilog-skip-forward-comment-or-string ()
  "Return true if in a string or comment."
  (let ((state (save-excursion (verilog-syntax-ppss))))
    (cond
     ((nth 3 state)			;Inside string
      (search-forward "\"")
      t)
     ((nth 7 state)			;Inside // comment
      (forward-line 1)
      t)
     ((nth 4 state)			;Inside any comment (hence /**/)
      (search-forward "*/"))
     (t
      nil))))

(defun verilog-skip-backward-comment-or-string ()
  "Return true if in a string or comment."
  (let ((state (save-excursion (verilog-syntax-ppss))))
    (cond
     ((nth 3 state)			;Inside string
      (search-backward "\"")
      t)
     ((nth 7 state)			;Inside // comment
      (search-backward "//")
      (skip-chars-backward "/")
      t)
     ((nth 4 state)			;Inside /* */ comment
      (search-backward "/*")
      t)
     (t
      nil))))

(defun verilog-skip-backward-comments ()
  "Return true if a comment was skipped."
  (let ((more t))
    (while more
      (setq more
            (let ((state (save-excursion (verilog-syntax-ppss))))
              (cond
               ((nth 7 state)			;Inside // comment
                (search-backward "//")
                (skip-chars-backward "/")
                (skip-chars-backward " \t\n\f")
                t)
               ((nth 4 state)			;Inside /* */ comment
                (search-backward "/*")
                (skip-chars-backward " \t\n\f")
                t)
               ((and (not (bobp))
                     (= (char-before) ?\/)
                     (= (char-before (1- (point))) ?\*))
                (goto-char (- (point) 2))
                t)  ; Let nth 4 state handle the rest
               ((and (not (bobp))
                     ;;(looking-back "\\*)" nil) ;; super slow, use two char-before instead
                     (= (char-before) ?\))
                     (= (char-before (1- (point))) ?\*)
                     (not (looking-back "(\\s-*\\*)" nil))) ;; slow but unlikely to be called
                (goto-char (- (point) 2))
                (if (search-backward "(*" nil t)
                    (progn
                      (skip-chars-backward " \t\n\f")
                      t)
                  (progn
                    (goto-char (+ (point) 2))
                    nil)))
               (t
                (/= (skip-chars-backward " \t\n\f") 0))))))))

(defun verilog-skip-forward-comment-p ()
  "If in comment, move to end and return true."
  (let* (h
         (state (save-excursion (verilog-syntax-ppss)))
         (skip (cond
                ((nth 3 state)		;Inside string
                 t)
                ((nth 7 state)		;Inside // comment
                 (end-of-line)
                 (forward-char 1)
                 t)
                ((nth 4 state)		;Inside /* comment
                 (search-forward "*/")
                 t)
                ((verilog-in-attribute-p)  ;Inside (* attribute
                 (search-forward "*)" nil t)
                 t)
                (t nil))))
    (skip-chars-forward " \t\n\f")
    (while
        (cond
         ((looking-at "\\/\\*")
          (progn
            (setq h (point))
            (goto-char (match-end 0))
            (if (search-forward "*/" nil t)
                (progn
                  (skip-chars-forward " \t\n\f")
                  (setq skip 't))
              (progn
                (goto-char h)
                nil))))
         ((and (looking-at "(\\*")  ; attribute start, but not an event (*) or (* )
               (not (looking-at "(\\*\\s-*)")))
          (progn
            (setq h (point))
            (goto-char (match-end 0))
            (if (search-forward "*)" nil t)
                (progn
                  (skip-chars-forward " \t\n\f")
                  (setq skip 't))
              (progn
                (goto-char h)
                nil))))
         (t nil)))
    skip))

(defun verilog-indent-line-relative ()
  "Cheap version of indent line.
Only look at a few lines to determine indent level."
  (interactive)
  (let ((indent-str)
        (sp (point)))
    (if (looking-at "^[ \t]*$")
        (cond  ;- A blank line; No need to be too smart.
         ((bobp)
          (setq indent-str (list 'cpp 0)))
         ((verilog-continued-line)
          (let ((sp1 (point)))
            (if (verilog-continued-line)
                (progn
                  (goto-char sp)
                  (setq indent-str
                        (list 'statement (verilog-current-indent-level))))
              (goto-char sp1)
              (setq indent-str (list 'block (verilog-current-indent-level)))))
          (goto-char sp))
         ((goto-char sp)
          (setq indent-str (verilog-calculate-indent))))
      (progn (skip-chars-forward " \t")
             (setq indent-str (verilog-calculate-indent))))
    (verilog-do-indent indent-str)))

(defun verilog-indent-line ()
  "Indent for special part of code."
  (verilog-do-indent (verilog-calculate-indent)))

(defun verilog-do-indent (indent-str)
  (let ((type (car indent-str))
        (ind (car (cdr indent-str))))
    (cond
     (; handle continued exp
      (eq type 'cexp)
      (let ((here (point)))
        (verilog-backward-syntactic-ws)
        (cond
         ((or
           (= (preceding-char) ?\,)
           (save-excursion
             (verilog-beg-of-statement-1)
             (looking-at verilog-declaration-re)))
          (let* ( fst
                  (val
                   (save-excursion
                     (backward-char 1)
                     (verilog-beg-of-statement-1)
                     (setq fst (point))
                     (if (looking-at verilog-declaration-re)
                         (progn  ; we have multiple words
                           (goto-char (match-end 0))
                           (skip-chars-forward " \t")
                           (cond
                            ((and verilog-indent-declaration-macros
                                  (= (following-char) ?\`))
                             (progn
                               (forward-char 1)
                               (forward-word-strictly 1)
                               (skip-chars-forward " \t")))
                            ((= (following-char) ?\[)
                             (progn
                               (forward-char 1)
                               (verilog-backward-up-list -1)
                               (skip-chars-forward " \t"))))
                           (current-column))
                       (progn
                         (goto-char fst)
                         (+ (current-column) verilog-cexp-indent))))))
            (goto-char here)
            (indent-line-to val)
            (if (and (not verilog-indent-lists)
                     (verilog-in-paren))
                (verilog-pretty-declarations-auto))
            ))
         ((= (preceding-char) ?\) )
          (goto-char here)
          (let ((val (eval (cdr (assoc type verilog-indent-alist)))))
            (indent-line-to val)))
         (t
          (goto-char here)
          (let ((val))
            (verilog-beg-of-statement-1)
            (if (and (< (point) here)
                     (verilog-re-search-forward "=[ \t]*" here 'move)
                     ;; not at a |=>, #=#, or [=n] operator
                     (not (string-match "\\[=.\\|#=#\\||=>"
                                        (or (buffer-substring (- (point) 2) (1+ (point)))
                                            ""))))  ; don't let buffer over/under-run spoil the party
                (setq val (current-column))
              (setq val (eval (cdr (assoc type verilog-indent-alist)))))
            (goto-char here)
            (indent-line-to val))))))

     (; handle inside parenthetical expressions
      (eq type 'cparenexp)
      (let* (here
             (current-depth (verilog-in-paren-count))
             (next-depth (save-excursion
                           (forward-char 1)
                           (verilog-in-paren-count)))
             (val (save-excursion
                    (verilog-backward-up-list 1)
                    (forward-char 1)
                    (if verilog-indent-lists
                        (progn (skip-chars-forward " \t")
                               (setq here (point))
                               (if (> current-depth next-depth) ; End of parentheses, indent 1 level less
                                   (progn (back-to-indentation)
                                          (current-column))
                                 (progn (if (eolp) ; first list item start from next line, +1 level on before list indentation
                                            (progn (back-to-indentation)
                                                   (+ verilog-indent-level (current-column)))
                                          (current-column)))))
                      (progn (verilog-forward-syntactic-ws)
                             (setq here (point))
                             (current-column)))))
             (decl (save-excursion
                     (goto-char here)
                     (verilog-forward-syntactic-ws)
                     (setq here (point))
                     (looking-at verilog-declaration-re))))
        (indent-line-to val)
        (if decl
            (verilog-pretty-declarations-auto))))

     (;-- Handle the ends
      (or
       (looking-at verilog-end-block-re)
       (verilog-at-close-constraint-p)
       (verilog-at-close-struct-p))
      (let ((val (if (eq type 'statement)
                     (if (> ind verilog-indent-level)
                         (- ind verilog-indent-level)
                       0)
                   ind)))
        (indent-line-to val)))

     (;-- Case -- maybe line 'em up
      (and (eq type 'case) (not (looking-at "^[ \t]*$")))
      (progn
        (cond
         ((looking-at "\\<endcase\\>")
          (indent-line-to ind))
         (t
          (let ((val (eval (cdr (assoc type verilog-indent-alist)))))
            (indent-line-to val))))))

     (;-- defun
      (and (eq type 'defun)
           (looking-at verilog-zero-indent-re))
      (indent-line-to 0))

     (;-- declaration
      (and (or
            (eq type 'defun)
            (eq type 'block))
           (looking-at verilog-declaration-re)
           ;; Do not consider "virtual function", "virtual task", "virtual class"
           ;; as declarations
           (not (looking-at (concat verilog-declaration-re
                                    "\\s-+\\(function\\|task\\|class\\)\\b"))))
      (verilog-indent-declaration ind))

     (;-- form feeds - ignored as bug in indent-line-to in < 24.5
      (looking-at "\f"))

     (;-- Everything else
      t
      (let ((val (eval (cdr (assoc type verilog-indent-alist)))))
        (indent-line-to val))))

    (if (looking-at "[ \t]+$")
        (skip-chars-forward " \t"))
    indent-str				; Return indent data
    ))

(defun verilog-current-indent-level ()
  "Return the indent-level of the current statement."
  (save-excursion
    (let (par-pos)
      (beginning-of-line)
      (setq par-pos (verilog-parenthesis-depth))
      (while par-pos
        (goto-char par-pos)
        (beginning-of-line)
        (setq par-pos (verilog-parenthesis-depth)))
      (skip-chars-forward " \t")
      (current-column))))

(defun verilog-case-indent-level ()
  "Return the indent-level of the current statement.
Do not count named blocks or case-statements."
  (save-excursion
    (skip-chars-forward " \t")
    (cond
     ((looking-at verilog-named-block-re)
      (current-column))
     ((and (not (looking-at verilog-extended-case-re))
           (looking-at "^[^:;]+[ \t]*:"))
      (verilog-re-search-forward ":" nil t)
      (skip-chars-forward " \t")
      (current-column))
     (t
      (current-column)))))

(defun verilog-indent-comment ()
  "Indent current line as comment."
  (let* ((stcol
          (cond
           ((verilog-in-star-comment-p)
            (save-excursion
              (re-search-backward "/\\*" nil t)
              (1+(current-column))))
           (comment-column
            comment-column )
           (t
            (save-excursion
              (re-search-backward "//" nil t)
              (current-column))))))
    (indent-line-to stcol)
    stcol))

(defun verilog-more-comment ()
  "Make more comment lines like the previous."
  (let* ((star 0)
         (stcol
          (cond
           ((verilog-in-star-comment-p)
            (save-excursion
              (setq star 1)
              (re-search-backward "/\\*" nil t)
              (1+(current-column))))
           (comment-column
            comment-column )
           (t
            (save-excursion
              (re-search-backward "//" nil t)
              (current-column))))))
    (progn
      (indent-to stcol)
      (if (and star
               (save-excursion
                 (forward-line -1)
                 (skip-chars-forward " \t")
                 (looking-at "\\*")))
          (insert "* ")))))

(defun verilog-comment-indent (&optional _arg)
  "Return the column number the line should be indented to.
_ARG is ignored, for `comment-indent-function' compatibility."
  (cond
   ((verilog-in-star-comment-p)
    (save-excursion
      (re-search-backward "/\\*" nil t)
      (1+(current-column))))
   ( comment-column
     comment-column )
   (t
    (save-excursion
      (re-search-backward "//" nil t)
      (current-column)))))

;;

(defun verilog-pretty-declarations-auto (&optional quiet)
  "Call `verilog-pretty-declarations' QUIET based on `verilog-auto-lineup'."
  (when (or (eq 'all verilog-auto-lineup)
            (eq 'declarations verilog-auto-lineup))
    (verilog-pretty-declarations quiet)))

(defun verilog-pretty-declarations (&optional quiet)
  "Line up declarations around point.
Be verbose about progress unless optional QUIET set."
  (interactive)
  (let* ((m1 (make-marker))
         (e (point))
         el
         r
         (here (point))
         ind
         start
         startpos
         end
         endpos
         base-ind
         )
    (save-excursion
      (if (progn
            ;; (verilog-beg-of-statement-1)
            (beginning-of-line)
            (verilog-forward-syntactic-ws)
            (and (not (verilog-in-directive-p))  ; could have `define input foo
                 (looking-at verilog-declaration-re)))
          (progn
            (if (verilog-parenthesis-depth)
                ;; in an argument list or parameter block
                (setq el (verilog-backward-up-list -1)
                      start (progn
                              (goto-char e)
                              (verilog-backward-up-list 1)
                              (forward-line)  ; ignore ( input foo,
                              (verilog-re-search-forward verilog-declaration-re el 'move)
                              (goto-char (match-beginning 0))
                              (skip-chars-backward " \t")
                              (point))
                      startpos (set-marker (make-marker) start)
                      end (progn
                            (goto-char start)
                            (verilog-backward-up-list -1)
                            (forward-char -1)
                            (verilog-backward-syntactic-ws)
                            (point))
                      endpos (set-marker (make-marker) end)
                      base-ind (progn
                                 (goto-char start)
                                 (forward-char 1)
                                 (skip-chars-forward " \t")
                                 (current-column)))
              ;; in a declaration block (not in argument list)
              (setq
               start (progn
                       (verilog-beg-of-statement-1)
                       (while (and (looking-at verilog-declaration-re)
                                   (not (bobp)))
                         (skip-chars-backward " \t")
                         (setq e (point))
                         (beginning-of-line)
                         (verilog-backward-syntactic-ws)
                         (backward-char)
                         (verilog-beg-of-statement-1))
                       e)
               startpos (set-marker (make-marker) start)
               end (progn
                     (goto-char here)
                     (verilog-end-of-statement)
                     (setq e (point))	;Might be on last line
                     (verilog-forward-syntactic-ws)
                     (while (looking-at verilog-declaration-re)
                       (verilog-end-of-statement)
                       (setq e (point))
                       (verilog-forward-syntactic-ws))
                     e)
               endpos (set-marker (make-marker) end)
               base-ind (progn
                          (goto-char start)
                          (verilog-do-indent (verilog-calculate-indent))
                          (verilog-forward-ws&directives)
                          (current-column))))
            ;; OK, start and end are set
            (goto-char (marker-position startpos))
            (if (and (not quiet)
                     (> (- end start) 100))
                (message "Lining up declarations..(please stand by)"))
            ;; Get the beginning of line indent first
            (while (progn (setq e (marker-position endpos))
                          (< (point) e))
              (cond
               ((save-excursion (skip-chars-backward " \t")
                                (bolp))
                (verilog-forward-ws&directives)
                (indent-line-to base-ind)
                (verilog-forward-ws&directives)
                (if (< (point) e)
                    (verilog-re-search-forward "[ \t\n\f]" e 'move)))
               (t
                (just-one-space)
                (verilog-re-search-forward "[ \t\n\f]" e 'move)))
              ;;(forward-line)
              )
            ;; Now find biggest prefix
            (setq ind (verilog-get-lineup-indent (marker-position startpos) endpos))
            ;; Now indent each line.
            (goto-char (marker-position startpos))
            (while (progn (setq e (marker-position endpos))
                          (setq r (- e (point)))
                          (> r 0))
              (setq e (point))
              (unless quiet (message "%d" r))
              ;; (verilog-do-indent (verilog-calculate-indent)))
              (verilog-forward-ws&directives)
              (cond
               ((or (and verilog-indent-declaration-macros
                         (looking-at verilog-declaration-re-2-macro))
                    (looking-at verilog-declaration-re-2-no-macro))
                (let ((p (match-end 0)))
                  (set-marker m1 p)
                  (if (verilog-re-search-forward "[[#`]" p 'move)
                      (progn
                        (forward-char -1)
                        (just-one-space)
                        (goto-char (marker-position m1))
                        (just-one-space)
                        (indent-to ind))
                    (progn
                      (just-one-space)
                      (indent-to ind)))))
               ((verilog-continued-line-1 (marker-position startpos))
                (goto-char e)
                (indent-line-to ind))
               ((verilog-in-struct-p)
                ;; could have a declaration of a user defined item
                (goto-char e)
                (verilog-end-of-statement))
               (t		; Must be comment or white space
                (goto-char e)
                (verilog-forward-ws&directives)
                (forward-line -1)))
              (forward-line 1))
            (unless quiet (message "")))))))

(defun verilog-pretty-expr (&optional quiet)
  "Line up expressions around point.
If QUIET is non-nil, do not print messages showing the progress of line-up."
  (interactive)
  (unless (verilog-in-comment-or-string-p)
    (save-excursion
      (let ((regexp (concat "^\\s-*" verilog-complete-reg))
            (regexp1 (concat "^\\s-*" verilog-basic-complete-re)))
        (beginning-of-line)
        (if (verilog-assign-statement-p)
            (verilog-align-assign)
          (when (and (not (looking-at regexp))
                     (looking-at verilog-assignment-operation-re)
                     (save-excursion
                       (goto-char (match-end 2))
                       (and (not (verilog-in-attribute-p))
                            (not (verilog-in-parameter-p))
                            (not (verilog-in-comment-or-string-p)))))
            (let* ((start (save-excursion ; BOL of the first line of the assignment block
                            (beginning-of-line)
                            (let ((pt (point)))
                              (verilog-backward-syntactic-ws)
                              (beginning-of-line)
                              (while (and (not (looking-at regexp1))
                                          (looking-at verilog-assignment-operation-re)
                                          (not (bobp)))
                                (setq pt (point))
                                (verilog-backward-syntactic-ws)
                                (beginning-of-line)) ; Ack, need to grok `define
                              pt)))
                   (end (save-excursion ; EOL of the last line of the assignment block
                          (end-of-line)
                          (let ((pt (point))) ; Might be on last line
                            (verilog-forward-syntactic-ws)
                            (beginning-of-line)
                            (while (and
                                    (not (looking-at regexp1))
                                    (looking-at verilog-assignment-operation-re)
                                    (progn
                                      (end-of-line)
                                      (not (eq pt (point)))))
                              (setq pt (point))
                              (verilog-forward-syntactic-ws)
                              (beginning-of-line))
                            pt)))
                   (contains-2-char-operator (string-match "<=" (buffer-substring-no-properties start end)))
                   (endmark (set-marker (make-marker) end)))
              (goto-char start)
              (verilog-do-indent (verilog-calculate-indent))
              (when (and (not quiet)
                         (> (- end start) 100))
                (message "Lining up expressions.. (please stand by)"))

              ;; Set indent to minimum throughout region
              ;; Rely on mark rather than on point as the indentation changes can
              ;; make the older point reference obsolete
              (while (< (point) (marker-position endmark))
                (beginning-of-line)
                (save-excursion
                  (verilog-just-one-space verilog-assignment-operation-re))
                (verilog-do-indent (verilog-calculate-indent))
                (end-of-line)
                (verilog-forward-syntactic-ws))

              (let ((ind (verilog-get-lineup-indent-2 verilog-assignment-operation-re start (marker-position endmark))) ; Find the biggest prefix
                    e)
                ;; Now indent each line.
                (goto-char start)
                (while (progn
                         (setq e (marker-position endmark))
                         (> e (point)))
                  (unless quiet
                    (message " verilog-pretty-expr: %d" (- e (point))))
                  (setq e (point))
                  (cond
                   ((looking-at verilog-assignment-operation-re)
                    (goto-char (match-beginning 2))
                    (unless (or (verilog-in-parenthesis-p) ; Leave attributes and comparisons alone
                                (verilog-in-coverage-p))
                      (if (and contains-2-char-operator
                               (eq (char-after) ?=))
                          (indent-to (1+ ind)) ; Line up the = of the <= with surrounding =
                        (indent-to ind))))
                   ((verilog-continued-line-1 start)
                    (goto-char e)
                    (indent-line-to ind))
                   (t                     ; Must be comment or white space
                    (goto-char e)
                    (verilog-forward-ws&directives)
                    (forward-line -1)))
                  (forward-line 1))
                (unless quiet
                  (message ""))))))))))

(defun verilog-just-one-space (myre)
  "Remove extra spaces around regular expression MYRE."
  (interactive)
  (if (and (not(looking-at verilog-complete-reg))
           (looking-at myre))
      (let ((p1 (match-end 1))
            (p2 (match-end 2)))
        (progn
          (goto-char p2)
          (just-one-space)
          (goto-char p1)
          (just-one-space)))))

(defun verilog-indent-declaration (baseind)
  "Indent current lines as declaration.
Line up the variable names based on previous declaration's indentation.
BASEIND is the base indent to offset everything."
  (interactive)
  (let ((pos (point-marker))
        (lim (save-excursion
               ;; (verilog-re-search-backward verilog-declaration-opener nil 'move)
               (verilog-re-search-backward "\\(\\<begin\\>\\)\\|\\(\\<module\\>\\)\\|\\(\\<task\\>\\)" nil 'move)
               (point)))
        (ind)
        (val)
        (m1 (make-marker)))
    (setq val
          (+ baseind (eval (cdr (assoc 'declaration verilog-indent-alist)))))
    (indent-line-to val)

    ;; Use previous declaration (in this module) as template.
    (if (or (eq 'all verilog-auto-lineup)
            (eq 'declarations verilog-auto-lineup))
        (if (verilog-re-search-backward
             (or (and verilog-indent-declaration-macros
                      verilog-declaration-re-1-macro)
                 verilog-declaration-re-1-no-macro) lim t)
            (progn
              (goto-char (match-end 0))
              (skip-chars-forward " \t")
              (setq ind (current-column))
              (goto-char pos)
              (setq val
                    (+ baseind
                       (eval (cdr (assoc 'declaration verilog-indent-alist)))))
              (indent-line-to val)
              (if (and verilog-indent-declaration-macros
                       (looking-at verilog-declaration-re-2-macro))
                  (let ((p (match-end 0)))
                    (set-marker m1 p)
                    (if (verilog-re-search-forward "[[#`]" p 'move)
                        (progn
                          (forward-char -1)
                          (just-one-space)
                          (goto-char (marker-position m1))
                          (just-one-space)
                          (indent-to ind))
                      (if (/= (current-column) ind)
                          (progn
                            (just-one-space)
                            (indent-to ind)))))
                (if (looking-at verilog-declaration-re-2-no-macro)
                    (let ((p (match-end 0)))
                      (set-marker m1 p)
                      (if (verilog-re-search-forward "[[`#]" p 'move)
                          (progn
                            (forward-char -1)
                            (just-one-space)
                            (goto-char (marker-position m1))
                            (just-one-space)
                            (indent-to ind))
                        (if (/= (current-column) ind)
                            (progn
                              (just-one-space)
                              (indent-to ind))))))))))
    (goto-char pos)))

(defun verilog-get-lineup-indent (b edpos)
  "Return the indent level that will line up several lines within the region.
Region is defined by B and EDPOS."
  (save-excursion
    (let ((ind 0) e)
      (goto-char b)
      ;; Get rightmost position
      (while (progn (setq e (marker-position edpos))
                    (< (point) e))
        (if (verilog-re-search-forward
             (or (and verilog-indent-declaration-macros
                      verilog-declaration-re-1-macro)
                 verilog-declaration-re-1-no-macro) e 'move)
            (progn
              (goto-char (match-end 0))
              (verilog-backward-syntactic-ws)
              (if (> (current-column) ind)
                  (setq ind (current-column)))
              (goto-char (match-end 0)))))
      (if (> ind 0)
          (1+ ind)
        ;; No lineup-string found
        (goto-char b)
        (end-of-line)
        (verilog-backward-syntactic-ws)
        ;;(skip-chars-backward " \t")
        (1+ (current-column))))))

(defun verilog-get-lineup-indent-2 (regexp beg end)
  "Return the indent level that will line up several lines.
The lineup string is searched using REGEXP within the region between points
BEG and END."
  (save-excursion
    (let ((ind 0))
      (goto-char beg)
      ;; Get rightmost position
      (while (< (point) end)
        (when (and (verilog-re-search-forward regexp end 'move)
                   (not (verilog-in-attribute-p))) ; skip attribute exprs
          (goto-char (match-beginning 2))
          (verilog-backward-syntactic-ws)
          (if (> (current-column) ind)
              (setq ind (current-column)))
          (goto-char (match-end 0))))
      (setq ind (if (> ind 0)
                    (1+ ind)
                  ;; No lineup-string found
                  (goto-char beg)
                  (end-of-line)
                  (skip-chars-backward " \t")
                  (1+ (current-column))))
      ind)))



;;; Completion:
;;
(defvar verilog-str nil)
(defvar verilog-all nil)
(defvar verilog-pred nil)
(defvar verilog-buffer-to-use nil)
(defvar verilog-flag nil)
(defvar verilog-toggle-completions nil
  "True means \\<verilog-mode-map>\\[verilog-complete-word] should try all possible completions one by one.
Repeated use of \\[verilog-complete-word] will show you all of them.
Normally, when there is more than one possible completion,
it displays a list of all possible completions.")
(when (boundp 'completion-cycle-threshold)
  (make-obsolete-variable
   'verilog-toggle-completions 'completion-cycle-threshold "26.1"))


(defvar verilog-type-keywords
  '(
    "and" "buf" "bufif0" "bufif1" "cmos" "defparam" "inout" "input"
    "integer" "localparam" "logic" "mailbox" "nand" "nmos" "nor" "not" "notif0"
    "notif1" "or" "output" "parameter" "pmos" "pull0" "pull1" "pulldown" "pullup"
    "rcmos" "real" "realtime" "reg" "rnmos" "rpmos" "rtran" "rtranif0"
    "rtranif1" "semaphore" "time" "tran" "tranif0" "tranif1" "tri" "tri0" "tri1"
    "triand" "trior" "trireg" "wand" "wire" "wor" "xnor" "xor"
    )
  "Keywords for types used when completing a word in a declaration or parmlist.
\(integer, real, reg...)")

(defvar verilog-cpp-keywords
  '("module" "macromodule" "primitive" "timescale" "define" "ifdef" "ifndef" "else"
    "endif")
  "Keywords to complete when at first word of a line in declarative scope.
\(initial, always, begin, assign...)
The procedures and variables defined within the Verilog program
will be completed at runtime and should not be added to this list.")

(defvar verilog-defun-keywords
  (append
   '(
     "always" "always_comb" "always_ff" "always_latch" "assign"
     "begin" "end" "generate" "endgenerate" "module" "endmodule"
     "specify" "endspecify" "function" "endfunction" "initial" "final"
     "task" "endtask" "primitive" "endprimitive"
     )
   verilog-type-keywords)
  "Keywords to complete when at first word of a line in declarative scope.
\(initial, always, begin, assign...)
The procedures and variables defined within the Verilog program
will be completed at runtime and should not be added to this list.")

(defvar verilog-block-keywords
  '(
    "begin" "break" "case" "continue" "else" "end" "endfunction"
    "endgenerate" "endinterface" "endpackage" "endspecify" "endtask"
    "for" "fork" "if" "join" "join_any" "join_none" "repeat" "return"
    "while")
  "Keywords to complete when at first word of a line in behavioral scope.
\(begin, if, then, else, for, fork...)
The procedures and variables defined within the Verilog program
will be completed at runtime and should not be added to this list.")

(defvar verilog-tf-keywords
  '("begin" "break" "fork" "join" "join_any" "join_none" "case" "end" "endtask" "endfunction" "if" "else" "for" "while" "repeat")
  "Keywords to complete when at first word of a line in a task or function.
\(begin, if, then, else, for, fork.)
The procedures and variables defined within the Verilog program
will be completed at runtime and should not be added to this list.")

(defvar verilog-case-keywords
  '("begin" "fork" "join" "join_any" "join_none" "case" "end" "endcase" "if" "else" "for" "repeat")
  "Keywords to complete when at first word of a line in case scope.
\(begin, if, then, else, for, fork...)
The procedures and variables defined within the Verilog program
will be completed at runtime and should not be added to this list.")

(defvar verilog-separator-keywords
  '("else" "then" "begin")
  "Keywords to complete when NOT standing at the first word of a statement.
\(else, then, begin...)
Variables and function names defined within the Verilog program
will be completed at runtime and should not be added to this list.")

(defvar verilog-gate-ios
  ;; All these have an implied {"input"...} at the end
  '(("and"	"output")
    ("buf"	"output")
    ("bufif0"	"output")
    ("bufif1"	"output")
    ("cmos"	"output")
    ("nand"	"output")
    ("nmos"	"output")
    ("nor"	"output")
    ("not"	"output")
    ("notif0"	"output")
    ("notif1"	"output")
    ("or"	"output")
    ("pmos"	"output")
    ("pulldown"	"output")
    ("pullup"	"output")
    ("rcmos"	"output")
    ("rnmos"	"output")
    ("rpmos"	"output")
    ("rtran"	"inout" "inout")
    ("rtranif0"	"inout" "inout")
    ("rtranif1"	"inout" "inout")
    ("tran"	"inout" "inout")
    ("tranif0"	"inout" "inout")
    ("tranif1"	"inout" "inout")
    ("xnor"	"output")
    ("xor"	"output"))
  "Map of direction for each positional argument to each gate primitive.")

(defvar verilog-gate-keywords (mapcar `car verilog-gate-ios)
  "Keywords for gate primitives.")

(defun verilog-string-diff (str1 str2)
  "Return index of first letter where STR1 and STR2 differs."
  (catch 'done
    (let ((diff 0))
      (while t
        (if (or (> (1+ diff) (length str1))
                (> (1+ diff) (length str2)))
            (throw 'done diff))
        (or (equal (aref str1 diff) (aref str2 diff))
            (throw 'done diff))
        (setq diff (1+ diff))))))

;; Calculate all possible completions for functions if argument is `function',
;; completions for procedures if argument is `procedure' or both functions and
;; procedures otherwise.

(defun verilog-func-completion (type)
  "Build regular expression for module/task/function names.
TYPE is `module', `tf' for task or function, or t if unknown."
  (if (string= verilog-str "")
      (setq verilog-str "[a-zA-Z_]"))
  (let ((verilog-str (concat (cond
                              ((eq type 'module) "\\<\\(module\\)\\s +")
                              ((eq type 'tf) "\\<\\(task\\|function\\)\\s +")
                              (t "\\<\\(task\\|function\\|module\\)\\s +"))
                             "\\<\\(" verilog-str "[a-zA-Z0-9_.]*\\)\\>"))
        match)

    (if (not (looking-at verilog-defun-re))
        (verilog-re-search-backward verilog-defun-re nil t))
    (forward-char 1)

    ;; Search through all reachable functions
    (goto-char (point-min))
    (while (verilog-re-search-forward verilog-str (point-max) t)
      (progn (setq match (buffer-substring (match-beginning 2)
                                           (match-end 2)))
             (if (or (null verilog-pred)
                     (funcall verilog-pred match))
                 (setq verilog-all (cons match verilog-all)))))
    (if (match-beginning 0)
        (goto-char (match-beginning 0)))))

(defun verilog-get-completion-decl (end)
  "Macro for searching through current declaration (var, type or const)
for matches of `str' and adding the occurrence tp `all' through point END."
  (let ((re (or (and verilog-indent-declaration-macros
                     verilog-declaration-re-2-macro)
                verilog-declaration-re-2-no-macro))
        decl-end match)
    ;; Traverse lines
    (while (and (< (point) end)
                (verilog-re-search-forward re end t))
      ;; Traverse current line
      (setq decl-end (save-excursion (verilog-declaration-end)))
      (while (and (verilog-re-search-forward verilog-symbol-re decl-end t)
                  (not (match-end 1)))
        (setq match (buffer-substring (match-beginning 0) (match-end 0)))
        (if (string-match (concat "\\<" verilog-str) match)
            (if (or (null verilog-pred)
                    (funcall verilog-pred match))
                (setq verilog-all (cons match verilog-all)))))
      (forward-line 1)))
  verilog-all)

(defun verilog-var-completion ()
  "Calculate all possible completions for variables (or constants)."
  (let ((start (point)))
    ;; Search for all reachable var declarations
    (verilog-beg-of-defun)
    (save-excursion
      ;; Check var declarations
      (verilog-get-completion-decl start))))

(defun verilog-keyword-completion (keyword-list)
  "Give list of all possible completions of keywords in KEYWORD-LIST."
  (mapcar (lambda (s)
            (if (string-match (concat "\\<" verilog-str) s)
                (if (or (null verilog-pred)
                        (funcall verilog-pred s))
                    (setq verilog-all (cons s verilog-all)))))
          keyword-list))


(defun verilog-completion (verilog-str verilog-pred verilog-flag)
  "Function passed to `completing-read', `try-completion' or `all-completions'.
Called to get completion on VERILOG-STR.  If VERILOG-PRED is non-nil, it
must be a function to be called for every match to check if this should
really be a match.  If VERILOG-FLAG is t, the function returns a list of
all possible completions.  If VERILOG-FLAG is nil it returns a string,
the longest possible completion, or t if VERILOG-STR is an exact match.
If VERILOG-FLAG is `lambda', the function returns t if VERILOG-STR is an
exact match, nil otherwise."
  (save-excursion
    (let ((verilog-all nil))
      ;; Set buffer to use for searching labels. This should be set
      ;; within functions which use verilog-completions
      (set-buffer verilog-buffer-to-use)

      ;; Determine what should be completed
      (let ((state (car (verilog-calculate-indent))))
        (cond ((eq state 'defun)
               (save-excursion (verilog-var-completion))
               (verilog-func-completion 'module)
               (verilog-keyword-completion verilog-defun-keywords))

              ((eq state 'behavioral)
               (save-excursion (verilog-var-completion))
               (verilog-func-completion 'module)
               (verilog-keyword-completion verilog-defun-keywords))

              ((eq state 'block)
               (save-excursion (verilog-var-completion))
               (verilog-func-completion 'tf)
               (verilog-keyword-completion verilog-block-keywords))

              ((eq state 'case)
               (save-excursion (verilog-var-completion))
               (verilog-func-completion 'tf)
               (verilog-keyword-completion verilog-case-keywords))

              ((eq state 'tf)
               (save-excursion (verilog-var-completion))
               (verilog-func-completion 'tf)
               (verilog-keyword-completion verilog-tf-keywords))

              ((eq state 'cpp)
               (save-excursion (verilog-var-completion))
               (verilog-keyword-completion verilog-cpp-keywords))

              ((eq state 'cparenexp)
               (save-excursion (verilog-var-completion)))

              (t;--Anywhere else
               (save-excursion (verilog-var-completion))
               (verilog-func-completion 'both)
               (verilog-keyword-completion verilog-separator-keywords))))

      ;; Now we have built a list of all matches. Give response to caller
      (verilog-completion-response))))

(defun verilog-completion-response ()
  (cond ((or (equal verilog-flag 'lambda) (null verilog-flag))
         ;; This was not called by all-completions
         (if (null verilog-all)
             ;; Return nil if there was no matching label
             nil
           ;; Get longest string common in the labels
           ;; FIXME: Why not use `try-completion'?
           (let* ((elm (cdr verilog-all))
                  (match (car verilog-all))
                  (min (length match))
                  tmp)
             (if (string= match verilog-str)
                 ;; Return t if first match was an exact match
                 (setq match t)
               (while (not (null elm))
                 ;; Find longest common string
                 (if (< (setq tmp (verilog-string-diff match (car elm))) min)
                     (progn
                       (setq min tmp)
                       (setq match (substring match 0 min))))
                 ;; Terminate with match=t if this is an exact match
                 (if (string= (car elm) verilog-str)
                     (progn
                       (setq match t)
                       (setq elm nil))
                   (setq elm (cdr elm)))))
             ;; If this is a test just for exact match, return nil ot t
             (if (and (equal verilog-flag 'lambda) (not (equal match 't)))
                 nil
               match))))
        ;; If flag is t, this was called by all-completions. Return
        ;; list of all possible completions
        (verilog-flag
         verilog-all)))

(defvar verilog-last-word-numb 0)
(defvar verilog-last-word-shown nil)
(defvar verilog-last-completions nil)

(defun verilog-completion-at-point ()
  "Used as an element of `completion-at-point-functions'.
\(See also `verilog-type-keywords' and
`verilog-separator-keywords'.)"
  (let* ((b (save-excursion (skip-chars-backward "a-zA-Z0-9_") (point)))
         (e (save-excursion (skip-chars-forward "a-zA-Z0-9_") (point)))
         (verilog-str (buffer-substring b e))
         ;; The following variable is used in verilog-completion
         (verilog-buffer-to-use (current-buffer))
         (allcomp (if (and verilog-toggle-completions
                           (string= verilog-last-word-shown verilog-str))
                      verilog-last-completions
                    (all-completions verilog-str 'verilog-completion))))
    (list b e allcomp)))

(defun verilog-complete-word ()
  "Complete word at current point.
\(See also `verilog-toggle-completions', `verilog-type-keywords',
and `verilog-separator-keywords'.)"
  ;; NOTE: This is just a fallback for Emacs versions lacking
  ;; `completion-at-point'.
  (interactive)
  (let* ((comp-info (verilog-completion-at-point))
         (b (nth 0 comp-info))
         (e (nth 1 comp-info))
         (verilog-str (buffer-substring b e))
         (allcomp (nth 2 comp-info))
         (match (if verilog-toggle-completions
                    "" (try-completion
                        verilog-str (mapcar (lambda (elm)
                                              (cons elm 0)) allcomp)))))
    ;; Delete old string
    (delete-region b e)

    ;; Toggle-completions inserts whole labels
    (if verilog-toggle-completions
        (progn
          ;; Update entry number in list
          (setq verilog-last-completions allcomp
                verilog-last-word-numb
                (if (>= verilog-last-word-numb (1- (length allcomp)))
                    0
                  (1+ verilog-last-word-numb)))
          (setq verilog-last-word-shown (elt allcomp verilog-last-word-numb))
          ;; Display next match or same string if no match was found
          (if (not (null allcomp))
              (insert "" verilog-last-word-shown)
            (insert "" verilog-str)
            (message "(No match)")))
      ;; The other form of completion does not necessarily do that.

      ;; Insert match if found, or the original string if no match
      (if (or (null match) (equal match 't))
          (progn (insert "" verilog-str)
                 (message "(No match)"))
        (insert "" match))
      ;; Give message about current status of completion
      (cond ((equal match 't)
             (if (not (null (cdr allcomp)))
                 (message "(Complete but not unique)")
               (message "(Sole completion)")))
            ;; Display buffer if the current completion didn't help
            ;; on completing the label.
            ((and (not (null (cdr allcomp))) (= (length verilog-str)
                                                (length match)))
             (with-output-to-temp-buffer "*Completions*"
               (display-completion-list allcomp))
             ;; Wait for a key press. Then delete *Completion*  window
             (momentary-string-display "" (point))
             (delete-window (get-buffer-window (get-buffer "*Completions*")))
             )))))

(defun verilog-show-completions ()
  "Show all possible completions at current point."
  ;; NOTE: This is just a fallback for Emacs versions lacking
  ;; `completion-help-at-point'.
  (interactive)
  ;; Show possible completions in a temporary buffer.
  (with-output-to-temp-buffer "*Completions*"
    (display-completion-list (nth 2 (verilog-completion-at-point))))
  ;; Wait for a key press. Then delete *Completion*  window
  (momentary-string-display "" (point))
  (delete-window (get-buffer-window (get-buffer "*Completions*"))))

(defun verilog-get-default-symbol ()
  "Return symbol around current point as a string."
  (save-excursion
    (buffer-substring (progn
                        (skip-chars-backward " \t")
                        (skip-chars-backward "a-zA-Z0-9_")
                        (point))
                      (progn
                        (skip-chars-forward "a-zA-Z0-9_")
                        (point)))))

(defun verilog-build-defun-re (str &optional arg)
  "Return function/task/module starting with STR as regular expression.
With optional second ARG non-nil, STR is the complete name of the instruction."
  (let ((keywords-prefix "^[ \t]*\\(class\\|function\\|interface\\|module\\|package\\|\\program\\|task\\)[ \t]+\\("))
    (if arg
      (concat keywords-prefix str "\\)\\>")
      (concat keywords-prefix str "[a-zA-Z0-9_]*\\)\\>"))))

(defun verilog-comp-defun (verilog-str verilog-pred verilog-flag)
  "Function passed to `completing-read', `try-completion' or `all-completions'.
Returns a completion on any function name based on VERILOG-STR prefix.  If
VERILOG-PRED is non-nil, it must be a function to be called for every match
to check if this should really be a match.  If VERILOG-FLAG is t, the
function returns a list of all possible completions.  If it is nil it
returns a string, the longest possible completion, or t if VERILOG-STR is
an exact match.  If VERILOG-FLAG is `lambda', the function returns t if
VERILOG-STR is an exact match, nil otherwise."
  (save-excursion
    (let ((verilog-all nil)
          match)

      ;; Set buffer to use for searching labels. This should be set
      ;; within functions which use verilog-completions
      (set-buffer verilog-buffer-to-use)

      (let ((verilog-str verilog-str))
        ;; Build regular expression for functions
        (if (string= verilog-str "")
            (setq verilog-str (verilog-build-defun-re "[a-zA-Z_]"))
          (setq verilog-str (verilog-build-defun-re verilog-str)))
        (goto-char (point-min))

        ;; Build a list of all possible completions
        (while (verilog-re-search-forward verilog-str nil t)
          (setq match (buffer-substring (match-beginning 2) (match-end 2)))
          (if (or (null verilog-pred)
                  (funcall verilog-pred match))
              (setq verilog-all (cons match verilog-all)))))

      ;; Now we have built a list of all matches. Give response to caller
      (verilog-completion-response))))

(defun verilog-goto-defun ()
  "Move to specified Verilog module/interface/task/function.
The default is a name found in the buffer around point.
If search fails, other files are checked based on
`verilog-library-flags'."
  (interactive)
  (let* ((default (verilog-get-default-symbol))
         ;; The following variable is used in verilog-comp-function
         (verilog-buffer-to-use (current-buffer))
         (label (if (not (string= default ""))
                    ;; Do completion with default
                    (completing-read (concat "Goto-Label: (default "
                                             default ") ")
                                     'verilog-comp-defun nil nil "")
                  ;; There is no default value. Complete without it
                  (completing-read "Goto-Label: "
                                   'verilog-comp-defun nil nil "")))
         pt)
    ;; Make sure library paths are correct, in case need to resolve module
    (verilog-auto-reeval-locals)
    (verilog-getopt-flags)
    ;; If there was no response on prompt, use default value
    (if (string= label "")
        (setq label default))
    ;; Goto right place in buffer if label is not an empty string
    (or (string= label "")
        (progn
          (save-excursion
            (goto-char (point-min))
            (setq pt
                  (re-search-forward (verilog-build-defun-re label t) nil t)))
          (when pt
            (goto-char pt)
            (beginning-of-line))
          pt)
        (verilog-goto-defun-file label))))

;; Eliminate compile warning
(defvar occur-pos-list)

(defun verilog-showscopes ()
  "List all scopes in this module."
  (interactive)
  (let ((buffer (current-buffer))
        (linenum 1)
        (nlines 0)
        (first 1)
        (prevpos (point-min))
        (final-context-start (make-marker))
        (regexp "\\(module\\s-+\\w+\\s-*(\\)\\|\\(\\w+\\s-+\\w+\\s-*(\\)"))
    (with-output-to-temp-buffer "*Occur*"
      (save-excursion
        (message "Searching for %s ..." regexp)
        ;; Find next match, but give up if prev match was at end of buffer.
        (while (and (not (= prevpos (point-max)))
                    (verilog-re-search-forward regexp nil t))
          (goto-char (match-beginning 0))
          (beginning-of-line)
          (save-match-data
            (setq linenum (+ linenum (count-lines prevpos (point)))))
          (setq prevpos (point))
          (goto-char (match-end 0))
          (let* ((start (save-excursion
                          (goto-char (match-beginning 0))
                          (forward-line (if (< nlines 0) nlines (- nlines)))
                          (point)))
                 (end (save-excursion
                        (goto-char (match-end 0))
                        (if (> nlines 0)
                            (forward-line (1+ nlines))
                          (forward-line 1))
                        (point)))
                 (tag (format "%3d" linenum))
                 (empty (make-string (length tag) ?\ ))
                 tem)
            (save-excursion
              (setq tem (make-marker))
              (set-marker tem (point))
              (set-buffer standard-output)
              (setq occur-pos-list (cons tem occur-pos-list))
              (or first (zerop nlines)
                  (insert "--------\n"))
              (setq first nil)
              (insert-buffer-substring buffer start end)
              (backward-char (- end start))
              (setq tem (if (< nlines 0) (- nlines) nlines))
              (while (> tem 0)
                (insert empty ?:)
                (forward-line 1)
                (setq tem (1- tem)))
              (let ((this-linenum linenum))
                (set-marker final-context-start
                            (+ (point) (- (match-end 0) (match-beginning 0))))
                (while (< (point) final-context-start)
                  (if (null tag)
                      (setq tag (format "%3d" this-linenum)))
                  (insert tag ?:)))))))
      (set-buffer-modified-p nil))))


;; Highlight helper functions
(defconst verilog-directive-regexp "\\(translate\\|coverage\\|lint\\)_")

(defun verilog-within-translate-off ()
  "Return point if within translate-off region, else nil."
  (and (save-excursion
         (re-search-backward
          (concat "//\\s-*.*\\s-*" verilog-directive-regexp "\\(on\\|off\\)\\>")
          nil t))
       (equal "off" (match-string 2))
       (point)))

(defun verilog-start-translate-off (limit)
  "Return point before translate-off directive if before LIMIT, else nil."
  (when (re-search-forward
         (concat "//\\s-*.*\\s-*" verilog-directive-regexp "off\\>")
         limit t)
    (match-beginning 0)))

(defun verilog-back-to-start-translate-off (limit)
  "Return point before translate-off directive if before LIMIT, else nil."
  (when (re-search-backward
         (concat "//\\s-*.*\\s-*" verilog-directive-regexp "off\\>")
         limit t)
    (match-beginning 0)))

(defun verilog-end-translate-off (limit)
  "Return point after translate-on directive if before LIMIT, else nil."
  (re-search-forward (concat
                      "//\\s-*.*\\s-*" verilog-directive-regexp "on\\>") limit t))

(defun verilog-match-translate-off (limit)
  "Match a translate-off block, setting `match-data' and returning t, else nil.
Bound search by LIMIT."
  (when (< (point) limit)
    (let ((start (or (verilog-within-translate-off)
                     (verilog-start-translate-off limit)))
          (case-fold-search t))
      (when start
        (let ((end (or (verilog-end-translate-off limit) limit)))
          (set-match-data (list start end))
          (goto-char end))))))



;;; Signal list parsing:
;;

;; Elements of a signal list
;; Unfortunately we use 'assoc' on this, so can't be a vector
(defsubst verilog-sig-new (name bits comment mem enum signed type multidim modport)
  (list name bits comment mem enum signed type multidim modport))
(defsubst verilog-sig-name (sig)
  (car sig))
(defsubst verilog-sig-bits (sig)  ; First element of packed array (pre signal-name)
  (nth 1 sig))
(defsubst verilog-sig-comment (sig)
  (nth 2 sig))
(defsubst verilog-sig-memory (sig)  ; Unpacked array (post signal-name)
  (nth 3 sig))
(defsubst verilog-sig-enum (sig)
  (nth 4 sig))
(defsubst verilog-sig-signed (sig)
  (nth 5 sig))
(defsubst verilog-sig-type (sig)
  (nth 6 sig))
(defsubst verilog-sig-type-set (sig type)
  (setcar (nthcdr 6 sig) type))
(defsubst verilog-sig-multidim (sig)  ; Second and additional elements of packed array
  (nth 7 sig))
(defsubst verilog-sig-multidim-string (sig)
  (if (verilog-sig-multidim sig)
      (let ((str "") (args (verilog-sig-multidim sig)))
        (while args
          (setq str (concat (car args) str))
          (setq args (cdr args)))
        str)))
(defsubst verilog-sig-modport (sig)
  (nth 8 sig))
(defsubst verilog-sig-width (sig)
  (verilog-make-width-expression (verilog-sig-bits sig)))

(defsubst verilog-alw-new (outputs-del outputs-imm temps inputs)
  (vector outputs-del outputs-imm temps inputs))
(defsubst verilog-alw-get-outputs-delayed (sigs)
  (aref sigs 0))
(defsubst verilog-alw-get-outputs-immediate (sigs)
  (aref sigs 1))
(defsubst verilog-alw-get-temps (sigs)
  (aref sigs 2))
(defsubst verilog-alw-get-inputs (sigs)
  (aref sigs 3))
(defsubst verilog-alw-get-uses-delayed (sigs)
  (aref sigs 0))

(defsubst verilog-modport-new (name clockings decls)
  (list name clockings decls))
(defsubst verilog-modport-name (sig)
  (car sig))
(defsubst verilog-modport-clockings (sig)
  (nth 1 sig))  ; Returns list of names
(defsubst verilog-modport-clockings-add (sig val)
  (setcar (nthcdr 1 sig) (cons val (nth 1 sig))))
(defsubst verilog-modport-decls (sig)
  (nth 2 sig))  ; Returns verilog-decls-* structure
(defsubst verilog-modport-decls-set (sig val)
  (setcar (nthcdr 2 sig) val))

(defsubst verilog-modi-new (name fob pt type)
  (vector name fob pt type))
(defsubst verilog-modi-name (modi)
  (aref modi 0))
(defsubst verilog-modi-file-or-buffer (modi)
  (aref modi 1))
(defsubst verilog-modi-get-point (modi)
  (aref modi 2))
(defsubst verilog-modi-get-type (modi)  ; "module" or "interface"
  (aref modi 3))
(defsubst verilog-modi-get-decls (modi)
  (verilog-modi-cache-results modi 'verilog-read-decls))
(defsubst verilog-modi-get-sub-decls (modi)
  (verilog-modi-cache-results modi 'verilog-read-sub-decls))

;; Signal reading for given module
;; Note these all take modi's - as returned from verilog-modi-current
(defsubst verilog-decls-new (out inout in vars modports assigns consts gparams interfaces)
  (vector out inout in vars modports assigns consts gparams interfaces))
(defsubst verilog-decls-append (a b)
  (cond ((not a) b) ((not b) a)
        (t (vector (append (aref a 0) (aref b 0))   (append (aref a 1) (aref b 1))
                   (append (aref a 2) (aref b 2))   (append (aref a 3) (aref b 3))
                   (append (aref a 4) (aref b 4))   (append (aref a 5) (aref b 5))
                   (append (aref a 6) (aref b 6))   (append (aref a 7) (aref b 7))
                   (append (aref a 8) (aref b 8))))))
(defsubst verilog-decls-get-outputs (decls)
  (aref decls 0))
(defsubst verilog-decls-get-inouts (decls)
  (aref decls 1))
(defsubst verilog-decls-get-inputs (decls)
  (aref decls 2))
(defsubst verilog-decls-get-vars (decls)
  (aref decls 3))
(defsubst verilog-decls-get-modports (decls)  ; Also for clocking blocks; contains another verilog-decls struct
  (aref decls 4))  ; Returns verilog-modport* structure
(defsubst verilog-decls-get-assigns (decls)
  (aref decls 5))
(defsubst verilog-decls-get-consts (decls)
  (aref decls 6))
(defsubst verilog-decls-get-gparams (decls)
  (aref decls 7))
(defsubst verilog-decls-get-interfaces (decls)
  (aref decls 8))


(defsubst verilog-subdecls-new (out inout in intf intfd)
  (vector out inout in intf intfd))
(defsubst verilog-subdecls-get-outputs (subdecls)
  (aref subdecls 0))
(defsubst verilog-subdecls-get-inouts (subdecls)
  (aref subdecls 1))
(defsubst verilog-subdecls-get-inputs (subdecls)
  (aref subdecls 2))
(defsubst verilog-subdecls-get-interfaces (subdecls)
  (aref subdecls 3))
(defsubst verilog-subdecls-get-interfaced (subdecls)
  (aref subdecls 4))

(defun verilog-signals-from-signame (signame-list)
  "Return signals in standard form from SIGNAME-LIST, a simple list of names."
  (mapcar (lambda (name) (verilog-sig-new name nil nil nil nil nil nil nil nil))
          signame-list))

(defun verilog-signals-in (in-list not-list)
  "Return list of signals in IN-LIST that are also in NOT-LIST.
Also remove any duplicates in IN-LIST.
Signals must be in standard (base vector) form."
  ;; This function is hot, so implemented as O(1)
  (cond ((eval-when-compile (fboundp 'make-hash-table))
         (let ((ht (make-hash-table :test 'equal :rehash-size 4.0))
               (ht-not (make-hash-table :test 'equal :rehash-size 4.0))
               out-list)
           (while not-list
             (puthash (car (car not-list)) t ht-not)
             (setq not-list (cdr not-list)))
           (while in-list
             (when (and (gethash (verilog-sig-name (car in-list)) ht-not)
                        (not (gethash (verilog-sig-name (car in-list)) ht)))
               (setq out-list (cons (car in-list) out-list))
               (puthash (verilog-sig-name (car in-list)) t ht))
             (setq in-list (cdr in-list)))
           (nreverse out-list)))
        ;; Slower Fallback if no hash tables (pre Emacs 21.1/XEmacs 21.4)
        (t
         (let (out-list)
           (while in-list
             (if (and (assoc (verilog-sig-name (car in-list)) not-list)
                      (not (assoc (verilog-sig-name (car in-list)) out-list)))
                 (setq out-list (cons (car in-list) out-list)))
             (setq in-list (cdr in-list)))
           (nreverse out-list)))))
;;(verilog-signals-in '(("A" "") ("B" "") ("DEL" "[2:3]")) '(("DEL" "") ("C" "")))

(defun verilog-signals-not-in (in-list not-list)
  "Return list of signals in IN-LIST that aren't also in NOT-LIST.
Also remove any duplicates in IN-LIST.
Signals must be in standard (base vector) form."
  ;; This function is hot, so implemented as O(1)
  (cond ((eval-when-compile (fboundp 'make-hash-table))
         (let ((ht (make-hash-table :test 'equal :rehash-size 4.0))
               out-list)
           (while not-list
             (puthash (car (car not-list)) t ht)
             (setq not-list (cdr not-list)))
           (while in-list
             (when (not (gethash (verilog-sig-name (car in-list)) ht))
               (setq out-list (cons (car in-list) out-list))
               (puthash (verilog-sig-name (car in-list)) t ht))
             (setq in-list (cdr in-list)))
           (nreverse out-list)))
        ;; Slower Fallback if no hash tables (pre Emacs 21.1/XEmacs 21.4)
        (t
         (let (out-list)
           (while in-list
             (if (and (not (assoc (verilog-sig-name (car in-list)) not-list))
                      (not (assoc (verilog-sig-name (car in-list)) out-list)))
                 (setq out-list (cons (car in-list) out-list)))
             (setq in-list (cdr in-list)))
           (nreverse out-list)))))
;;(verilog-signals-not-in '(("A" "") ("B" "") ("DEL" "[2:3]")) '(("DEL" "") ("EXT" "")))

(defun verilog-signals-not-in-struct (in-list not-list)
  "Return list of signals in IN-LIST that aren't also in NOT-LIST.
Also remove any duplicates in IN-LIST.
Any structure in not-list will remove all members in in-list.
Signals must be in standard (base vector) form."
  (cond ((eval-when-compile (fboundp 'make-hash-table))
         (let ((ht (make-hash-table :test 'equal :rehash-size 4.0))
               out-list addit nm)
           (while not-list
             (puthash (car (car not-list)) t ht)
             (setq not-list (cdr not-list)))
           (while in-list
             (setq nm (verilog-sig-name (car in-list)))
             (when (not (gethash nm ht))
               (setq addit t)
               (while (string-match "^\\([^\\].*\\)\\.[^.]+$" nm)
                 (setq nm (match-string 1 nm))
                 (setq addit (and addit
                                  (not (gethash nm ht)))))
               (when addit
                 (setq out-list (cons (car in-list) out-list))
                 (puthash (verilog-sig-name (car in-list)) t ht)))
             (setq in-list (cdr in-list)))
           (nreverse out-list)))
        ;; Slower Fallback if no hash tables (pre Emacs 21.1/XEmacs 21.4)
        (t
         (let (out-list addit nm)
           (while in-list
             (setq nm (verilog-sig-name (car in-list)))
             (when (and (not (assoc nm not-list))
                        (not (assoc nm out-list)))
               (setq addit t)
               (while (string-match "^\\([^\\].*\\)\\.[^.]+$" nm)
                 (setq nm (match-string 1 nm))
                 (setq addit (and addit
                                  (not (assoc nm not-list)))))
               (when addit
                 (setq out-list (cons (car in-list) out-list))))
             (setq in-list (cdr in-list)))
           (nreverse out-list)))))
;;(verilog-signals-not-in-struct '(("A" "") ("B" "") ("DEL.SUB.A" "[2:3]")) '(("DEL.SUB" "") ("EXT" "")))

(defun verilog-signals-memory (in-list)
  "Return list of signals in IN-LIST that are memorized (multidimensional)."
  (let (out-list)
    (while in-list
      (if (nth 3 (car in-list))
          (setq out-list (cons (car in-list) out-list)))
      (setq in-list (cdr in-list)))
    out-list))
;;(verilog-signals-memory '(("A" nil nil "[3:0]")) '(("B" nil nil nil)))

(defun verilog-signals-sort-compare (a b)
  "Compare signal A and B for sorting."
  (string< (verilog-sig-name a) (verilog-sig-name b)))

(defun verilog-signals-not-params (in-list)
  "Return list of signals in IN-LIST that aren't parameters or numeric constants."
  (let (out-list)
    (while in-list
      ;; Namespace intentionally short for AUTOs and compatibility
      (unless (boundp (intern (concat "vh-" (verilog-sig-name (car in-list)))))
        (setq out-list (cons (car in-list) out-list)))
      (setq in-list (cdr in-list)))
    (nreverse out-list)))

(defun verilog-signals-with (func in-list)
  "Return list of signals where FUNC is true executed on each signal in IN-LIST."
  (let (out-list)
    (while in-list
      (when (funcall func (car in-list))
        (setq out-list (cons (car in-list) out-list)))
      (setq in-list (cdr in-list)))
    (nreverse out-list)))

(defun verilog-signals-combine-bus (in-list)
  "Return a list of signals in IN-LIST, with buses combined.
Duplicate signals are also removed.  For example A[2] and A[1] become A[2:1]."
  (let (combo
        buswarn
        out-list
        sig highbit lowbit		; Temp information about current signal
        sv-name sv-highbit sv-lowbit	; Details about signal we are forming
        sv-comment sv-memory sv-enum sv-signed sv-type sv-multidim sv-busstring
        sv-modport
        bus)
    ;; Shove signals so duplicated signals will be adjacent
    (setq in-list (sort in-list `verilog-signals-sort-compare))
    (while in-list
      (setq sig (car in-list))
      ;; No current signal; form from existing details
      (unless sv-name
        (setq sv-name    (verilog-sig-name sig)
              sv-highbit nil
              sv-busstring nil
              sv-comment (verilog-sig-comment sig)
              sv-memory  (verilog-sig-memory sig)
              sv-enum    (verilog-sig-enum sig)
              sv-signed  (verilog-sig-signed sig)
              sv-type    (verilog-sig-type sig)
              sv-multidim (verilog-sig-multidim sig)
              sv-modport  (verilog-sig-modport sig)
              combo ""
              buswarn ""))
      ;; Extract bus details
      (setq bus (verilog-sig-bits sig))
      (setq bus (and bus (verilog-simplify-range-expression bus)))
      (cond ((and bus
                  (or (and (string-match "^\\[\\([0-9]+\\):\\([0-9]+\\)\\]$" bus)
                           (setq highbit (string-to-number (match-string 1 bus))
                                 lowbit  (string-to-number
                                          (match-string 2 bus))))
                      (and (string-match "^\\[\\([0-9]+\\)\\]$" bus)
                           (setq highbit (string-to-number (match-string 1 bus))
                                 lowbit  highbit))))
             ;; Combine bits in bus
             (if sv-highbit
                 (setq sv-highbit (max highbit sv-highbit)
                       sv-lowbit  (min lowbit  sv-lowbit))
               (setq sv-highbit highbit
                     sv-lowbit  lowbit)))
            (bus
             ;; String, probably something like `preproc:0
             (setq sv-busstring bus)))
      ;; Peek ahead to next signal
      (setq in-list (cdr in-list))
      (setq sig (car in-list))
      (cond ((and sig (equal sv-name (verilog-sig-name sig)))
             ;; Combine with this signal
             (when (and sv-busstring
                        (not (equal sv-busstring (verilog-sig-bits sig))))
               (when nil  ; Debugging
                 (message (concat "Warning, can't merge into single bus `%s%s'"
                                  ", the AUTOs may be wrong")
                          sv-name bus))
               (setq buswarn ", Couldn't Merge"))
             (if (verilog-sig-comment sig) (setq combo ", ..."))
             (setq sv-memory (or sv-memory (verilog-sig-memory sig))
                   sv-enum   (or sv-enum   (verilog-sig-enum sig))
                   sv-signed (or sv-signed (verilog-sig-signed sig))
                   sv-type   (or sv-type   (verilog-sig-type sig))
                   sv-multidim (or sv-multidim (verilog-sig-multidim sig))
                   sv-modport  (or sv-modport  (verilog-sig-modport sig))))
            ;; Doesn't match next signal, add to queue, zero in prep for next
            ;; Note sig may also be nil for the last signal in the list
            (t
             (setq out-list
                   (cons (verilog-sig-new
                          sv-name
                          (or sv-busstring
                              (if sv-highbit
                                  (concat "[" (int-to-string sv-highbit) ":"
                                          (int-to-string sv-lowbit) "]")))
                          (concat sv-comment combo buswarn)
                          sv-memory sv-enum sv-signed sv-type sv-multidim sv-modport)
                         out-list)
                   sv-name nil))))
    ;;
    out-list))

;;
;; Dumping
;;

(defun verilog-decls-princ (decls &optional header prefix)
  "For debug, dump the `verilog-read-decls' structure DECLS.
Use optional HEADER and PREFIX."
  (when decls
    (if header (princ header))
    (setq prefix (or prefix ""))
    (verilog-signals-princ (verilog-decls-get-outputs decls)
                           (concat prefix "Outputs:\n") (concat prefix "  "))
    (verilog-signals-princ (verilog-decls-get-inouts decls)
                           (concat prefix "Inout:\n") (concat prefix "  "))
    (verilog-signals-princ (verilog-decls-get-inputs decls)
                           (concat prefix "Inputs:\n") (concat prefix "  "))
    (verilog-signals-princ (verilog-decls-get-vars decls)
                           (concat prefix "Vars:\n") (concat prefix "  "))
    (verilog-signals-princ (verilog-decls-get-assigns decls)
                           (concat prefix "Assigns:\n") (concat prefix "  "))
    (verilog-signals-princ (verilog-decls-get-consts decls)
                           (concat prefix "Consts:\n") (concat prefix "  "))
    (verilog-signals-princ (verilog-decls-get-gparams decls)
                           (concat prefix "Gparams:\n") (concat prefix "  "))
    (verilog-signals-princ (verilog-decls-get-interfaces decls)
                           (concat prefix "Interfaces:\n") (concat prefix "  "))
    (verilog-modport-princ (verilog-decls-get-modports decls)
                           (concat prefix "Modports:\n") (concat prefix "  "))
    (princ "\n")))

(defun verilog-signals-princ (signals &optional header prefix)
  "For debug, dump internal SIGNALS structures, with HEADER and PREFIX."
  (when signals
    (if header (princ header))
    (while signals
      (let ((sig (car signals)))
        (setq signals (cdr signals))
        (princ prefix)
        (princ "\"") (princ (verilog-sig-name sig)) (princ "\"")
        (princ "  bits=") (princ (verilog-sig-bits sig))
        (princ "  cmt=") (princ (verilog-sig-comment sig))
        (princ "  mem=") (princ (verilog-sig-memory sig))
        (princ "  enum=") (princ (verilog-sig-enum sig))
        (princ "  sign=") (princ (verilog-sig-signed sig))
        (princ "  type=") (princ (verilog-sig-type sig))
        (princ "  dim=") (princ (verilog-sig-multidim sig))
        (princ "  modp=") (princ (verilog-sig-modport sig))
        (princ "\n")))))

(defun verilog-modport-princ (modports &optional header prefix)
  "For debug, dump internal MODPORTS structures, with HEADER and PREFIX."
  (when modports
    (if header (princ header))
    (while modports
      (let ((sig (car modports)))
        (setq modports (cdr modports))
        (princ prefix)
        (princ "\"") (princ (verilog-modport-name sig)) (princ "\"")
        (princ "  clockings=") (princ (verilog-modport-clockings sig))
        (princ "\n")
        (verilog-decls-princ (verilog-modport-decls sig)
                             (concat prefix "  syms:\n")
                             (concat prefix "    "))))))

;;
;; Port/Wire/Etc Reading
;;

(defun verilog-read-inst-backward-name ()
  "Move point back to beginning of inst-name."
  (verilog-backward-open-paren)
  (let (done)
    (while (not done)
      (verilog-re-search-backward-quick "\\()\\|\\b[a-zA-Z0-9`_$]\\|\\]\\)" nil nil)  ; ] isn't word boundary
      (cond ((looking-at ")")
             (verilog-backward-open-paren))
            (t (setq done t)))))
  (while (looking-at "\\]")
    (verilog-backward-open-bracket)
    (verilog-re-search-backward-quick "\\(\\b[a-zA-Z0-9`_$]\\|\\]\\)" nil nil))
  (skip-chars-backward "a-zA-Z0-9`_$"))

(defun verilog-read-inst-module-matcher ()
  "Set match data 0 with module_name when point is inside instantiation."
  (verilog-read-inst-backward-name)
  ;; Skip over instantiation name
  (verilog-re-search-backward-quick "\\(\\b[a-zA-Z0-9`_$]\\|)\\)" nil nil)  ; ) isn't word boundary
  ;; Check for parameterized instantiations
  (when (looking-at ")")
    (verilog-backward-open-paren)
    (verilog-re-search-backward-quick "\\b[a-zA-Z0-9`_$]" nil nil))
  (skip-chars-backward "a-zA-Z0-9'_$")
  ;; #1 is legal syntax for gate primitives
  (when (save-excursion
          (verilog-backward-syntactic-ws-quick)
          (eq ?# (char-before)))
    (verilog-re-search-backward-quick "\\b[a-zA-Z0-9`_$]" nil nil)
    (skip-chars-backward "a-zA-Z0-9'_$"))
  (looking-at "[a-zA-Z0-9`_$]+")
  ;; Important: don't use match string, this must work with Emacs 19 font-lock on
  (buffer-substring-no-properties (match-beginning 0) (match-end 0))
  ;; Caller assumes match-beginning/match-end is still set
  )

(defun verilog-read-inst-module ()
  "Return module_name when point is inside instantiation."
  (save-excursion
    (verilog-read-inst-module-matcher)))

(defun verilog-read-inst-name ()
  "Return instance_name when point is inside instantiation."
  (save-excursion
    (verilog-read-inst-backward-name)
    (looking-at "[a-zA-Z0-9`_$]+")
    ;; Important: don't use match string, this must work with Emacs 19 font-lock on
    (buffer-substring-no-properties (match-beginning 0) (match-end 0))))

(defun verilog-read-module-name ()
  "Return module name when after its ( or ;."
  (save-excursion
    (re-search-backward "[(;]")
    ;; Due to "module x import y (" we must search for declaration begin
    (verilog-re-search-backward-quick verilog-defun-re nil nil)
    (goto-char (match-end 0))
    (verilog-re-search-forward-quick "\\b[a-zA-Z0-9`_$]+" nil nil)
    ;; Important: don't use match string, this must work with Emacs 19 font-lock on
    (verilog-symbol-detick
     (buffer-substring-no-properties (match-beginning 0) (match-end 0)) t)))

(defun verilog-read-inst-param-value ()
  "Return list of parameters and values when point is inside instantiation."
  (save-excursion
    (verilog-read-inst-backward-name)
    ;; Skip over instantiation name
    (verilog-re-search-backward-quick "\\(\\b[a-zA-Z0-9`_$]\\|)\\)" nil nil)  ; ) isn't word boundary
    ;; If there are parameterized instantiations
    (when (looking-at ")")
      (let ((end-pt (point))
            params
            param-name paren-beg-pt param-value)
        (verilog-backward-open-paren)
        (while (verilog-re-search-forward-quick "\\." end-pt t)
          (verilog-re-search-forward-quick "\\([a-zA-Z0-9`_$]\\)" nil nil)
          (skip-chars-backward "a-zA-Z0-9'_$")
          (looking-at "[a-zA-Z0-9`_$]+")
          (setq param-name (buffer-substring-no-properties
                            (match-beginning 0) (match-end 0)))
          (verilog-re-search-forward-quick "(" nil nil)
          (setq paren-beg-pt (point))
          (verilog-forward-close-paren)
          (setq param-value (string-trim
                             (buffer-substring-no-properties
                              paren-beg-pt (1- (point)))))
          (setq params (cons (list param-name param-value) params)))
        params))))

(defun verilog-read-auto-params (num-param &optional max-param)
  "Return parameter list inside auto.
Optional NUM-PARAM and MAX-PARAM check for a specific number of parameters."
  (let ((olist))
    (save-excursion
      ;; /*AUTOPUNT("parameter", "parameter")*/
      (backward-sexp 1)
      (while (looking-at "(?\\s *\"\\([^\"]*\\)\"\\s *,?")
        (setq olist (cons (match-string 1) olist))
        (goto-char (match-end 0))))
    (or (eq nil num-param)
        (<= num-param (length olist))
        (error "%s: Expected %d parameters" (verilog-point-text) num-param))
    (if (eq max-param nil) (setq max-param num-param))
    (or (eq nil max-param)
        (>= max-param (length olist))
        (error "%s: Expected <= %d parameters" (verilog-point-text) max-param))
    (nreverse olist)))

(defun verilog-read-decls ()
  "Compute signal declaration information for the current module at point.
Return an array of [outputs inouts inputs wire reg assign const]."
  (let ((end-mod-point (or (verilog-get-end-of-defun) (point-max)))
        (functask 0) (paren 0) (sig-paren 0) (v2kargs-ok t)
        in-modport in-clocking in-ign-to-semi ptype ign-prop
        sigs-in sigs-out sigs-inout sigs-var sigs-assign sigs-const
        sigs-gparam sigs-intf sigs-modports
        vec expect-signal keywd last-keywd newsig rvalue enum io
        signed typedefed multidim
        modport
        varstack tmp)
    ;;(if dbg (setq dbg (concat dbg (format "\n\nverilog-read-decls START PT %s END %s\n" (point) end-mod-point))))
    (save-excursion
      (verilog-beg-of-defun-quick)
      (setq sigs-const (verilog-read-auto-constants (point) end-mod-point))
      (while (< (point) end-mod-point)
        ;;(if dbg (setq dbg (concat dbg (format "Pt %s  Vec %s   C%c Kwd'%s'\n" (point) vec (following-char) keywd))))
        (cond
         ((looking-at "//")
          (when (looking-at "[^\n]*\\(auto\\|synopsys\\)\\s +enum\\s +\\([a-zA-Z0-9_]+\\)")
            (setq enum (match-string 2)))
          (search-forward "\n"))
         ((looking-at "/\\*")
          (forward-char 2)
          (when (looking-at "[^\n]*\\(auto\\|synopsys\\)\\s +enum\\s +\\([a-zA-Z0-9_]+\\)")
            (setq enum (match-string 2)))
          (or (search-forward "*/")
              (error "%s: Unmatched /* */, at char %d" (verilog-point-text) (point))))
         ((looking-at "(\\*")
          ;; To advance past either "(*)" or "(* ... *)" don't forward past first *
          (forward-char 1)
          (or (search-forward "*)")
              (error "%s: Unmatched (* *), at char %d" (verilog-point-text) (point))))
         ((eq ?\" (following-char))
          (or (re-search-forward "[^\\]\"" nil t)  ; don't forward-char first, since we look for a non backslash first
              (error "%s: Unmatched quotes, at char %d" (verilog-point-text) (point))))
         ((eq ?\; (following-char))
          (cond (in-ign-to-semi  ; Such as inside a "import ...;" in a module header
                 (setq in-ign-to-semi nil  rvalue nil))
                ((and in-modport (not (eq in-modport t)))  ; end of a modport declaration
                 (verilog-modport-decls-set
                  in-modport
                  (verilog-decls-new sigs-out sigs-inout sigs-in
                                     nil nil nil nil nil nil))
                 ;; Pop from varstack to restore state to pre-clocking
                 (setq tmp (car varstack)
                       varstack (cdr varstack)
                       sigs-out (aref tmp 0)
                       sigs-inout (aref tmp 1)
                       sigs-in (aref tmp 2))
                 (setq vec nil  io nil  expect-signal nil  newsig nil  paren 0  rvalue nil
                       v2kargs-ok nil  in-modport nil  ign-prop nil))
                (t
                 (setq vec nil  io nil  expect-signal nil  newsig nil  paren 0  rvalue nil
                       v2kargs-ok nil  in-modport nil  ign-prop nil)))
          (forward-char 1))
         ((eq ?= (following-char))
          (setq rvalue t  newsig nil)
          (forward-char 1))
         ((and (eq ?, (following-char))
               (eq paren sig-paren))
          (setq rvalue nil)
          (forward-char 1))
         ;; ,'s can occur inside {} & funcs
         ((looking-at "[{(]")
          (setq paren (1+ paren))
          (forward-char 1))
         ((looking-at "[})]")
          (setq paren (1- paren))
          (forward-char 1)
          (when (< paren sig-paren)
            (setq expect-signal nil rvalue nil)))   ; ) that ends variables inside v2k arg list
         ((looking-at "\\s-*\\(\\[[^]]+\\]\\)")
          (goto-char (match-end 0))
          (cond (newsig	; Memory, not just width.  Patch last signal added's memory (nth 3)
                 (setcar (cdr (cdr (cdr newsig)))
                         (if (verilog-sig-memory newsig)
                             (concat (verilog-sig-memory newsig) (match-string 1))
                           (match-string-no-properties 1))))
                (vec  ; Multidimensional
                 (setq multidim (cons vec multidim))
                 (setq vec (verilog-string-replace-matches
                            "\\s-+" "" nil nil (match-string-no-properties 1))))
                (t  ; Bit width
                 (setq vec (verilog-string-replace-matches
                            "\\s-+" "" nil nil (match-string-no-properties 1))))))
         ;; Normal or escaped identifier -- note we remember the \ if escaped
         ((looking-at "\\s-*\\([a-zA-Z0-9`_$]+\\|\\\\[^ \t\n\f]+\\)")
          (goto-char (match-end 0))
          (setq last-keywd keywd
                keywd (match-string-no-properties 1))
          (when (string-match "^\\\\" (match-string 1))
            (setq keywd (concat keywd " ")))  ; Escaped ID needs space at end
          ;; Add any :: package names to same identifier
          ;; '*' here is for "import x::*"
          (while (looking-at "\\s-*::\\s-*\\(\\*\\|[a-zA-Z0-9`_$]+\\|\\\\[^ \t\n\f]+\\)")
            (goto-char (match-end 0))
            (setq keywd (concat keywd "::" (match-string 1)))
            (when (string-match "^\\\\" (match-string 1))
              (setq keywd (concat keywd " "))))  ; Escaped ID needs space at end
          (cond ((equal keywd "input")
                 (setq vec nil        enum nil      rvalue nil  newsig nil  signed nil
                       typedefed nil  multidim nil  ptype nil   modport nil
                       expect-signal 'sigs-in       io t        sig-paren paren))
                ((equal keywd "output")
                 (setq vec nil        enum nil      rvalue nil  newsig nil  signed nil
                       typedefed nil  multidim nil  ptype nil   modport nil
                       expect-signal 'sigs-out      io t        sig-paren paren))
                ((equal keywd "inout")
                 (setq vec nil        enum nil      rvalue nil  newsig nil  signed nil
                       typedefed nil  multidim nil  ptype nil   modport nil
                       expect-signal 'sigs-inout    io t        sig-paren paren))
                ((equal keywd "parameter")
                 (setq vec nil        enum nil      rvalue nil  signed nil
                       typedefed nil  multidim nil  ptype nil   modport nil
                       expect-signal 'sigs-gparam   io t        sig-paren paren))
                ((member keywd '("wire" "reg"  ; Fast
                                 ;; net_type
                                 "tri" "tri0" "tri1" "triand" "trior" "trireg"
                                 "uwire" "wand" "wor"
                                 ;; integer_atom_type
                                 "byte" "shortint" "int" "longint" "integer" "time"
                                 "supply0" "supply1"
                                 ;; integer_vector_type - "reg" above
                                 "bit" "logic"
                                 ;; non_integer_type
                                 "shortreal" "real" "realtime"
                                 ;; data_type
                                 "string" "event" "chandle"))
                 (cond (io
                        (setq typedefed
                              (if typedefed (concat typedefed " " keywd) keywd)))
                       (t (setq vec nil  enum nil  rvalue nil  signed nil
                                typedefed nil  multidim nil  sig-paren paren
                                expect-signal 'sigs-var  modport nil))))
                ((equal keywd "assign")
                 (setq vec nil        enum nil        rvalue nil  signed nil
                       typedefed nil  multidim nil    ptype nil   modport nil
                       expect-signal 'sigs-assign     sig-paren paren))
                ((member keywd '("localparam" "genvar"))
                 (setq vec nil        enum nil      rvalue nil  signed nil
                       typedefed nil  multidim nil  ptype nil   modport nil
                       expect-signal 'sigs-const    sig-paren paren))
                ((member keywd '("signed" "unsigned"))
                 (setq signed keywd))
                ((member keywd '("assert" "assume" "cover" "expect" "restrict"))
                 (setq ign-prop t))
                ((member keywd '("class" "covergroup" "function"
                                 "property" "randsequence" "sequence" "task"))
                 (unless ign-prop
                   (setq functask (1+ functask))))
                ((member keywd '("endclass" "endgroup" "endfunction"
                                 "endproperty" "endsequence" "endtask"))
                 (setq functask (1- functask)))
                ((equal keywd "modport")
                 (setq in-modport t))
                ((and (equal keywd "clocking")
                      (not (equal last-keywd "default")))
                 (setq in-clocking t))
                ((equal keywd "import")
                 (when v2kargs-ok  ; import in module header, not a modport import
                   (setq in-ign-to-semi t  rvalue t)))
                ((equal keywd "type")
                 (setq ptype t))
                ((equal keywd "var"))
                ;; Ifdef?  Ignore name of define
                ((member keywd '("`ifdef" "`ifndef" "`elsif"))
                 (setq rvalue t))
                ;; Type?
                ((unless ptype
                   (verilog-typedef-name-p keywd))
                 (cond (io
                        (setq typedefed
                              (if typedefed (concat typedefed " " keywd) keywd)))
                       (t (setq vec nil  enum nil  rvalue nil  signed nil
                                typedefed keywd  ; Have a type
                                multidim nil  sig-paren paren
                                expect-signal 'sigs-var  modport nil))))
                ;; Interface with optional modport in v2k arglist?
                ;; Skip over parsing modport, and take the interface name as the type
                ((and v2kargs-ok
                      (eq paren 1)
                      (not rvalue)
                      (or (looking-at "\\s-*#")
                          (looking-at "\\s-*\\(\\.\\(\\s-*[a-zA-Z`_$][a-zA-Z0-9`_$]*\\)\\|\\)\\s-*[a-zA-Z`_$][a-zA-Z0-9`_$]*")))
                 (when (match-end 2) (goto-char (match-end 2)))
                 (setq vec nil          enum nil       rvalue nil  signed nil
                       typedefed keywd  multidim nil   ptype nil   modport (match-string 2)
                       newsig nil    sig-paren paren
                       expect-signal 'sigs-intf  io t  ))
                ;; Ignore dotted LHS assignments: "assign foo.bar = z;"
                ((looking-at "\\s-*\\.")
                 (goto-char (match-end 0))
                 (when (not rvalue)
                   (setq expect-signal nil)))
                ;; "modport <keywd>"
                ((and (eq in-modport t)
                      (not (member keywd verilog-keywords)))
                 (setq in-modport (verilog-modport-new keywd nil nil))
                 (setq sigs-modports (cons in-modport sigs-modports))
                 ;; Push old sig values to stack and point to new signal list
                 (setq varstack (cons (vector sigs-out sigs-inout sigs-in)
                                      varstack))
                 (setq sigs-in nil  sigs-inout nil  sigs-out nil))
                ;; "modport x (clocking <keywd>)"
                ((and in-modport in-clocking)
                 (verilog-modport-clockings-add in-modport keywd)
                 (setq in-clocking nil))
                ;; endclocking
                ((and in-clocking
                      (equal keywd "endclocking"))
                 (unless (eq in-clocking t)
                   (verilog-modport-decls-set
                    in-clocking
                    (verilog-decls-new sigs-out sigs-inout sigs-in
                                       nil nil nil nil nil nil))
                   ;; Pop from varstack to restore state to pre-clocking
                   (setq tmp (car varstack)
                         varstack (cdr varstack)
                         sigs-out (aref tmp 0)
                         sigs-inout (aref tmp 1)
                         sigs-in (aref tmp 2)))
                 (setq in-clocking nil))
                ;; "clocking <keywd>"
                ((and (eq in-clocking t)
                      (not (member keywd verilog-keywords)))
                 (setq in-clocking (verilog-modport-new keywd nil nil))
                 (setq sigs-modports (cons in-clocking sigs-modports))
                 ;; Push old sig values to stack and point to new signal list
                 (setq varstack (cons (vector sigs-out sigs-inout sigs-in)
                                      varstack))
                 (setq sigs-in nil  sigs-inout nil  sigs-out nil))
                ;; New signal, maybe?
                ((and expect-signal
                      (not rvalue)
                      (eq functask 0)
                      (not (member keywd verilog-keywords))
                      (or (not io) (eq paren sig-paren)))
                 ;; Add new signal to expect-signal's variable
                 ;;(if dbg (setq dbg (concat dbg (format "Pt %s  New sig %s'\n" (point) keywd))))
                 (setq newsig (verilog-sig-new keywd vec nil nil enum signed typedefed multidim modport))
                 (set expect-signal (cons newsig
                                          (symbol-value expect-signal))))))
         (t
          (forward-char 1)))
        (skip-syntax-forward " "))
      ;; Return arguments
      (setq tmp (verilog-decls-new (nreverse sigs-out)
                                   (nreverse sigs-inout)
                                   (nreverse sigs-in)
                                   (nreverse sigs-var)
                                   (nreverse sigs-modports)
                                   (nreverse sigs-assign)
                                   (nreverse sigs-const)
                                   (nreverse sigs-gparam)
                                   (nreverse sigs-intf)))
      ;;(if dbg (verilog-decls-princ tmp))
      tmp)))

(defvar verilog-read-sub-decls-in-interfaced nil
  "For `verilog-read-sub-decls', process next signal as under interfaced block.")

(defvar verilog-read-sub-decls-gate-ios nil
  "For `verilog-read-sub-decls', gate IO pins remaining, nil if non-primitive.")

(eval-when-compile
  ;; Prevent compile warnings; these are let's, not globals
  ;; Do not remove the eval-when-compile
  ;; - we want an error when we are debugging this code if they are refed.
  (defvar sigs-in)
  (defvar sigs-inout)
  (defvar sigs-intf)
  (defvar sigs-intfd)
  (defvar sigs-out)
  (defvar sigs-out-d)
  (defvar sigs-out-i)
  (defvar sigs-out-unk)
  (defvar sigs-temp)
  ;; These are known to be from other packages and may not be defined
  (defvar diff-command)
  ;; There are known to be from newer versions of Emacs
  (defvar create-lockfiles)
  (defvar which-func-modes))

(defun verilog-read-sub-decls-type (par-values portdata)
  "For `verilog-read-sub-decls-line', decode a signal type."
  (let* ((type (verilog-sig-type portdata))
         (pvassoc (assoc type par-values)))
    (cond ((member type '("wire" "reg")) nil)
          (pvassoc (nth 1 pvassoc))
          (t type))))

(defun verilog-read-sub-decls-sig (submoddecls par-values comment port sig vec multidim mem)
  "For `verilog-read-sub-decls-line', add a signal."
  ;; sig eq t to indicate .name syntax
  ;;(message "vrsds: %s(%S)" port sig)
  (let ((dotname (eq sig t))
        portdata)
    (when sig
      (setq port (verilog-symbol-detick-denumber port))
      (setq sig  (if dotname port (verilog-symbol-detick-denumber sig)))
      (if vec (setq vec  (verilog-symbol-detick-denumber vec)))
      (if multidim (setq multidim  (mapcar `verilog-symbol-detick-denumber multidim)))
      (if mem (setq mem (verilog-symbol-detick-denumber mem)))
      (unless (or (not sig)
                  (equal sig ""))  ; Ignore .foo(1'b1) assignments
        (cond ((or (setq portdata (assoc port (verilog-decls-get-inouts submoddecls)))
                   (equal "inout" verilog-read-sub-decls-gate-ios))
               (setq sigs-inout
                     (cons (verilog-sig-new
                            sig
                            (if dotname (verilog-sig-bits portdata) vec)
                            (concat "To/From " comment)
                            mem
                            nil
                            (verilog-sig-signed portdata)
                            (verilog-read-sub-decls-type par-values portdata)
                            multidim nil)
                           sigs-inout)))
              ((or (setq portdata (assoc port (verilog-decls-get-outputs submoddecls)))
                   (equal "output" verilog-read-sub-decls-gate-ios))
               (setq sigs-out
                     (cons (verilog-sig-new
                            sig
                            (if dotname (verilog-sig-bits portdata) vec)
                            (concat "From " comment)
                            mem
                            nil
                            (verilog-sig-signed portdata)
                            ;; Though ok in SV, in V2K code, propagating the
                            ;;  "reg" in "output reg" upwards isn't legal.
                            ;; Also for backwards compatibility we don't propagate
                            ;;  "input wire" upwards.
                            ;; See also `verilog-signals-edit-wire-reg'.
                            (verilog-read-sub-decls-type par-values portdata)
                            multidim nil)
                           sigs-out)))
              ((or (setq portdata (assoc port (verilog-decls-get-inputs submoddecls)))
                   (equal "input" verilog-read-sub-decls-gate-ios))
               (setq sigs-in
                     (cons (verilog-sig-new
                            sig
                            (if dotname (verilog-sig-bits portdata) vec)
                            (concat "To " comment)
                            mem
                            nil
                            (verilog-sig-signed portdata)
                            (verilog-read-sub-decls-type par-values portdata)
                            multidim nil)
                           sigs-in)))
              ((setq portdata (assoc port (verilog-decls-get-interfaces submoddecls)))
               (setq sigs-intf
                     (cons (verilog-sig-new
                            sig
                            (if dotname (verilog-sig-bits portdata) vec)
                            (concat "To/From " comment)
                            mem
                            nil
                            (verilog-sig-signed portdata)
                            (verilog-read-sub-decls-type par-values portdata)
                            multidim nil)
                           sigs-intf)))
              ((setq portdata (and verilog-read-sub-decls-in-interfaced
                                   (assoc port (verilog-decls-get-vars submoddecls))))
               (setq sigs-intfd
                     (cons (verilog-sig-new
                            sig
                            (if dotname (verilog-sig-bits portdata) vec)
                            (concat "To/From " comment)
                            mem
                            nil
                            (verilog-sig-signed portdata)
                            (verilog-read-sub-decls-type par-values portdata)
                            multidim nil)
                           sigs-intf)))
              ;; (t  -- warning pin isn't defined.)   ; Leave for lint tool
              )))))

(defun verilog-read-sub-decls-expr (submoddecls par-values comment port expr)
  "For `verilog-read-sub-decls-line', parse a subexpression and add signals."
  ;;(message "vrsde: `%s'" expr)
  ;; Replace special /*[....]*/ comments inserted by verilog-auto-inst-port
  (setq expr (verilog-string-replace-matches "/\\*\\(\\.?\\[[^*]+\\]\\)\\*/" "\\1" nil nil expr))
  ;; Remove front operators
  (setq expr (verilog-string-replace-matches "^\\s-*[---+~!|&]+\\s-*" "" nil nil expr))
  ;;
  (cond
   ;; {..., a, b} requires us to recurse on a,b
   ;; To support {#{},{#{a,b}} we'll just split everything on [{},]
   ((string-match "^\\s-*{\\(.*\\)}\\s-*$" expr)
    (unless verilog-auto-ignore-concat
      (let ((mlst (split-string (match-string 1 expr) "[{},]"))
            mstr)
        (while (setq mstr (pop mlst))
          (verilog-read-sub-decls-expr submoddecls par-values comment port mstr)))))
   (t
    (let (sig vec multidim mem)
      ;; Remove leading reduction operators, etc
      (setq expr (verilog-string-replace-matches "^\\s-*[---+~!|&]+\\s-*" "" nil nil expr))
      ;;(message "vrsde-ptop: `%s'" expr)
      (cond  ; Find \signal. Final space is part of escaped signal name
       ((string-match "^\\s-*\\(\\\\[^ \t\n\f]+\\s-\\)" expr)
        ;;(message "vrsde-s: `%s'" (match-string 1 expr))
        (setq sig (match-string 1 expr)
              expr (substring expr (match-end 0))))
       ;; Find signal
       ((string-match "^\\s-*\\([a-zA-Z_][a-zA-Z_0-9]*\\)" expr)
        ;;(message "vrsde-s: `%s'" (match-string 1 expr))
        (setq sig (string-trim (match-string 1 expr))
              expr (substring expr (match-end 0)))))
      ;; Find [vector] or [multi][multi][multi][vector] or [vector[VEC2]]
      ;; Unfortunately Emacs regexps don't allow matching bracket searches, so just 2 deep.
      (while (string-match "^\\s-*\\(\\[\\([^][]+\\|\\[[^][]+\\]\\)*\\]\\)" expr)
        ;;(message "vrsde-v: `%s'" (match-string 1 expr))
        (when vec (setq multidim (cons vec multidim)))
        (setq vec (match-string 1 expr)
              expr (substring expr (match-end 0))))
      ;; Find .[unpacked_memory] or .[unpacked][unpacked]...
      (while (string-match "^\\s-*\\.\\(\\(\\[[^]]+\\]\\)+\\)" expr)
        ;;(message "vrsde-m: `%s'" (match-string 1 expr))
        (setq mem (match-string 1 expr)
              expr (substring expr (match-end 0))))
      ;; If found signal, and nothing unrecognized, add the signal
      ;;(message "vrsde-rem: `%s'" expr)
      (when (and sig (string-match "^\\s-*$" expr))
        (verilog-read-sub-decls-sig submoddecls par-values comment port sig vec multidim mem))))))

(defun verilog-read-sub-decls-line (submoddecls par-values comment)
  "For `verilog-read-sub-decls', read lines of port defs until none match.
Inserts the list of signals found, using submodi to look up each port."
  (let (done port)
    (save-excursion
      (forward-line 1)
      (while (not done)
        ;; Get port name
        (cond ((looking-at "\\s-*\\.\\s-*\\([a-zA-Z0-9`_$]*\\)\\s-*(\\s-*")
               (setq port (match-string-no-properties 1))
               (goto-char (match-end 0)))
              ;; .\escaped (
              ((looking-at "\\s-*\\.\\s-*\\(\\\\[^ \t\n\f]*\\)\\s-*(\\s-*")
               (setq port (concat (match-string-no-properties 1) " "))  ; escaped id's need trailing space
               (goto-char (match-end 0)))
              ;; .name
              ((looking-at "\\s-*\\.\\s-*\\([a-zA-Z0-9`_$]*\\)\\s-*[,)/]")
               (verilog-read-sub-decls-sig
                submoddecls par-values comment (match-string-no-properties 1) t ; sig==t for .name
                nil nil nil) ; vec multidim mem
               (setq port nil))
              ;; .\escaped_name
              ((looking-at "\\s-*\\.\\s-*\\(\\\\[^ \t\n\f]*\\)\\s-*[,)/]")
               (verilog-read-sub-decls-sig
                submoddecls par-values comment (concat (match-string-no-properties 1) " ") t ; sig==t for .name
                nil nil nil) ; vec multidim mem
               (setq port nil))
              ;; random
              ((looking-at "\\s-*\\.[^(]*(")
               (setq port nil)  ; skip this line
               (goto-char (match-end 0)))
              (t
               (setq port nil  done t)))  ; Unknown, ignore rest of line
        ;; Get signal name.  Point is at the first-non-space after (
        ;; We intentionally ignore (non-escaped) signals with .s in them
        ;; this prevents AUTOWIRE etc from noticing hierarchical sigs.
        (when port
          (cond ((looking-at "\\([a-zA-Z_][a-zA-Z_0-9]*\\)\\s-*)")
                 (verilog-read-sub-decls-sig
                  submoddecls par-values comment port
                  (string-trim (match-string-no-properties 1)) ; sig
                  nil nil nil)) ; vec multidim mem
                ;;
                ((looking-at "\\([a-zA-Z_][a-zA-Z_0-9]*\\)\\s-*\\(\\[[^][]+\\]\\)\\s-*)")
                 (verilog-read-sub-decls-sig
                  submoddecls par-values comment port
                  (string-trim (match-string-no-properties 1)) ; sig
                  (match-string-no-properties 2) nil nil)) ; vec multidim mem
                ;; Fastpath was above looking-at's.
                ;; For something more complicated invoke a parser
                ((looking-at "[^)]+")
                 (verilog-read-sub-decls-expr
                  submoddecls par-values comment port
                  (buffer-substring-no-properties
                   (point) (1- (progn (search-backward "(") ; start at (
                                      (verilog-forward-sexp-ign-cmt 1)
                                      (point)))))))) ; expr
        ;;
        (forward-line 1)))))
;;(verilog-read-sub-decls-line (verilog-decls-new nil nil nil nil nil nil nil nil nil) nil "Cmt")

(defun verilog-read-sub-decls-gate (submoddecls par-values comment submod end-inst-point)
  "For `verilog-read-sub-decls', read lines of UDP gate decl until none match.
Inserts the list of signals found."
  (save-excursion
    (let ((iolist (cdr (assoc submod verilog-gate-ios))))
      (while (< (point) end-inst-point)
        ;; Get primitive's signal name, as will never have port, and no trailing )
        (cond ((looking-at "//")
               (search-forward "\n"))
              ((looking-at "/\\*")
               (or (search-forward "*/")
                   (error "%s: Unmatched /* */, at char %d" (verilog-point-text) (point))))
              ((looking-at "(\\*")
               ;; To advance past either "(*)" or "(* ... *)" don't forward past first *
               (forward-char 1)
               (or (search-forward "*)")
                   (error "%s: Unmatched (* *), at char %d" (verilog-point-text) (point))))
              ;; On pins, parse and advance to next pin
              ;; Looking at pin, but *not* an // Output comment, or ) to end the inst
              ((looking-at "\\s-*[a-zA-Z0-9`_$({}\\\\][^,]*")
               (goto-char (match-end 0))
               (setq verilog-read-sub-decls-gate-ios (or (car iolist) "input")
                     iolist (cdr iolist))
               (verilog-read-sub-decls-expr
                submoddecls par-values comment "primitive_port"
                (match-string 0)))
              (t
               (forward-char 1)
               (skip-syntax-forward " ")))))))

(defun verilog-read-sub-decls ()
  "Internally parse signals going to modules under this module.
Return an array of [ outputs inouts inputs ] signals for modules that are
instantiated in this module.  For example if declare A A (.B(SIG)) and SIG
is an output, then SIG will be included in the list.

This only works on instantiations created with /*AUTOINST*/ converted by
\\[verilog-auto-inst].  Otherwise, it would have to read in the whole
component library to determine connectivity of the design.

One work around for this problem is to manually create // Inputs and //
Outputs comments above subcell signals, for example:

  module ModuleName (
      // Outputs
      .out (out),
      // Inputs
      .in  (in));"
  (save-excursion
    (let ((end-mod-point (verilog-get-end-of-defun))
          st-point end-inst-point par-values
          ;; below 3 modified by verilog-read-sub-decls-line
          sigs-out sigs-inout sigs-in sigs-intf sigs-intfd)
      (verilog-beg-of-defun-quick)
      (while (verilog-re-search-forward-quick "\\(/\\*AUTOINST\\*/\\|\\.\\*\\)" end-mod-point t)
        (save-excursion
          (goto-char (match-beginning 0))
          (setq par-values (and verilog-auto-inst-param-value
                                verilog-auto-inst-param-value-type
                                (verilog-read-inst-param-value)))
          (unless (verilog-inside-comment-or-string-p)
            ;; Attempt to snarf a comment
            (let* ((submod (verilog-read-inst-module))
                   (inst (verilog-read-inst-name))
                   (subprim (member submod verilog-gate-keywords))
                   (comment (concat inst " of " submod ".v"))
                   submodi submoddecls)
              (cond
               (subprim
                (setq submodi `primitive
                      submoddecls (verilog-decls-new nil nil nil nil nil nil nil nil nil)
                      comment (concat inst " of " submod))
                (verilog-backward-open-paren)
                (setq end-inst-point (save-excursion (verilog-forward-sexp-ign-cmt 1)
                                                     (point))
                      st-point (point))
                (forward-char 1)
                (verilog-read-sub-decls-gate submoddecls par-values comment submod end-inst-point))
               ;; Non-primitive
               (t
                (when (setq submodi (verilog-modi-lookup submod t))
                  (setq submoddecls (verilog-modi-get-decls submodi)
                        verilog-read-sub-decls-gate-ios nil)
                  (verilog-backward-open-paren)
                  (setq end-inst-point (save-excursion (verilog-forward-sexp-ign-cmt 1)
                                                       (point))
                        st-point (point))
                  ;; This could have used a list created by verilog-auto-inst
                  ;; However I want it to be runnable even on user's manually added signals
                  (let ((verilog-read-sub-decls-in-interfaced t))
                    (while (re-search-forward "\\s *(?\\s *// Interfaced" end-inst-point t)
                      (verilog-read-sub-decls-line submoddecls par-values comment)))  ; Modifies sigs-ifd
                  (goto-char st-point)
                  (while (re-search-forward "\\s *(?\\s *// Interfaces" end-inst-point t)
                    (verilog-read-sub-decls-line submoddecls par-values comment))  ; Modifies sigs-out
                  (goto-char st-point)
                  (while (re-search-forward "\\s *(?\\s *// Outputs" end-inst-point t)
                    (verilog-read-sub-decls-line submoddecls par-values comment))  ; Modifies sigs-out
                  (goto-char st-point)
                  (while (re-search-forward "\\s *(?\\s *// Inouts" end-inst-point t)
                    (verilog-read-sub-decls-line submoddecls par-values comment))  ; Modifies sigs-inout
                  (goto-char st-point)
                  (while (re-search-forward "\\s *(?\\s *// Inputs" end-inst-point t)
                    (verilog-read-sub-decls-line submoddecls par-values comment))  ; Modifies sigs-in
                  )))))))
      ;; Combine duplicate bits
      ;;(setq rr (vector sigs-out sigs-inout sigs-in))
      (verilog-subdecls-new
       (verilog-signals-combine-bus (nreverse sigs-out))
       (verilog-signals-combine-bus (nreverse sigs-inout))
       (verilog-signals-combine-bus (nreverse sigs-in))
       (verilog-signals-combine-bus (nreverse sigs-intf))
       (verilog-signals-combine-bus (nreverse sigs-intfd))))))

(defun verilog-read-inst-pins ()
  "Return an array of [ pins ] for the current instantiation at point.
For example if declare A A (.B(SIG)) then B will be included in the list."
  (save-excursion
    (let ((end-mod-point (point))  ; presume at /*AUTOINST*/ point
          pins pin)
      (verilog-backward-open-paren)
      (while (re-search-forward "\\.\\([^(,) \t\n\f]*\\)\\s-*" end-mod-point t)
        (setq pin (match-string 1))
        (unless (verilog-inside-comment-or-string-p)
          (setq pins (cons (list pin) pins))
          (when (looking-at "(")
            (verilog-forward-sexp-ign-cmt 1))))
      (vector pins))))

(defun verilog-read-arg-pins ()
  "Return an array of [ pins ] for the current argument declaration at point."
  (save-excursion
    (let ((end-mod-point (point))  ; presume at /*AUTOARG*/ point
          pins pin)
      (verilog-backward-open-paren)
      (while (re-search-forward "\\([a-zA-Z0-9$_.%`]+\\)" end-mod-point t)
        (setq pin (match-string 1))
        (unless (verilog-inside-comment-or-string-p)
          (setq pins (cons (list pin) pins))))
      (vector pins))))

(defun verilog-read-auto-constants (beg end-mod-point)
  "Return a list of AUTO_CONSTANTs used in the region from BEG to END-MOD-POINT."
  ;; Insert new
  (save-excursion
    (let (sig-list tpl-end-pt)
      (goto-char beg)
      (while (re-search-forward "\\<AUTO_CONSTANT" end-mod-point t)
        (if (not (looking-at "\\s *("))
            (error "%s: Missing () after AUTO_CONSTANT" (verilog-point-text)))
        (search-forward "(" end-mod-point)
        (setq tpl-end-pt (save-excursion
                           (backward-char 1)
                           (verilog-forward-sexp-cmt 1)  ; Moves to paren that closes argdecl's
                           (backward-char 1)
                           (point)))
        (while (re-search-forward "\\s-*\\([\"a-zA-Z0-9$_.%`]+\\)\\s-*,*" tpl-end-pt t)
          (setq sig-list (cons (list (match-string 1) nil nil) sig-list))))
      sig-list)))

(defvar verilog-cache-has-lisp nil "True if any AUTO_LISP in buffer.")
(make-variable-buffer-local 'verilog-cache-has-lisp)

(defun verilog-read-auto-lisp-present ()
  "Set `verilog-cache-has-lisp' if any AUTO_LISP in this buffer."
  (save-excursion
    (goto-char (point-min))
    (setq verilog-cache-has-lisp (re-search-forward "\\<AUTO_LISP(" nil t))))

(defun verilog-read-auto-lisp (start end)
  "Look for and evaluate an AUTO_LISP between START and END.
Must call `verilog-read-auto-lisp-present' before this function."
  ;; This function is expensive for large buffers, so we cache if any AUTO_LISP exists
  (when verilog-cache-has-lisp
    (save-excursion
      (goto-char start)
      (while (re-search-forward "\\<AUTO_LISP(" end t)
        (backward-char)
        (let* ((beg-pt (prog1 (point)
                         (verilog-forward-sexp-cmt 1)))  ; Closing paren
               (end-pt (point))
               (verilog-in-hooks t))
          (eval-region beg-pt end-pt nil))))))

(defun verilog-read-always-signals-recurse
    (exit-keywd rvalue temp-next)
  "Recursive routine for parentheses/bracket matching.
EXIT-KEYWD is expression to stop at, nil if top level.
RVALUE is true if at right hand side of equal.
TEMP-NEXT is true to ignore next token, fake from inside case statement."
  (let* ((semi-rvalue (equal "endcase" exit-keywd))  ; true if after a ; we are looking for rvalue
         keywd last-keywd sig-tolk sig-last-tolk gotend got-sig got-list end-else-check
         ignore-next)
    ;;(if dbg (setq dbg (concat dbg (format "Recursion %S %S %S\n" exit-keywd rvalue temp-next))))
    (while (not (or (eobp) gotend))
      (cond
       ((looking-at "//")
        (search-forward "\n"))
       ((looking-at "/\\*")
        (or (search-forward "*/")
            (error "%s: Unmatched /* */, at char %d" (verilog-point-text) (point))))
       ((looking-at "(\\*")
        ;; To advance past either "(*)" or "(* ... *)" don't forward past first *
        (forward-char 1)
        (or (search-forward "*)")
            (error "%s: Unmatched (* *), at char %d" (verilog-point-text) (point))))
       (t (setq keywd (buffer-substring-no-properties
                       (point)
                       (save-excursion (when (eq 0 (skip-chars-forward "a-zA-Z0-9$_.%`"))
                                         (forward-char 1))
                                       (point)))
                sig-last-tolk sig-tolk
                sig-tolk nil)
          ;;(if dbg (setq dbg (concat dbg (format "\tPt=%S %S\trv=%S in=%S ee=%S gs=%S\n" (point) keywd rvalue ignore-next end-else-check got-sig))))
          (cond
           ((equal keywd "\"")
            (or (re-search-forward "[^\\]\"" nil t)
                (error "%s: Unmatched quotes, at char %d" (verilog-point-text) (point))))
           ;; else at top level loop, keep parsing
           ((and end-else-check (equal keywd "else"))
            ;;(if dbg (setq dbg (concat dbg (format "\tif-check-else %s\n" keywd))))
            ;; no forward movement, want to see else in lower loop
            (setq end-else-check nil))
           ;; End at top level loop
           ((and end-else-check (looking-at "[^ \t\n\f]"))
            ;;(if dbg (setq dbg (concat dbg (format "\tif-check-else-other %s\n" keywd))))
            (setq gotend t))
           ;; Final statement?
           ((and exit-keywd (and (or (equal keywd exit-keywd)
                                     (and (equal exit-keywd "'}")
                                          (equal keywd "}")))
                                 (not (looking-at "::"))))
            (setq gotend t)
            (forward-char (length keywd)))
           ;; Standard tokens...
           ((equal keywd ";")
            (setq ignore-next nil  rvalue semi-rvalue)
            ;; Final statement at top level loop?
            (when (not exit-keywd)
              ;;(if dbg (setq dbg (concat dbg (format "\ttop-end-check %s\n" keywd))))
              (setq end-else-check t))
            (forward-char 1))
           ((equal keywd "'")
            (cond ((looking-at "'[sS]?[hdxboHDXBO]?[ \t]*[0-9a-fA-F_xzXZ?]+")
                   (goto-char (match-end 0)))
                  ((looking-at "'{")
                   (forward-char 2)
                   (verilog-read-always-signals-recurse "'}" t nil))
                  (t
                   (forward-char 1))))
           ((equal keywd ":")  ; Case statement, begin/end label, x?y:z
            (cond ((looking-at "::")
                   (forward-char 1))  ; Another forward-char below
                  ((equal "endcase" exit-keywd)  ; case x: y=z; statement next
                   (setq ignore-next nil rvalue nil))
                  ((equal "?" exit-keywd)  ; x?y:z rvalue
                   )  ; NOP
                  ((equal "]" exit-keywd)  ; [x:y] rvalue
                   )  ; NOP
                  ((equal "'}" exit-keywd)  ; Pattern assignment
                   )  ; NOP
                  (got-sig  ; label: statement
                   (setq ignore-next nil rvalue semi-rvalue got-sig nil))
                  ((not rvalue)  ; begin label
                   (setq ignore-next t rvalue nil)))
            (forward-char 1))
           ((equal keywd "=")
            (when got-sig
              ;;(if dbg (setq dbg (concat dbg (format "\t\tequal got-sig=%S got-list=%s\n" got-sig got-list))))
              (set got-list (cons got-sig (symbol-value got-list)))
              (setq got-sig nil))
            (when (not rvalue)
              (if (eq (char-before) ?< )
                  (setq sigs-out-d (append sigs-out-d sigs-out-unk)
                        sigs-out-unk nil)
                (setq sigs-out-i (append sigs-out-i sigs-out-unk)
                      sigs-out-unk nil)))
            (setq ignore-next nil rvalue t)
            (forward-char 1))
           ((equal keywd "?")
            (forward-char 1)
            (verilog-read-always-signals-recurse ":" rvalue nil))
           ((equal keywd "[")
            (forward-char 1)
            (verilog-read-always-signals-recurse "]" t nil))
           ((equal keywd "(")
            (forward-char 1)
            (cond (sig-last-tolk  ; Function call; zap last signal
                   (setq got-sig nil)))
            (cond ((equal last-keywd "for")
                   ;; temp-next: Variables on LHS are lvalues, but generally we want
                   ;; to ignore them, assuming they are loop increments
                   (verilog-read-always-signals-recurse ";" nil t)
                   (verilog-read-always-signals-recurse ";" t nil)
                   (verilog-read-always-signals-recurse ")" nil nil))
                  (t (verilog-read-always-signals-recurse ")" t nil))))
           ((equal keywd "begin")
            (skip-syntax-forward "w_")
            (verilog-read-always-signals-recurse "end" nil nil)
            ;;(if dbg (setq dbg (concat dbg (format "\tgot-end %s\n" exit-keywd))))
            (setq ignore-next nil  rvalue semi-rvalue)
            (if (not exit-keywd) (setq end-else-check t)))
           ((member keywd '("case" "casex" "casez" "randcase"))
            (skip-syntax-forward "w_")
            (verilog-read-always-signals-recurse "endcase" t nil)
            (setq ignore-next nil  rvalue semi-rvalue)
            (if (not exit-keywd) (setq gotend t)))  ; top level begin/end
           ((string-match "^[$`a-zA-Z_]" keywd)  ; not exactly word constituent
            (cond ((member keywd '("`ifdef" "`ifndef" "`elsif"))
                   (setq ignore-next t))
                  ((or ignore-next
                       (member keywd verilog-keywords)
                       (string-match "^\\$" keywd))  ; PLI task
                   (setq ignore-next nil))
                  (t
                   (setq keywd (verilog-symbol-detick-denumber keywd))
                   (when got-sig
                     (set got-list (cons got-sig (symbol-value got-list)))
                     ;;(if dbg (setq dbg (concat dbg (format "\t\tgot-sig=%S got-list=%S\n" got-sig got-list))))
                     )
                   (setq got-list (cond (temp-next 'sigs-temp)
                                        (rvalue 'sigs-in)
                                        (t 'sigs-out-unk))
                         got-sig (if (or (not keywd)
                                         (assoc keywd (symbol-value got-list)))
                                     nil (list keywd nil nil))
                         temp-next nil
                         sig-tolk t)))
            (skip-chars-forward "a-zA-Z0-9$_.%`"))
           (t
            (forward-char 1)))
          ;; End of non-comment token
          (setq last-keywd keywd)))
      (skip-syntax-forward " "))
    ;; Append the final pending signal
    (when got-sig
      ;;(if dbg (setq dbg (concat dbg (format "\t\tfinal got-sig=%S got-list=%s\n" got-sig got-list))))
      (set got-list (cons got-sig (symbol-value got-list)))
      (setq got-sig nil))
    ;;(if dbg (setq dbg (concat dbg (format "ENDRecursion %s\n" exit-keywd))))
    ))

(defun verilog-read-always-signals ()
  "Parse always block at point and return list of (outputs inout inputs)."
  (save-excursion
    (let* (;(dbg "")
           sigs-out-d sigs-out-i sigs-out-unk sigs-temp sigs-in)
      (verilog-read-always-signals-recurse nil nil nil)
      (setq sigs-out-i (append sigs-out-i sigs-out-unk)
            sigs-out-unk nil)
      ;;(if dbg (with-current-buffer (get-buffer-create "*vl-dbg*") (delete-region (point-min) (point-max)) (insert dbg) (setq dbg "")))
      ;; Return what was found
      (verilog-alw-new sigs-out-d sigs-out-i sigs-temp sigs-in))))

(defun verilog-read-instants ()
  "Parse module at point and return list of ( ( file instance ) ... )."
  (verilog-beg-of-defun-quick)
  (let* ((end-mod-point (verilog-get-end-of-defun))
         (state nil)
         (instants-list nil))
    (save-excursion
      (while (< (point) end-mod-point)
        ;; Stay at level 0, no comments
        (while (progn
                 (setq state (parse-partial-sexp (point) end-mod-point 0 t nil))
                 (or (> (car state) 0)	; in parens
                     (nth 5 state)		; comment
                     ))
          (forward-line 1))
        (beginning-of-line)
        (if (looking-at "^\\s-*\\([a-zA-Z0-9`_$]+\\)\\s-+\\([a-zA-Z0-9`_$]+\\)\\s-*(")
            (let ((module (match-string 1))
                  (instant (match-string 2)))
              (if (not (member module verilog-keywords))
                  (setq instants-list (cons (list module instant) instants-list)))))
        (forward-line 1)))
    instants-list))


(defun verilog-read-auto-template-middle ()
  "With point in middle of an AUTO_TEMPLATE, parse it.
Returns REGEXP and list of ( (signal_name connection_name)... )."
  (save-excursion
    ;; Find beginning
    (let ((tpl-regexp "\\([0-9]+\\)")
          (lineno -1)  ; -1 to offset for the AUTO_TEMPLATE's newline
          (templateno 0)
          tpl-sig-list tpl-wild-list tpl-end-pt rep)
      ;; Parse "REGEXP"
      ;; We reserve @"..." for future lisp expressions that evaluate
      ;; once-per-AUTOINST
      (when (looking-at "\\s-*\"\\([^\"]*\\)\"")
        (setq tpl-regexp (match-string 1))
        (goto-char (match-end 0)))
      (search-forward "(")
      ;; Parse lines in the template
      (when (or verilog-auto-inst-template-numbers
                verilog-auto-template-warn-unused)
        (save-excursion
          (let ((pre-pt (point)))
            (goto-char (point-min))
            (while (search-forward "AUTO_TEMPLATE" pre-pt t)
              (setq templateno (1+ templateno)))
            (while (< (point) pre-pt)
              (forward-line 1)
              (setq lineno (1+ lineno))))))
      (setq tpl-end-pt (save-excursion
                         (backward-char 1)
                         (verilog-forward-sexp-cmt 1)  ; Moves to paren that closes argdecl's
                         (backward-char 1)
                         (point)))
      ;;
      (while (< (point) tpl-end-pt)
        (cond ((looking-at "\\s-*\\.\\([a-zA-Z0-9`_$]+\\)\\s-*(\\(.*\\))\\s-*\\(,\\|)\\s-*;\\)")
               (setq tpl-sig-list
                     (cons (list
                            (match-string-no-properties 1)
                            (match-string-no-properties 2)
                            templateno lineno)
                           tpl-sig-list))
               (goto-char (match-end 0)))
              ;; Regexp form??
              ((looking-at
                ;; Regexp bug in XEmacs disallows ][ inside [], and wants + last
                "\\s-*\\.\\(\\([a-zA-Z0-9`_$+@^.*?|---]\\|[][]\\|\\\\[()|]\\)+\\)\\s-*(\\(.*\\))\\s-*\\(,\\|)\\s-*;\\)")
               (setq rep (match-string-no-properties 3))
               (goto-char (match-end 0))
               (setq tpl-wild-list
                     (cons (list
                            (concat "^"
                                    (verilog-string-replace-matches "@" "\\\\([0-9]+\\\\)" nil nil
                                                                    (match-string 1))
                                    "$")
                            rep
                            templateno lineno)
                           tpl-wild-list)))
              ((looking-at "[ \t\f]+")
               (goto-char (match-end 0)))
              ((looking-at "\n")
               (setq lineno (1+ lineno))
               (goto-char (match-end 0)))
              ((looking-at "//")
               (search-forward "\n")
               (setq lineno (1+ lineno)))
              ((looking-at "/\\*")
               (forward-char 2)
               (or (search-forward "*/")
                   (error "%s: Unmatched /* */, at char %d" (verilog-point-text) (point))))
              (t
               (error "%s: AUTO_TEMPLATE parsing error: %s"
                      (verilog-point-text)
                      (progn (looking-at ".*$") (match-string 0))))))
      ;; Return
      (vector tpl-regexp
              (list tpl-sig-list tpl-wild-list)))))

(defun verilog-read-auto-template (module)
  "Look for an auto_template for the instantiation of the given MODULE.
If found returns `verilog-read-auto-template-inside' structure."
  (save-excursion
    ;; Find beginning
    (let ((pt (point)))
      ;; Note this search is expensive, as we hunt from mod-begin to point
      ;; for every instantiation.  Likewise in verilog-read-auto-lisp.
      ;; So, we look first for an exact string rather than a slow regexp.
      ;; Someday we may keep a cache of every template, but this would also
      ;; need to record the relative position of each AUTOINST, as multiple
      ;; templates exist for each module, and we're inserting lines.
      (cond ((or
              ;; See also regexp in `verilog-auto-template-lint'
              (verilog-re-search-backward-substr
               "AUTO_TEMPLATE"
               (concat "^\\s-*/?\\*?\\s-*" module "\\s-+AUTO_TEMPLATE") nil t)
              ;; Also try forward of this AUTOINST
              ;; This is for historical support; this isn't speced as working
              (progn
                (goto-char pt)
                (verilog-re-search-forward-substr
                 "AUTO_TEMPLATE"
                 (concat "^\\s-*/?\\*?\\s-*" module "\\s-+AUTO_TEMPLATE") nil t)))
             (goto-char (match-end 0))
             (verilog-read-auto-template-middle))
            ;; If no template found
            (t (vector "" nil))))))
;;(progn (find-file "auto-template.v") (verilog-read-auto-template "ptl_entry"))

(defvar verilog-auto-template-hits nil "Successful lookups with `verilog-read-auto-template-hit'.")
(make-variable-buffer-local 'verilog-auto-template-hits)

(defun verilog-read-auto-template-init ()
  "Initialize `verilog-read-auto-template'."
  (when (eval-when-compile (fboundp 'make-hash-table))  ; else feature not allowed
    (when verilog-auto-template-warn-unused
      (setq verilog-auto-template-hits
            (make-hash-table :test 'equal :rehash-size 4.0)))))

(defun verilog-read-auto-template-hit (tpl-ass)
  "Record that TPL-ASS template from `verilog-read-auto-template' was used."
  (when (eval-when-compile (fboundp 'make-hash-table))  ; else feature not allowed
    (when verilog-auto-template-warn-unused
      (unless verilog-auto-template-hits
        (verilog-read-auto-template-init))
      (puthash (vector (nth 2 tpl-ass) (nth 3 tpl-ass)) t
               verilog-auto-template-hits))))

(defun verilog-set-define (defname defvalue &optional buffer enumname)
  "Set the definition DEFNAME to the DEFVALUE in the given BUFFER.
Optionally associate it with the specified enumeration ENUMNAME."
  (with-current-buffer (or buffer (current-buffer))
    ;; Namespace intentionally short for AUTOs and compatibility
    (let ((mac (intern (concat "vh-" defname))))
      ;;(message "Define %s=%s" defname defvalue) (sleep-for 1)
      ;; Need to define to a constant if no value given
      (set (make-local-variable mac)
           (if (equal defvalue "") "1" defvalue)))
    (if enumname
        ;; Namespace intentionally short for AUTOs and compatibility
        (let ((enumvar (intern (concat "venum-" enumname))))
          ;;(message "Define %s=%s" defname defvalue) (sleep-for 1)
          (unless (boundp enumvar) (set enumvar nil))
          (add-to-list (make-local-variable enumvar) defname)))))

(defun verilog-read-defines (&optional filename recurse subcall)
  "Read \\=`defines and parameters for the current file, or optional FILENAME.
If the filename is provided, `verilog-library-flags' will be used to
resolve it.  If optional RECURSE is non-nil, recurse through \\=`includes.

Localparams must be simple assignments to constants, or have their own
\"localparam\" label rather than a list of localparams.  Thus:

    localparam X = 5, Y = 10;	// Ok
    localparam X = {1\\='b1, 2\\='h2};	// Ok
    localparam X = {1\\='b1, 2\\='h2}, Y = 10;	// Bad, make into 2 localparam lines

Defines must be simple text substitutions, one on a line, starting
at the beginning of the line.  Any ifdefs or multiline comments around the
define are ignored.

Defines are stored inside Emacs variables using the name
vh-{definename}.

Localparams define what symbols are constants so that AUTOSENSE
will not include them in sensitivity lists.  However any
parameters in the include file are not considered ports in the
including file, thus will not appear in AUTOINSTPARAM lists for a
parent module..

The file variables feature can be used to set defines that
`verilog-mode' can see; put at the *END* of your file something
like:

    // Local Variables:
    // vh-macro:\"macro_definition\"
    // End:

If macros are defined earlier in the same file and you want their values,
you can read them automatically with:

    // Local Variables:
    // verilog-auto-read-includes:t
    // End:

Or a more specific alternative example, which requires having
`enable-local-eval' non-nil:

    // Local Variables:
    // eval:(verilog-read-defines)
    // eval:(verilog-read-defines \"group_standard_includes.v\")
    // End:

Note these are only read when the file is first visited, you must use
\\[find-alternate-file] RET  to have these take effect after editing them!

If you want to disable the \"Process `eval' or hook local variables\"
warning message, you need to add to your init file:

    (setq enable-local-eval t)"
  (let ((origbuf (current-buffer)))
    (save-excursion
      (unless subcall (verilog-getopt-flags))
      (when filename
        (let ((fns (verilog-library-filenames filename (buffer-file-name))))
          (if fns
              (set-buffer (find-file-noselect (car fns)))
            (error "%s: Can't find verilog-read-defines file: %s"
                   (verilog-point-text) filename))))
      (when recurse
        (goto-char (point-min))
        (while (re-search-forward "^\\s-*`include\\s-+\\([^ \t\n\f]+\\)" nil t)
          (let ((inc (verilog-substitute-include-name
                      (match-string-no-properties 1))))
            (unless (verilog-inside-comment-or-string-p)
              (verilog-read-defines inc recurse t)))))
      ;; Read `defines
      ;; note we don't use verilog-re... it's faster this way, and that
      ;; function has problems when comments are at the end of the define
      (goto-char (point-min))
      (while (re-search-forward "^\\s-*`define\\s-+\\([a-zA-Z0-9_$]+\\)\\s-+\\(.*\\)$" nil t)
        (let ((defname (match-string-no-properties 1))
              (defvalue (match-string-no-properties 2)))
          (unless (verilog-inside-comment-or-string-p (match-beginning 0))
            (setq defvalue (verilog-string-replace-matches "\\s-*/[/*].*$" "" nil nil defvalue))
            (verilog-set-define defname defvalue origbuf))))
      ;; Hack: Read parameters
      (goto-char (point-min))
      (while (re-search-forward
              "^\\s-*\\(parameter\\|localparam\\)\\(\\s-*\\[[^]]*\\]\\)?\\s-*" nil t)
        (let (enumname)
          ;; The primary way of getting defines is verilog-read-decls
          ;; However, that isn't called yet for included files, so we'll add another scheme
          (if (looking-at "[^\n]*\\(auto\\|synopsys\\)\\s +enum\\s +\\([a-zA-Z0-9_]+\\)")
              (setq enumname (match-string-no-properties 2)))
          (forward-comment 99999)
          (while (looking-at (concat "\\s-*,?\\s-*\\(?:/[/*].*?$\\)?\\s-*\\([a-zA-Z0-9_$]+\\)"
                                     "\\s-*=\\s-*\\([^;,]*\\),?\\s-*\\(/[/*].*?$\\)?\\s-*"))
            (unless (verilog-inside-comment-or-string-p (match-beginning 0))
              (verilog-set-define (match-string-no-properties 1)
                                  (match-string-no-properties 2) origbuf enumname))
            (goto-char (match-end 0))
            (forward-comment 99999)))))))

(defun verilog-read-includes ()
  "Read \\=`includes for the current file.
This will find all of the \\=`includes which are at the beginning of lines,
ignoring any ifdefs or multiline comments around them.
`verilog-read-defines' is then performed on the current and each included
file.

It is often useful put at the *END* of your file something like:

    // Local Variables:
    // verilog-auto-read-includes:t
    // End:

Or the equivalent longer version, which requires having
`enable-local-eval' non-nil:

    // Local Variables:
    // eval:(verilog-read-defines)
    // eval:(verilog-read-includes)
    // End:

Note includes are only read when the file is first visited, you must use
\\[find-alternate-file] RET  to have these take effect after editing them!

It is good to get in the habit of including all needed files in each .v
file that needs it, rather than waiting for compile time.  This will aid
this process, Verilint, and readability.  To prevent defining the same
variable over and over when many modules are compiled together, put a test
around the inside each include file:

foo.v (an include file):
  \\=`ifdef _FOO_V	// include if not already included
  \\=`else
  \\=`define _FOO_V
  ... contents of file
  \\=`endif // _FOO_V"
  ;;slow:  (verilog-read-defines nil t)
  (save-excursion
    (verilog-getopt-flags)
    (goto-char (point-min))
    (while (re-search-forward "^\\s-*`include\\s-+\\([^ \t\n\f]+\\)" nil t)
      (let ((inc (verilog-substitute-include-name (match-string 1))))
        (verilog-read-defines inc nil t)))))

(defun verilog-read-signals (&optional start end)
  "Return a simple list of all possible signals in the file.
Bounded by optional region from START to END.  Overly aggressive but fast.
Some macros and such are also found and included.  For dinotrace.el."
  (let (sigs-all keywd)
    (progn;save-excursion
      (goto-char (or start (point-min)))
      (setq end (or end (point-max)))
      (while (re-search-forward "[\"/a-zA-Z_.%`]" end t)
        (forward-char -1)
        (cond
         ((looking-at "//")
          (search-forward "\n"))
         ((looking-at "/\\*")
          (search-forward "*/"))
         ((looking-at "(\\*")
          (or (looking-at "(\\*\\s-*)")  ; It's an "always @ (*)"
              (search-forward "*)")))
         ((eq ?\" (following-char))
          (re-search-forward "[^\\]\""))  ; don't forward-char first, since we look for a non backslash first
         ((looking-at "\\s-*\\([a-zA-Z0-9$_.%`]+\\)")
          (goto-char (match-end 0))
          (setq keywd (match-string-no-properties 1))
          (or (member keywd verilog-keywords)
              (member keywd sigs-all)
              (setq sigs-all (cons keywd sigs-all))))
         (t (forward-char 1))))
      ;; Return list
      sigs-all)))

;;
;; Argument file parsing
;;

(defun verilog-getopt (arglist &optional default-dir)
  "Parse -f, -v etc arguments in ARGLIST list or string.
Use DEFAULT-DIR to anchor paths if non-nil."
  (unless (listp arglist) (setq arglist (list arglist)))
  (let ((space-args '())
        arg next-param)
    ;; Split on spaces, so users can pass whole command lines
    (while arglist
      (setq arg (car arglist)
            arglist (cdr arglist))
      (while (string-match "^\\([^ \t\n\f]+\\)[ \t\n\f]*\\(.*$\\)" arg)
        (setq space-args (append space-args
                                 (list (match-string-no-properties 1 arg))))
        (setq arg (match-string 2 arg))))
    ;; Parse arguments
    (while space-args
      (setq arg (car space-args)
            space-args (cdr space-args))
      (cond
       ;; Need another arg
       ((equal arg "-F")
        (setq next-param arg))
       ((equal arg "-f")
        (setq next-param arg))
       ((equal arg "-v")
        (setq next-param arg))
       ((equal arg "-y")
        (setq next-param arg))
       ;; +libext+(ext1)+(ext2)...
       ((string-match "^\\+libext\\+\\(.*\\)" arg)
        (setq arg (match-string 1 arg))
        (while (string-match "\\([^+]+\\)\\+?\\(.*\\)" arg)
          (verilog-add-list-unique `verilog-library-extensions
                                   (match-string 1 arg))
          (setq arg (match-string 2 arg))))
       ;;
       ((or (string-match "^-D\\([^+=]*\\)[+=]\\(.*\\)" arg)  ; -Ddefine=val
            (string-match "^-D\\([^+=]*\\)\\(\\)" arg)  ; -Ddefine
            (string-match "^\\+define\\([^+=]*\\)[+=]\\(.*\\)" arg)  ; +define+val
            (string-match "^\\+define\\([^+=]*\\)\\(\\)" arg))  ; +define+define
        (verilog-set-define (match-string 1 arg) (match-string 2 arg)))
       ;;
       ((or (string-match "^\\+incdir\\+\\(.*\\)" arg)  ; +incdir+dir
            (string-match "^-I\\(.*\\)" arg))   ; -Idir
        (verilog-add-list-unique `verilog-library-directories
                                 (substitute-in-file-name (match-string 1 arg))))
       ;; Ignore
       ((equal "+librescan" arg))
       ((string-match "^-U\\(.*\\)" arg))  ; -Udefine
       ;; Second parameters
       ((equal next-param "-F")
        (setq next-param nil)
        (verilog-getopt-file (verilog-substitute-file-name-path arg default-dir)
                             (file-name-directory (verilog-substitute-file-name-path arg default-dir))))
       ((equal next-param "-f")
        (setq next-param nil)
        (verilog-getopt-file (verilog-substitute-file-name-path arg default-dir) nil))
       ((equal next-param "-v")
        (setq next-param nil)
        (verilog-add-list-unique `verilog-library-files
                                 (verilog-substitute-file-name-path arg default-dir)))
       ((equal next-param "-y")
        (setq next-param nil)
        (verilog-add-list-unique `verilog-library-directories
                                 (verilog-substitute-file-name-path arg default-dir)))
       ;; Filename
       ((string-match "^[^-+]" arg)
        (verilog-add-list-unique `verilog-library-files
                                 (verilog-substitute-file-name-path arg default-dir)))
       ;; Default - ignore; no warning
       ))))
;;(verilog-getopt (list "+libext+.a+.b" "+incdir+foodir" "+define+a+aval" "-f" "otherf" "-v" "library" "-y" "dir"))

(defun verilog-getopt-file (filename &optional default-dir)
  "Read Verilog options from the specified FILENAME.
Use DEFAULT-DIR to anchor paths if non-nil."
  (save-excursion
    (let ((fns (verilog-library-filenames filename (buffer-file-name)))
          (orig-buffer (current-buffer))
          line)
      (if fns
          (set-buffer (find-file-noselect (car fns)))
        (error "%s: Can't find verilog-getopt-file -f file: %s"
               (verilog-point-text) filename))
      (goto-char (point-min))
      (while (not (eobp))
        (setq line (buffer-substring (point) (point-at-eol)))
        (forward-line 1)
        (when (string-match "//" line)
          (setq line (substring line 0 (match-beginning 0))))
        (with-current-buffer orig-buffer  ; Variables are buffer-local, so need right context.
          (verilog-getopt line default-dir))))))

(defun verilog-getopt-flags ()
  "Convert `verilog-library-flags' into standard library variables."
  ;; If the flags are local, then all the outputs should be local also
  (when (local-variable-p `verilog-library-flags (current-buffer))
    (mapc 'make-local-variable '(verilog-library-extensions
                                 verilog-library-directories
                                 verilog-library-files
                                 verilog-library-flags)))
  ;; Allow user to customize
  (verilog-run-hooks 'verilog-before-getopt-flags-hook)
  ;; Process arguments
  (verilog-getopt verilog-library-flags)
  ;; Allow user to customize
  (verilog-run-hooks 'verilog-getopt-flags-hook))

(defun verilog-substitute-file-name-path (filename default-dir)
  "Return FILENAME with environment variables substituted.
Use DEFAULT-DIR to anchor paths if non-nil."
  (if default-dir
      (expand-file-name (substitute-in-file-name filename) default-dir)
    (substitute-in-file-name filename)))

(defun verilog-substitute-include-name (filename)
  "Return FILENAME for include with define substituted."
  (setq filename (verilog-string-replace-matches "\"" "" nil nil filename))
  (verilog-string-replace-matches "\"" "" nil nil
                                  (verilog-symbol-detick filename t)))

(defun verilog-add-list-unique (varref object)
  "Append to VARREF list the given OBJECT,
unless it is already a member of the variable's list."
  (unless (member object (symbol-value varref))
    (set varref (append (symbol-value varref) (list object))))
  varref)
;;(progn (setq l '()) (verilog-add-list-unique `l "a") (verilog-add-list-unique `l "a") l)

(defun verilog-current-flags ()
  "Convert `verilog-library-flags' and similar variables to command line.
Used for __FLAGS__ in `verilog-expand-command'."
  (let ((cmd (mapconcat `concat verilog-library-flags " ")))
    (when (equal cmd "")
      (setq cmd (concat
                 "+libext+" (mapconcat `concat verilog-library-extensions "+")
                 (mapconcat (lambda (i) (concat " -y " i " +incdir+" i))
                            verilog-library-directories "")
                 (mapconcat (lambda (i) (concat " -v " i))
                            verilog-library-files ""))))
    cmd))
;;(verilog-current-flags)


;;; Cached directory support:
;;

(defvar verilog-dir-cache-preserving nil
  "If true, the directory cache is enabled, and file system changes are ignored.
See `verilog-dir-exists-p' and `verilog-dir-files'.")

;; If adding new cached variable, add also to verilog-preserve-dir-cache
(defvar verilog-dir-cache-list nil
  "Alist of (((Cwd Dirname) Results)...) for caching `verilog-dir-files'.")
(defvar verilog-dir-cache-lib-filenames nil
  "Cached data for `verilog-library-filenames'.")

(defmacro verilog-preserve-dir-cache (&rest body)
  "Execute the BODY forms, allowing directory cache preservation within BODY.
This means that changes inside BODY made to the file system will not be
seen by the `verilog-dir-files' and related functions."
  `(let ((verilog-dir-cache-preserving (current-buffer))
         verilog-dir-cache-list
         verilog-dir-cache-lib-filenames)
     (progn ,@body)))

(defun verilog-dir-files (dirname)
  "Return all filenames in the DIRNAME directory.
Relative paths depend on the `default-directory'.
Results are cached if inside `verilog-preserve-dir-cache'."
  (unless verilog-dir-cache-preserving
    (setq verilog-dir-cache-list nil))  ; Cache disabled
  ;; We don't use expand-file-name on the dirname to make key, as it's slow
  (let* ((cache-key (list dirname default-directory))
         (fass (assoc cache-key verilog-dir-cache-list))
         exp-dirname data)
    (cond (fass  ; Return data from cache hit
           (nth 1 fass))
          (t
           (setq exp-dirname (expand-file-name dirname)
                 data (and (file-directory-p exp-dirname)
                           (directory-files exp-dirname nil nil nil)))
           ;; Note we also encache nil for non-existing dirs.
           (setq verilog-dir-cache-list (cons (list cache-key data)
                                              verilog-dir-cache-list))
           data))))
;; Miss-and-hit test:
;;(verilog-preserve-dir-cache (prin1 (verilog-dir-files "."))
;; (prin1 (verilog-dir-files ".")) nil)

(defun verilog-dir-file-exists-p (filename)
  "Return true if FILENAME exists.
Like `file-exists-p' but results are cached if inside
`verilog-preserve-dir-cache'."
  (let* ((dirname (file-name-directory filename))
         ;; Correct for file-name-nondirectory returning same if no slash.
         (dirnamed (if (or (not dirname) (equal dirname filename))
                       default-directory dirname))
         (flist (verilog-dir-files dirnamed)))
    (and flist
         (member (file-name-nondirectory filename) flist)
         t)))
;;(verilog-dir-file-exists-p "verilog-mode.el")
;;(verilog-dir-file-exists-p "../verilog-mode/verilog-mode.el")


;;; Module name lookup:
;;

(defun verilog-module-inside-filename-p (module filename)
  "Return modi if MODULE is specified inside FILENAME, else nil.
Allows version control to check out the file if need be."
  (and (or (file-exists-p filename)
           (and (fboundp 'vc-backend)
                (vc-backend filename)))
       (let (modi type)
         (with-current-buffer (find-file-noselect filename)
           (save-excursion
             (goto-char (point-min))
             (while (and
                     ;; It may be tempting to look for verilog-defun-re,
                     ;; don't, it slows things down a lot!
                     (verilog-re-search-forward-quick "\\<\\(module\\|interface\\|program\\)\\>" nil t)
                     (setq type (match-string-no-properties 0))
                     (verilog-re-search-forward-quick "[(;]" nil t))
               (if (equal module (verilog-read-module-name))
                   (setq modi (verilog-modi-new module filename (point) type))))
             modi)))))

(defun verilog-is-number (symbol)
  "Return true if SYMBOL is number-like."
  (or (string-match "^[0-9 \t:]+$" symbol)
      (string-match "^[---]*[0-9]+$" symbol)
      (string-match "^[0-9 \t]+'s?[hdxbo][0-9a-fA-F_xz? \t]*$" symbol)))

(defun verilog-symbol-detick (symbol wing-it)
  "Return an expanded SYMBOL name without any defines.
If the variable vh-{symbol} is defined, return that value.
If undefined, and WING-IT, return just SYMBOL without the tick, else nil."
  (while (and symbol (string-match "^`" symbol))
    (setq symbol (substring symbol 1))
    (setq symbol
          ;; Namespace intentionally short for AUTOs and compatibility
          (if (boundp (intern (concat "vh-" symbol)))
              ;; Emacs has a bug where boundp on a buffer-local
              ;; variable in only one buffer returns t in another.
              ;; This can confuse, so check for nil.
              ;; Namespace intentionally short for AUTOs and compatibility
              (let ((val (eval (intern (concat "vh-" symbol)))))
                (if (eq val nil)
                    (if wing-it symbol nil)
                  val))
            (if wing-it symbol nil))))
  symbol)
;;(verilog-symbol-detick "`mod" nil)

(defun verilog-symbol-detick-denumber (symbol)
  "Return SYMBOL with defines converted and any numbers dropped to nil."
  (when (string-match "^`" symbol)
    ;; This only will work if the define is a simple signal, not
    ;; something like a[b].  Sorry, it should be substituted into the parser
    (setq symbol
          (verilog-string-replace-matches
           "\\[[^0-9: \t]+\\]" "" nil nil
           (or (verilog-symbol-detick symbol nil)
               (if verilog-auto-sense-defines-constant
                   "0"
                 symbol)))))
  (if (verilog-is-number symbol)
      nil
    symbol))

(defun verilog-symbol-detick-text (text)
  "Return TEXT without any known defines.
If the variable vh-{symbol} is defined, substitute that value."
  (let ((ok t) symbol val)
    (while (and ok (string-match "`\\([a-zA-Z0-9_]+\\)" text))
      (setq symbol (match-string 1 text))
      ;;(message symbol)
      (cond ((and
              ;; Namespace intentionally short for AUTOs and compatibility
              (boundp (intern (concat "vh-" symbol)))
              ;; Emacs has a bug where boundp on a buffer-local
              ;; variable in only one buffer returns t in another.
              ;; This can confuse, so check for nil.
              ;; Namespace intentionally short for AUTOs and compatibility
              (setq val (eval (intern (concat "vh-" symbol)))))
             (setq text (replace-match val nil nil text)))
            (t (setq ok nil)))))
  text)
;;(progn (setq vh-mod "`foo" vh-foo "bar") (verilog-symbol-detick-text "bar `mod `undefed"))

(defun verilog-expand-dirnames (&optional dirnames)
  "Return a list of existing directories given a list of wildcarded DIRNAMES.
Or, just the existing dirnames themselves if there are no wildcards."
  ;; Note this function is performance critical.
  ;; Do not call anything that requires disk access that cannot be cached.
  (interactive)
  (unless dirnames
    (error "`verilog-library-directories' should include at least `.'"))
  (save-match-data
    (setq dirnames (reverse dirnames))	; not nreverse
    (let ((dirlist nil)
          pattern dirfile dirfiles dirname root filename rest basefile)
      (setq dirnames (mapcar 'substitute-in-file-name dirnames))
      (while dirnames
        (setq dirname (car dirnames)
              dirnames (cdr dirnames))
        (cond ((string-match (concat "^\\(\\|[/\\]*[^*?]*[/\\]\\)"  ; root
                                     "\\([^/\\]*[*?][^/\\]*\\)"     ; filename with *?
                                     "\\(.*\\)")                    ; rest
                             dirname)
               (setq root (match-string 1 dirname)
                     filename (match-string 2 dirname)
                     rest (match-string 3 dirname)
                     pattern filename)
               ;; now replace those * and ? with .+ and .
               ;; use ^ and /> to get only whole file names
               (setq pattern (verilog-string-replace-matches "[*]" ".+" nil nil pattern)
                     pattern (verilog-string-replace-matches "[?]" "." nil nil pattern)
                     pattern (concat "^" pattern "$")
                     dirfiles (verilog-dir-files root))
               (while dirfiles
                 (setq basefile (car dirfiles)
                       dirfile (expand-file-name (concat root basefile rest))
                       dirfiles (cdr dirfiles))
                 (when (and (string-match pattern basefile)
                            ;; Don't allow abc/*/rtl to match abc/rtl via ..
                            (not (equal basefile "."))
                            (not (equal basefile "..")))
                   ;; Might have more wildcards, so process again
                   (setq dirnames (cons dirfile dirnames)))))
              ;; Defaults
              (t
               (if (file-directory-p dirname)
                   (setq dirlist (cons dirname dirlist))))))
      dirlist)))
;;(verilog-expand-dirnames (list "." ".." "nonexist" "../*" "/home/wsnyder/*/v" "../*/*"))

(defun verilog-library-filenames (filename &optional current check-ext)
  "Return a search path to find the given FILENAME or module name.
Uses the optional CURRENT filename or variable `buffer-file-name', plus
`verilog-library-directories' and `verilog-library-extensions'
variables to build the path.  With optional CHECK-EXT also check
`verilog-library-extensions'."
  (unless current (setq current (buffer-file-name)))
  (unless verilog-dir-cache-preserving
    (setq verilog-dir-cache-lib-filenames nil))
  (let* ((cache-key (list filename current check-ext))
         (fass (assoc cache-key verilog-dir-cache-lib-filenames))
         chkdirs chkdir chkexts fn outlist)
    (cond (fass  ; Return data from cache hit
           (nth 1 fass))
          (t
           ;; Note this expand can't be easily cached, as we need to
           ;; pick up buffer-local variables for newly read sub-module files
           (setq chkdirs (verilog-expand-dirnames verilog-library-directories))
           (while chkdirs
             (setq chkdir (expand-file-name (car chkdirs)
                                            (file-name-directory current))
                   chkexts (if check-ext verilog-library-extensions `("")))
             (while chkexts
               (setq fn (expand-file-name (concat filename (car chkexts))
                                          chkdir))
               ;;(message "Check for %s" fn)
               (if (verilog-dir-file-exists-p fn)
                   (setq outlist (cons (expand-file-name
                                        fn (file-name-directory current))
                                       outlist)))
               (setq chkexts (cdr chkexts)))
             (setq chkdirs (cdr chkdirs)))
           (setq outlist (nreverse outlist))
           (setq verilog-dir-cache-lib-filenames
                 (cons (list cache-key outlist)
                       verilog-dir-cache-lib-filenames))
           outlist))))

(defun verilog-module-filenames (module current)
  "Return a search path to find the given MODULE name.
Uses the CURRENT filename, `verilog-library-extensions',
`verilog-library-directories' and `verilog-library-files'
variables to build the path."
  ;; Return search locations for it
  (append (list current)                ; first, current buffer
          (verilog-library-filenames module current t)
          ;; Finally any libraries; fixed up if using e.g. tramp
          (mapcar (lambda (fname)
                    (if (file-name-absolute-p fname)
                        (concat (file-remote-p current) fname)
                      fname))
                  verilog-library-files)))

;;
;; Module Information
;;
;; Many of these functions work on "modi" a module information structure
;; A modi is:  [module-name-string file-name begin-point]

(defvar verilog-cache-enabled t
  "Non-nil enables caching of signals, etc.  Set to nil for debugging to make things SLOW!")

(defvar verilog-modi-cache-list nil
  "Cache of ((Module Function) Buf-Tick Buf-Modtime Func-Returns)...
For speeding up verilog-modi-get-* commands.
Buffer-local.")
(make-variable-buffer-local 'verilog-modi-cache-list)

(defvar verilog-modi-cache-preserve-tick nil
  "Modification tick after which the cache is still considered valid.
Use `verilog-preserve-modi-cache' to set it.")
(defvar verilog-modi-cache-preserve-buffer nil
  "Modification tick after which the cache is still considered valid.
Use `verilog-preserve-modi-cache' to set it.")
(defvar verilog-modi-cache-current-enable nil
  "Non-nil means allow caching `verilog-modi-current', set by let().")
(defvar verilog-modi-cache-current nil
  "Currently active `verilog-modi-current', if any, set by let().")
(defvar verilog-modi-cache-current-max nil
  "Current endmodule point for `verilog-modi-cache-current', if any.")

(defun verilog-modi-current ()
  "Return the modi structure for the module currently at point, possibly cached."
  (cond ((and verilog-modi-cache-current
              (>= (point) (verilog-modi-get-point verilog-modi-cache-current))
              (<= (point) verilog-modi-cache-current-max))
         ;; Slow assertion, for debugging the cache:
         ;;(or (equal verilog-modi-cache-current (verilog-modi-current-get)) (debug))
         verilog-modi-cache-current)
        (verilog-modi-cache-current-enable
         (setq verilog-modi-cache-current (verilog-modi-current-get)
               verilog-modi-cache-current-max
               ;; The cache expires when we pass "endmodule" as then the
               ;; current modi may change to the next module
               ;; This relies on the AUTOs generally inserting, not deleting text
               (save-excursion
                 (verilog-re-search-forward-quick verilog-end-defun-re nil nil)))
         verilog-modi-cache-current)
        (t
         (verilog-modi-current-get))))

(defun verilog-modi-current-get ()
  "Return the modi structure for the module currently at point."
  (let* (name type pt)
    ;; read current module's name
    (save-excursion
      (verilog-re-search-backward-quick verilog-defun-re nil nil)
      (setq type (match-string-no-properties 0))
      (verilog-re-search-forward-quick "(" nil nil)
      (setq name (verilog-read-module-name))
      (setq pt (point)))
    ;; return modi - note this vector built two places
    (verilog-modi-new name (or (buffer-file-name) (current-buffer)) pt type)))

(defvar verilog-modi-lookup-cache nil "Hash of (modulename modi).")
(make-variable-buffer-local 'verilog-modi-lookup-cache)
(defvar verilog-modi-lookup-last-current nil "Cache of `current-buffer' at last lookup.")
(defvar verilog-modi-lookup-last-tick nil "Cache of `buffer-chars-modified-tick' at last lookup.")

(defun verilog-modi-lookup (module allow-cache &optional ignore-error)
  "Find the file and point at which MODULE is defined.
If ALLOW-CACHE is set, check and remember cache of previous lookups.
Return modi if successful, else print message unless IGNORE-ERROR is true."
  (let* ((current (or (buffer-file-name) (current-buffer)))
         modi)
    ;; Check cache
    ;;(message "verilog-modi-lookup: %s" module)
    (cond ((and verilog-modi-lookup-cache
                verilog-cache-enabled
                allow-cache
                (setq modi (gethash module verilog-modi-lookup-cache))
                (equal verilog-modi-lookup-last-current current)
                ;; If hit is in current buffer, then tick must match
                (or (equal verilog-modi-lookup-last-tick (buffer-chars-modified-tick))
                    (not (equal current (verilog-modi-file-or-buffer modi)))))
           ;;(message "verilog-modi-lookup: HIT %S" modi)
           modi)
          ;; Miss
          (t (let* ((realname (verilog-symbol-detick module t))
                    (orig-filenames (verilog-module-filenames realname current))
                    (filenames orig-filenames)
                    mif)
               (while (and filenames (not mif))
                 (if (not (setq mif (verilog-module-inside-filename-p realname (car filenames))))
                     (setq filenames (cdr filenames))))
               ;; mif has correct form to become later elements of modi
               (setq modi mif)
               (or mif ignore-error
                   (error
                    (concat
                     "%s: Can't locate `%s' module definition%s"
                     "\n    Check the verilog-library-directories variable."
                     "\n    I looked in (if not listed, doesn't exist):\n\t%s")
                    (verilog-point-text) module
                    (if (not (equal module realname))
                        (concat " (Expanded macro to " realname ")")
                      "")
                    (mapconcat 'concat orig-filenames "\n\t")))
               (when (eval-when-compile (fboundp 'make-hash-table))
                 (unless verilog-modi-lookup-cache
                   (setq verilog-modi-lookup-cache
                         (make-hash-table :test 'equal :rehash-size 4.0)))
                 (puthash module modi verilog-modi-lookup-cache))
               (setq verilog-modi-lookup-last-current current
                     verilog-modi-lookup-last-tick (buffer-chars-modified-tick)))))
    modi))

(defun verilog-modi-filename (modi)
  "Filename of MODI, or name of buffer if it's never been saved."
  (if (bufferp (verilog-modi-file-or-buffer modi))
      (or (buffer-file-name (verilog-modi-file-or-buffer modi))
          (buffer-name (verilog-modi-file-or-buffer modi)))
    (verilog-modi-file-or-buffer modi)))

(defun verilog-modi-goto (modi)
  "Move point/buffer to specified MODI."
  (or modi (error "Passed unfound modi to goto, check earlier"))
  (set-buffer (if (bufferp (verilog-modi-file-or-buffer modi))
                  (verilog-modi-file-or-buffer modi)
                (find-file-noselect (verilog-modi-file-or-buffer modi))))
  (or (equal major-mode `verilog-mode)  ; Put into Verilog mode to get syntax
      (verilog-mode))
  (goto-char (verilog-modi-get-point modi)))

(defun verilog-goto-defun-file (module)
  "Move point to the file at which a given MODULE is defined."
  (interactive "sGoto File for Module: ")
  (let* ((modi (verilog-modi-lookup module nil)))
    (when modi
      (verilog-modi-goto modi)
      (switch-to-buffer (current-buffer)))))

(defun verilog-modi-cache-results (modi function)
  "Run on MODI the given FUNCTION.  Locate the module in a file.
Cache the output of function so next call may have faster access."
  (let (fass)
    (save-excursion  ; Cache is buffer-local so can't avoid this.
      (verilog-modi-goto modi)
      (if (and (setq fass (assoc (list modi function)
                                 verilog-modi-cache-list))
               ;; Destroy caching when incorrect; Modified or file changed
               (not (and verilog-cache-enabled
                         (or (equal (buffer-chars-modified-tick) (nth 1 fass))
                             (and verilog-modi-cache-preserve-tick
                                  (<= verilog-modi-cache-preserve-tick  (nth 1 fass))
                                  (equal  verilog-modi-cache-preserve-buffer (current-buffer))))
                         (equal (visited-file-modtime) (nth 2 fass)))))
          (setq verilog-modi-cache-list nil
                fass nil))
      (cond (fass
             ;; Return data from cache hit
             (nth 3 fass))
            (t
             ;; Read from file
             ;; Clear then restore any highlighting to make emacs19 happy
             (let ((func-returns
                    (verilog-save-font-no-change-functions
                     (funcall function))))
               ;; Cache for next time
               (setq verilog-modi-cache-list
                     (cons (list (list modi function)
                                 (buffer-chars-modified-tick)
                                 (visited-file-modtime)
                                 func-returns)
                           verilog-modi-cache-list))
               func-returns))))))

(defun verilog-modi-cache-add (modi function element sig-list)
  "Add function return results to the module cache.
Update MODI's cache for given FUNCTION so that the return ELEMENT of that
function now contains the additional SIG-LIST parameters."
  (let (fass)
    (save-excursion
      (verilog-modi-goto modi)
      (if (setq fass (assoc (list modi function)
                            verilog-modi-cache-list))
          (let ((func-returns (nth 3 fass)))
            (aset func-returns element
                  (append sig-list (aref func-returns element))))))))

(defmacro verilog-preserve-modi-cache (&rest body)
  "Execute the BODY forms, allowing cache preservation within BODY.
This means that changes to the buffer will not result in the cache being
flushed.  If the changes affect the modsig state, they must call the
modsig-cache-add-* function, else the results of later calls may be
incorrect.  Without this, changes are assumed to be adding/removing signals
and invalidating the cache."
  `(let ((verilog-modi-cache-preserve-tick (buffer-chars-modified-tick))
         (verilog-modi-cache-preserve-buffer (current-buffer)))
     (progn ,@body)))


(defun verilog-modi-modport-lookup-one (modi name &optional ignore-error)
  "Given a MODI, return the declarations related to the given modport NAME.
Report errors unless optional IGNORE-ERROR."
  ;; Recursive routine - see below
  (let* ((realname (verilog-symbol-detick name t))
         (modport (assoc name (verilog-decls-get-modports (verilog-modi-get-decls modi)))))
    (or modport ignore-error
        (error "%s: Can't locate `%s' modport definition%s"
               (verilog-point-text) name
               (if (not (equal name realname))
                   (concat " (Expanded macro to " realname ")")
                 "")))
    (let* ((decls (verilog-modport-decls modport))
           (clks (verilog-modport-clockings modport)))
      ;; Now expand any clocking's
      (while clks
        (setq decls (verilog-decls-append
                     decls
                     (verilog-modi-modport-lookup-one modi (car clks) ignore-error)))
        (setq clks (cdr clks)))
      decls)))

(defun verilog-modi-modport-lookup (modi name-re &optional ignore-error)
  "Given a MODI, return the declarations related to the given modport NAME-RE.
If the modport points to any clocking blocks, expand the signals to include
those clocking block's signals."
  ;; Recursive routine - see below
  (let* ((mod-decls (verilog-modi-get-decls modi))
         (clks (verilog-decls-get-modports mod-decls))
         (name-re (concat "^" name-re "$"))
         (decls (verilog-decls-new nil nil nil nil nil nil nil nil nil)))
    ;; Pull in all modports
    (while clks
      (when (string-match name-re (verilog-modport-name (car clks)))
        (setq decls (verilog-decls-append
                     decls
                     (verilog-modi-modport-lookup-one modi (verilog-modport-name (car clks)) ignore-error))))
      (setq clks (cdr clks)))
    decls))

(defun verilog-signals-matching-enum (in-list enum)
  "Return all signals in IN-LIST matching the given ENUM."
  (let (out-list)
    (while in-list
      (if (equal (verilog-sig-enum (car in-list)) enum)
          (setq out-list (cons (car in-list) out-list)))
      (setq in-list (cdr in-list)))
    ;; New scheme
    ;; Namespace intentionally short for AUTOs and compatibility
    (let* ((enumvar (intern (concat "venum-" enum)))
           (enumlist (and (boundp enumvar) (eval enumvar))))
      (while enumlist
        (add-to-list 'out-list (list (car enumlist)))
        (setq enumlist (cdr enumlist))))
    (nreverse out-list)))

(defun verilog-signals-matching-regexp (in-list regexp)
  "Return all signals in IN-LIST matching the given REGEXP, if non-nil."
  (if (or (not regexp) (equal regexp ""))
      in-list
    (let ((case-fold-search verilog-case-fold)
          out-list)
      (while in-list
        (if (string-match regexp (verilog-sig-name (car in-list)))
            (setq out-list (cons (car in-list) out-list)))
        (setq in-list (cdr in-list)))
      (nreverse out-list))))

(defun verilog-signals-not-matching-regexp (in-list regexp)
  "Return all signals in IN-LIST not matching the given REGEXP, if non-nil."
  (if (or (not regexp) (equal regexp ""))
      in-list
    (let ((case-fold-search verilog-case-fold)
          out-list)
      (while in-list
        (if (not (string-match regexp (verilog-sig-name (car in-list))))
            (setq out-list (cons (car in-list) out-list)))
        (setq in-list (cdr in-list)))
      (nreverse out-list))))

(defun verilog-signals-matching-dir-re (in-list decl-type regexp)
  "Return all signals in IN-LIST matching the given DECL-TYPE and REGEXP,
if non-nil."
  (if (or (not regexp) (equal regexp ""))
      in-list
    (let (out-list to-match)
      (while in-list
        ;; Note verilog-insert-one-definition matches on this order
        (setq to-match (concat
                        decl-type
                        " " (verilog-sig-signed (car in-list))
                        " " (verilog-sig-multidim (car in-list))
                        (verilog-sig-bits (car in-list))))
        (if (string-match regexp to-match)
            (setq out-list (cons (car in-list) out-list)))
        (setq in-list (cdr in-list)))
      (nreverse out-list))))

(defun verilog-signals-edit-wire-reg (in-list)
  "Return all signals in IN-LIST with wire/reg data types made blank."
  (mapcar (lambda (sig)
            (when (member (verilog-sig-type sig) '("wire" "reg"))
              (verilog-sig-type-set sig nil))
            sig) in-list))

;; Combined
(defun verilog-decls-get-signals (decls)
  "Return all declared signals in DECLS, excluding `assign' statements."
  (append
   (verilog-decls-get-outputs decls)
   (verilog-decls-get-inouts decls)
   (verilog-decls-get-inputs decls)
   (verilog-decls-get-vars decls)
   (verilog-decls-get-consts decls)
   (verilog-decls-get-gparams decls)))

(defun verilog-decls-get-ports (decls)
  (append
   (verilog-decls-get-outputs decls)
   (verilog-decls-get-inouts decls)
   (verilog-decls-get-inputs decls)))

(defun verilog-decls-get-iovars (decls)
  (append
   (verilog-decls-get-vars decls)
   (verilog-decls-get-outputs decls)
   (verilog-decls-get-inouts decls)
   (verilog-decls-get-inputs decls)))

(defsubst verilog-modi-cache-add-outputs (modi sig-list)
  (verilog-modi-cache-add modi 'verilog-read-decls 0 sig-list))
(defsubst verilog-modi-cache-add-inouts (modi sig-list)
  (verilog-modi-cache-add modi 'verilog-read-decls 1 sig-list))
(defsubst verilog-modi-cache-add-inputs (modi sig-list)
  (verilog-modi-cache-add modi 'verilog-read-decls 2 sig-list))
(defsubst verilog-modi-cache-add-vars (modi sig-list)
  (verilog-modi-cache-add modi 'verilog-read-decls 3 sig-list))
(defsubst verilog-modi-cache-add-gparams (modi sig-list)
  (verilog-modi-cache-add modi 'verilog-read-decls 7 sig-list))


;;; Auto creation utilities:
;;

(defun verilog-auto-re-search-do (search-for func)
  "Search for the given auto text regexp SEARCH-FOR, and perform FUNC where it occurs."
  (goto-char (point-min))
  (while (verilog-re-search-forward-quick search-for nil t)
    (funcall func)))

(defun verilog-insert-one-definition (sig type indent-pt)
  "Print out a definition for SIG of the given TYPE,
with appropriate INDENT-PT indentation."
  (indent-to indent-pt)
  ;; Note verilog-signals-matching-dir-re matches on this order
  (insert type)
  (when (verilog-sig-modport sig)
    (insert "." (verilog-sig-modport sig)))
  (when (verilog-sig-signed sig)
    (insert " " (verilog-sig-signed sig)))
  (when (verilog-sig-multidim sig)
    (insert " " (verilog-sig-multidim-string sig)))
  (when (verilog-sig-bits sig)
    (insert " " (verilog-sig-bits sig)))
  (indent-to (max 24 (+ indent-pt 16)))
  (unless (= (char-syntax (preceding-char)) ?\  )
    (insert " "))  ; Need space between "]name" if indent-to did nothing
  (insert (verilog-sig-name sig))
  (when (verilog-sig-memory sig)
    (insert " " (verilog-sig-memory sig))))

(defun verilog-insert-definition (modi sigs direction indent-pt v2k &optional dont-sort)
  "Print out a definition for MODI's list of SIGS of the given DIRECTION,
with appropriate INDENT-PT indentation.  If V2K, use Verilog 2001 I/O
format.  Sort unless DONT-SORT.  DIRECTION is normally wire/reg/output.
When MODI is non-null, also add to modi-cache, for tracking."
  (when modi
    (cond ((equal direction "wire")
           (verilog-modi-cache-add-vars modi sigs))
          ((equal direction "reg")
           (verilog-modi-cache-add-vars modi sigs))
          ((equal direction "output")
           (verilog-modi-cache-add-outputs modi sigs)
           (when verilog-auto-declare-nettype
             (verilog-modi-cache-add-vars modi sigs)))
          ((equal direction "input")
           (verilog-modi-cache-add-inputs modi sigs)
           (when verilog-auto-declare-nettype
             (verilog-modi-cache-add-vars modi sigs)))
          ((equal direction "inout")
           (verilog-modi-cache-add-inouts modi sigs)
           (when verilog-auto-declare-nettype
             (verilog-modi-cache-add-vars modi sigs)))
          ((equal direction "interface"))
          ((equal direction "parameter")
           (verilog-modi-cache-add-gparams modi sigs))
          (t
           (error "Unsupported verilog-insert-definition direction: `%s'" direction))))
  (or dont-sort
      (setq sigs (sort (copy-alist sigs) `verilog-signals-sort-compare)))
  (while sigs
    (let ((sig (car sigs)))
      (verilog-insert-one-definition
       sig
       ;; Want "type x" or "output type x", not "wire type x"
       (cond ((and (equal "wire" verilog-auto-wire-type)
                   (or (not (verilog-sig-type sig))
                       (equal "logic" (verilog-sig-type sig))))
              (if (member direction '("input" "output" "inout"))
                  direction
                "wire"))
             ;;
             ((or (verilog-sig-type sig)
                  verilog-auto-wire-type)
              (concat
               (when (member direction '("input" "output" "inout"))
                 (concat direction " "))
               (or (verilog-sig-type sig)
                   verilog-auto-wire-type)))
             ;;
             ((and verilog-auto-declare-nettype
                   (member direction '("input" "output" "inout")))
              (concat direction " " verilog-auto-declare-nettype))
             (t
              direction))
       indent-pt)
      (insert (if v2k "," ";"))
      (if (or (not verilog-auto-wire-comment)
              (not (verilog-sig-comment sig))
              (equal "" (verilog-sig-comment sig)))
          (insert "\n")
        (indent-to (max 48 (+ indent-pt 40)))
        (verilog-insert "// " (verilog-sig-comment sig) "\n"))
      (setq sigs (cdr sigs)))))

(eval-when-compile
  (if (not (boundp 'indent-pt))
      (defvar indent-pt nil "Local used by `verilog-insert-indent'.")))

(defun verilog-insert-indent (&rest stuff)
  "Indent to position stored in local `indent-pt' variable, then insert STUFF.
Presumes that any newlines end a list element."
  (let ((need-indent t))
    (while stuff
      (if need-indent (indent-to indent-pt))
      (setq need-indent nil)
      (verilog-insert (car stuff))
      (setq need-indent (string-match "\n$" (car stuff))
            stuff (cdr stuff)))))
;;(let ((indent-pt 10)) (verilog-insert-indent "hello\n" "addon" "there\n"))

(defun verilog-forward-or-insert-line ()
  "Move forward a line, unless at EOB, then insert a newline."
  (if (eobp) (insert "\n")
    (forward-line)))

(defun verilog-repair-open-comma ()
  "Insert comma if previous argument is other than an open parenthesis or endif."
  ;; We can't just search backward for ) as it might be inside another expression.
  ;; Also want "`ifdef X   input foo   `endif" to just leave things to the human to deal with
  (save-excursion
    (verilog-backward-syntactic-ws-quick)
    (when (and (not (save-excursion  ; Not beginning (, or existing ,
                      (backward-char 1)
                      (looking-at "[(,]")))
               (not (save-excursion  ; Not `endif, or user define
                      (backward-char 1)
                      (skip-chars-backward "[a-zA-Z0-9_`]")
                      (looking-at "`"))))
      (insert ","))))

(defun verilog-repair-close-comma ()
  "If point is at a comma followed by a close parenthesis, fix it.
This repairs those mis-inserted by an AUTOARG."
  ;; It would be much nicer if Verilog allowed extra commas like Perl does!
  (save-excursion
    (verilog-forward-close-paren)
    (backward-char 1)
    (verilog-backward-syntactic-ws-quick)
    (backward-char 1)
    (when (looking-at ",")
      (delete-char 1))))

(defun verilog-make-width-expression (range-exp)
  "Return an expression calculating the length of a range [x:y] in RANGE-EXP."
  ;; strip off the []
  (cond ((not range-exp)
         "1")
        (t
         (if (string-match "^\\[\\(.*\\)\\]$" range-exp)
             (setq range-exp (match-string 1 range-exp)))
         (cond ((not range-exp)
                "1")
               ;; [#:#] We can compute a numeric result
               ((string-match "^\\s *\\([0-9]+\\)\\s *:\\s *\\([0-9]+\\)\\s *$"
                              range-exp)
                (int-to-string
                 (1+ (abs (- (string-to-number (match-string 1 range-exp))
                             (string-to-number (match-string 2 range-exp)))))))
               ;; [PARAM-1:0] can just return PARAM
               ((string-match "^\\s *\\([a-zA-Z_][a-zA-Z0-9_]*\\)\\s *-\\s *1\\s *:\\s *0\\s *$" range-exp)
                (match-string 1 range-exp))
               ;; [arbitrary] need math
               ((string-match "^\\(.*\\)\\s *:\\s *\\(.*\\)\\s *$" range-exp)
                (concat "(1+(" (match-string 1 range-exp) ")"
                        (if (equal "0" (match-string 2 range-exp))
                            ""  ; Don't bother with -(0)
                          (concat "-(" (match-string 2 range-exp) ")"))
                        ")"))
               (t nil)))))

(defun verilog-simplify-range-expression (expr)
  "Return a simplified range expression with constants eliminated from EXPR."
  ;; Note this is always called with brackets; ie [z] or [z:z]
  (if (or (not verilog-auto-simplify-expressions)
          (not (string-match "[---+*/<>()]" expr)))
      expr  ; disabled or short-circuited
    (let ((out expr)
          (last-pass ""))
      (while (not (equal last-pass out))
        (while (not (equal last-pass out))
          (setq last-pass out)
          ;; Prefix regexp needs beginning of match, or some symbol of
          ;; lesser or equal precedence.  We assume the [:]'s exist in expr.
          ;; Ditto the end.
          (while (string-match
                  (concat "\\([[({:*/<>+-]\\)"  ; - must be last
                          "(\\<\\([0-9A-Za-z_]+\\))"
                          "\\([])}:*/<>+-]\\)")
                  out)
            (setq out (replace-match "\\1\\2\\3" nil nil out)))
          (while (string-match
                  (concat "\\([[({:*/<>+-]\\)"  ; - must be last
                          "\\$clog2\\s *(\\<\\([0-9]+\\))"
                          "\\([])}:*/<>+-]\\)")
                  out)
            (setq out (replace-match
                       (concat
                        (match-string 1 out)
                        (int-to-string (verilog-clog2 (string-to-number (match-string 2 out))))
                        (match-string 3 out))
                       nil nil out)))
          ;; For precedence do *,/ before +,-,>>,<<
          (while (string-match
                  (concat "\\([[({:*/<>+-]\\)"
                          "\\([0-9]+\\)\\s *\\([*/]\\)\\s *\\([0-9]+\\)"
                          "\\([])}:*/<>+-]\\)")
                  out)
            (setq out (replace-match
                       (concat (match-string 1 out)
                               (if (equal (match-string 3 out) "/")
                                   (int-to-string (/ (string-to-number (match-string 2 out))
                                                     (string-to-number (match-string 4 out)))))
                               (if (equal (match-string 3 out) "*")
                                   (int-to-string (* (string-to-number (match-string 2 out))
                                                     (string-to-number (match-string 4 out)))))
                               (match-string 5 out))
                       nil nil out)))
          ;; Next precedence is +,-
          (while (string-match
                  (concat "\\([[({:<>+-]\\)"  ; No *,/ here as higher prec
                          "\\([0-9]+\\)\\s *\\([---+]\\)\\s *\\([0-9]+\\)"
                          "\\([])}:<>+-]\\)")
                  out)
            (let ((pre (match-string 1 out))
                  (lhs (string-to-number (match-string 2 out)))
                  (rhs (string-to-number (match-string 4 out)))
                  (post (match-string 5 out))
                  val)
              (when (equal pre "-")
                (setq lhs (- lhs)))
              (setq val (if (equal (match-string 3 out) "-")
                            (- lhs rhs)
                          (+ lhs rhs))
                    out (replace-match
                         (concat (if (and (equal pre "-")
                                          (< val 0))
                                     ""  ; Not "--20" but just "-20"
                                   pre)
                                 (int-to-string val)
                                 post)
                         nil nil out)) ))
          ;; Next precedence is >>,<<
          (while (string-match
                  (concat "\\([[({:]\\)"  ;; No << as not transitive
                          "\\([0-9]+\\)\\s *\\([<]\\{2,3\\}\\|[>]\\{2,3\\}\\)\\s *\\([0-9]+\\)"
                          "\\([])}:<>]\\)")
                  out)
            (setq out (replace-match
                       (concat (match-string 1 out)
                               (if (equal (match-string 3 out) ">>")
                                   (int-to-string (lsh (string-to-number (match-string 2 out))
                                                       (* -1 (string-to-number (match-string 4 out))))))
                               (if (equal (match-string 3 out) "<<")
                                   (int-to-string (lsh (string-to-number (match-string 2 out))
                                                       (string-to-number (match-string 4 out)))))
                               (if (equal (match-string 3 out) ">>>")
                                   (int-to-string (ash (string-to-number (match-string 2 out))
                                                       (* -1 (string-to-number (match-string 4 out))))))
                               (if (equal (match-string 3 out) "<<<")
                                   (int-to-string (ash (string-to-number (match-string 2 out))
                                                       (string-to-number (match-string 4 out)))))
                               (match-string 5 out))
                       nil nil out)))))
      out)))

(defun verilog-clog2 (value)
  "Compute $clog2 - ceiling log2 of VALUE."
  (if (< value 1)
      0
    (ceiling (/ (log value) (log 2)))))

(defun verilog-typedef-name-p (variable-name)
  "Return true if the VARIABLE-NAME is a type definition."
  (when verilog-typedef-regexp
    (verilog-string-match-fold verilog-typedef-regexp variable-name)))




(defconst verilog-include-file-regexp
  "^[ \t]*`include\\s-+\"\\([^\n\"]*\\)\""
  "Regexp that matches the include file.")

(defun verilog-highlight-region (beg end _old-len)
  "Colorize included files and modules in the (changed?) region.
Clicking on the middle-mouse button loads them in a buffer (as in dired)."
  (when (or verilog-highlight-includes
            verilog-highlight-modules)
    (save-excursion
      (save-match-data  ; A query-replace may call this function - do not disturb
        (verilog-save-buffer-state
         (verilog-save-scan-cache
          (let (end-point)
            (goto-char end)
            (setq end-point (point-at-eol))
            (goto-char beg)
            (beginning-of-line)  ; scan entire line
            ;; delete overlays existing on this line
            (let ((overlays (overlays-in (point) end-point)))
              (while overlays
                (if (and (overlay-get (car overlays) 'detachable)
                         (or (overlay-get (car overlays) 'verilog-include-file)
                             (overlay-get (car overlays) 'verilog-inst-module)))
                    (delete-overlay (car overlays)))
                (setq overlays (cdr overlays))))
            ;;
            ;; make new include overlays
            (when verilog-highlight-includes
              (while (search-forward-regexp verilog-include-file-regexp end-point t)
                (goto-char (match-beginning 1))
                (let ((ov (make-overlay (match-beginning 1) (match-end 1))))
                  (overlay-put ov 'start-closed 't)
                  (overlay-put ov 'end-closed 't)
                  (overlay-put ov 'evaporate 't)
                  (overlay-put ov 'verilog-include-file 't))))
            ;;
            ;; make new module overlays
            (goto-char beg)
            ;; This scanner is syntax-fragile, so don't get bent
            (when verilog-highlight-modules
              (condition-case nil
                  (while (verilog-re-search-forward-quick "\\(\\.\\*\\)" end-point t)
                    (save-excursion
                      (goto-char (match-beginning 0))
                      (unless (verilog-inside-comment-or-string-p)
                        (verilog-read-inst-module-matcher)  ; sets match 0
                        (let* ((ov (make-overlay (match-beginning 0) (match-end 0))))
                          (overlay-put ov 'start-closed 't)
                          (overlay-put ov 'end-closed 't)
                          (overlay-put ov 'evaporate 't)
                          (overlay-put ov 'verilog-inst-module 't)))))
                (error nil)))
            ;;
            ;; Future highlights:
            ;;  variables - make an Occur buffer of where referenced
            ;;  pins - make an Occur buffer of the sig in the declaration module
            )))))))

(defun verilog-highlight-buffer ()
  "Colorize included files and modules across the whole buffer."
  ;; Invoked via verilog-mode calling font-lock then `font-lock-mode-hook'
  (interactive)
  ;; delete and remake overlays
  (verilog-highlight-region (point-min) (point-max) nil))



;;; Bug reporting:
;;

(defun verilog-faq ()
  "Tell the user their current version, and where to get the FAQ etc."
  (interactive)
  (with-output-to-temp-buffer "*verilog-mode help*"
    (princ (format "You are using verilog-mode %s\n" verilog-mode-version))
    (princ "\n")
    (princ "For new releases, see http://www.veripool.com/verilog-mode\n")
    (princ "\n")
    (princ "For frequently asked questions, see http://www.veripool.org/verilog-mode-faq.html\n")
    (princ "\n")
    (princ "To submit a bug, use M-x verilog-submit-bug-report\n")
    (princ "\n")))

(autoload 'reporter-submit-bug-report "reporter")
(defvar reporter-prompt-for-summary-p)

(defun verilog-submit-bug-report ()
  "Submit via mail a bug report on verilog-mode.el."
  (interactive)
  (let ((reporter-prompt-for-summary-p t))
    (reporter-submit-bug-report
     "mac@verilog.com, wsnyder@wsnyder.org"
     (concat "verilog-mode v" verilog-mode-version)
     '(
       verilog-active-low-regexp
       verilog-after-save-font-hook
       verilog-align-ifelse
       verilog-assignment-delay
       verilog-before-getopt-flags-hook
       verilog-before-save-font-hook
       verilog-cache-enabled
       verilog-case-fold
       verilog-case-indent
       verilog-cexp-indent
       verilog-delete-auto-hook
       verilog-getopt-flags-hook
       verilog-highlight-grouping-keywords
       verilog-highlight-includes
       verilog-highlight-modules
       verilog-highlight-p1800-keywords
       verilog-highlight-translate-off
       verilog-indent-begin-after-if
       verilog-indent-declaration-macros
       verilog-indent-level
       verilog-indent-level-behavioral
       verilog-indent-level-declaration
       verilog-indent-level-directive
       verilog-indent-level-module
       verilog-indent-lists
       verilog-library-directories
       verilog-library-extensions
       verilog-library-files
       verilog-library-flags
       verilog-minimum-comment-distance
       verilog-mode-hook
       verilog-mode-release-emacs
       verilog-mode-version
       verilog-preprocessor
       verilog-tab-always-indent
       verilog-tab-to-comment
       verilog-typedef-regexp
       )
     nil nil
     (concat "Hi Mac,

I want to report a bug.

Before I go further, I want to say that Verilog mode has changed my life.
I save so much time, my files are colored nicely, my co workers respect
my coding ability... until now.  I'd really appreciate anything you
could do to help me out with this minor deficiency in the product.

I've taken a look at the Verilog-Mode FAQ at
http://www.veripool.org/verilog-mode-faq.html.

And, I've considered filing the bug on the issue tracker at
http://www.veripool.org/verilog-mode-bugs
since I realize that public bugs are easier for you to track,
and for others to search, but would prefer to email.

So, to reproduce the bug, start a fresh Emacs via " invocation-name "
-no-init-file -no-site-file'.  In a new buffer, in Verilog mode, type
the code included below.

Given those lines, I expected [[Fill in here]] to happen;
but instead, [[Fill in here]] happens!.

== The code: =="))))

(provide 'verilog-mode)

;; Local Variables:
;; checkdoc-permit-comma-termination-flag:t
;; checkdoc-force-docstrings-flag:nil
;; indent-tabs-mode:nil
;; End:

;;; verilog-mode.el ends here
