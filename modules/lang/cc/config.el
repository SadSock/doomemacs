;;; lang/cc/config.el --- c, c++, and obj-c -*- lexical-binding: t; -*-

(defvar +cc-default-include-paths
  (list "include"
        "includes")
  "A list of default relative paths which will be searched for up from the
current file, to be passed to irony as extra header search paths. Paths can be
absolute. This is ignored if your project has a compilation database.

This is ignored by ccls.")

(defvar +cc-default-header-file-mode 'c-mode
  "Fallback major mode for .h files if all other heuristics fail (in
`+cc-c-c++-objc-mode').")

(defvar +cc-default-compiler-options
  `((c-mode . nil)
    (c++-mode
     . ,(list "-std=c++1z" ; use C++17 draft by default
              (when IS-MAC
                ;; NOTE beware: you'll get abi-inconsistencies when passing
                ;; std-objects to libraries linked with libstdc++ (e.g. if you
                ;; use boost which wasn't compiled with libc++)
                "-stdlib=libc++")))
    (objc-mode . nil))
  "A list of default compiler options for the C family. These are ignored if a
compilation database is present in the project.

This is ignored by ccls.")


;;
;;; Packages

(use-package! cc-mode
  :mode ("\\.mm\\'" . objc-mode)
  ;; Use `c-mode'/`c++-mode'/`objc-mode' depending on heuristics
  :mode ("\\.h\\'" . +cc-c-c++-objc-mode) 
  ;; Ensure find-file-at-point recognize system libraries in C modes. It must be
  ;; set up before the likes of irony/lsp are initialized. Also, we use
  ;; local-vars hooks to ensure these only run in their respective major modes,
  ;; and not their derived modes.
  :hook ((c-mode-local-vars c++-mode-local-vars objc-mode-local-vars) . +cc-init-ffap-integration-h)
  ;;; Improve fontification in C/C++ (also see `modern-cpp-font-lock')
  :hook ((c-mode c++-mode) . +cc-fontify-constants-h)
  :config
  (set-docsets! 'c-mode "C")
  (set-docsets! 'c++-mode "C++" "Boost")
  (set-electric! '(c-mode c++-mode objc-mode java-mode) :chars '(?\n ?\} ?\{))
  (set-rotate-patterns! 'c++-mode
    :symbols '(("public" "protected" "private")
               ("class" "struct")))
  (set-ligatures! '(c-mode c++-mode)
    ;; Functional
    ;; :def "void "
    ;; Types
    :null "nullptr"
    :true "true" :false "false"
    :int "int" :float "float"
    :str "std::string"
    :bool "bool"
    ;; Flow
    :not "!"
    :and "&&" :or "||"
    :for "for"
    :return "return"
    :yield "#require")

  (when (modulep! +tree-sitter)
    (add-hook! '(c-mode-local-vars-hook
                 c++-mode-local-vars-hook)
               :append #'tree-sitter!))

  ;; HACK Suppress 'Args out of range' error in when multiple modifications are
  ;;      performed at once in a `c++-mode' buffer, e.g. with `iedit' or
  ;;      multiple cursors.
  (undefadvice! +cc--suppress-silly-errors-a (fn &rest args)
    :around #'c-after-change-mark-abnormal-strings
    (ignore-errors (apply fn args)))

  ;; Custom style, based off of linux
  (setq c-basic-offset tab-width
        c-backspace-function #'delete-backward-char)

  (c-add-style
   "doom" '((c-comment-only-line-offset . 0)
            (c-hanging-braces-alist (brace-list-open)
                                    (brace-entry-open)
                                    (substatement-open after)
                                    (block-close . c-snug-do-while)
                                    (arglist-cont-nonempty))
            (c-cleanup-list brace-else-brace)
            (c-offsets-alist
             (knr-argdecl-intro . 0)
             (substatement-open . 0)
             (substatement-label . 0)
             (statement-cont . +)
             (case-label . +)
             ;; align args with open brace OR don't indent at all (if open
             ;; brace is at eolp and close brace is after arg with no trailing
             ;; comma)
             (brace-list-intro . 0)
             (brace-list-close . -)
             (arglist-intro . +)
             (arglist-close +cc-lineup-arglist-close 0)
             ;; don't over-indent lambda blocks
             (inline-open . 0)
             (inlambda . 0)
             ;; indent access keywords +1 level, and properties beneath them
             ;; another level
             (access-label . -)
             (inclass +cc-c++-lineup-inclass +)
             (label . 0))))

  (when (listp c-default-style)
    (setf (alist-get 'other c-default-style) "doom"))

  (after! ffap
    (add-to-list 'ffap-alist '(c-mode . ffap-c-mode))))

;;
;; LSP

(when (modulep! +lsp)
  (add-hook! '(c-mode-local-vars-hook
               c++-mode-local-vars-hook
               objc-mode-local-vars-hook
               cmake-mode-local-vars-hook)
             :append #'lsp!)

  (map! :after ccls
        :map (c-mode-map c++-mode-map)
        :n "C-h" (cmd! (ccls-navigate "U"))
        :n "C-j" (cmd! (ccls-navigate "R"))
        :n "C-k" (cmd! (ccls-navigate "L"))
        :n "C-l" (cmd! (ccls-navigate "D"))
        (:localleader
         :desc "Preprocess file"        "lp" #'ccls-preprocess-file
         :desc "Reload cache & CCLS"    "lf" #'ccls-reload)
        (:after lsp-ui-peek
         (:localleader
          :desc "Callers list"          "c" #'+cc/ccls-show-caller
          :desc "Callees list"          "C" #'+cc/ccls-show-callee
          :desc "References (address)"  "a" #'+cc/ccls-show-references-address
          :desc "References (not call)" "f" #'+cc/ccls-show-references-not-call
          :desc "References (Macro)"    "m" #'+cc/ccls-show-references-macro
          :desc "References (Read)"     "r" #'+cc/ccls-show-references-read
          :desc "References (Write)"    "w" #'+cc/ccls-show-references-write)))

  (when (modulep! :tools lsp +eglot)
    ;; Map eglot specific helper
    (map! :localleader
          :after cc-mode
          :map c++-mode-map
          :desc "Show type inheritance hierarchy" "ct" #'+cc/eglot-ccls-inheritance-hierarchy)

    ;; NOTE : This setting is untested yet
    (after! eglot
      (when IS-MAC
        (add-to-list 'eglot-workspace-configuration
                     `((:ccls . ((:clang . ,(list :extraArgs ["-isystem/Library/Developer/CommandLineTools/usr/include/c++/v1"
                                                              "-isystem/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include"
                                                              "-isystem/usr/local/include"]
                                                  :resourceDir (cdr (doom-call-process "clang" "-print-resource-dir"))))))))))))

(use-package! ccls
  :when (modulep! +lsp)
  :unless (modulep! :tools lsp +eglot)
  :defer t
  :init
  (defvar ccls-sem-highlight-method 'font-lock)
  (after! projectile
    (add-to-list 'projectile-globally-ignored-directories "^.ccls-cache$")
    (add-to-list 'projectile-project-root-files-bottom-up ".ccls-root")
    (add-to-list 'projectile-project-root-files-top-down-recurring "compile_commands.json"))
  ;; Avoid using `:after' because it ties the :config below to when `lsp-mode'
  ;; loads, rather than `ccls' loads.
  (after! lsp-mode (require 'ccls))
  :config
  (set-evil-initial-state! 'ccls-tree-mode 'emacs)
  ;; Disable `ccls-sem-highlight-method' if `lsp-enable-semantic-highlighting'
  ;; is nil. Otherwise, it appears ccls bypasses it.
  (setq-hook! 'lsp-configure-hook
    ccls-sem-highlight-method (if lsp-enable-semantic-highlighting
                                  ccls-sem-highlight-method))
  (when (or IS-MAC
            IS-LINUX)
    (setq ccls-initialization-options
          `(:index (:trackDependency 1
                    :threads ,(max 1 (/ (doom-system-cpus) 2))))))
  (when IS-MAC
    (setq ccls-initialization-options
          (append ccls-initialization-options
                  `(:clang ,(list :extraArgs ["-isystem/Library/Developer/CommandLineTools/usr/include/c++/v1"
                                              "-isystem/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include"
                                              "-isystem/usr/local/include"]
                                  :resourceDir (cdr (doom-call-process "clang" "-print-resource-dir"))))))))
