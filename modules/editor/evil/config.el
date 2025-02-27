;;; editor/evil/config.el -*- lexical-binding: t; -*-

(defvar +evil-repeat-keys (cons ";" ",")
  "The keys to use for universal repeating motions.

This is a cons cell whose CAR is the key for repeating a motion forward, and
whose CDR is for repeating backward. They should both be `kbd'-able strings.

Set this to `nil' to disable universal-repeating on these keys.")

(defvar +evil-want-o/O-to-continue-comments t
  "If non-nil, the o/O keys will continue comment lines if the point is on a
line with a linewise comment.")

(defvar +evil-preprocessor-regexp "^\\s-*#[a-zA-Z0-9_]"
  "The regexp used by `+evil/next-preproc-directive' and
`+evil/previous-preproc-directive' on ]# and [#, to jump between preprocessor
directives. By default, this only recognizes C directives.")

;; Set these defaults before `evil'; use `defvar' so they can be changed prior
;; to loading.
(defvar evil-want-C-g-bindings t)
(defvar evil-want-C-i-jump nil)  ; we do this ourselves
(defvar evil-want-C-u-scroll t)  ; moved the universal arg to <leader> u
(defvar evil-want-C-u-delete t)
(defvar evil-want-C-w-delete t)
(defvar evil-want-Y-yank-to-eol t)
(defvar evil-want-abbrev-expand-on-insert-exit nil)
(defvar evil-respect-visual-line-mode nil)

(use-package! evil
  :hook (doom-after-modules-config . evil-mode)
  :demand t
  :preface
  (setq evil-ex-search-vim-style-regexp t
        evil-ex-visual-char-range t  ; column range for ex commands
        evil-mode-line-format 'nil
        ;; more vim-like behavior
        evil-symbol-word-search t
        ;; if the current state is obvious from the cursor's color/shape, then
        ;; we won't need superfluous indicators to do it instead.
        evil-default-cursor '+evil-default-cursor-fn
        evil-normal-state-cursor 'box
        evil-emacs-state-cursor  '(box +evil-emacs-cursor-fn)
        evil-insert-state-cursor 'bar
        evil-visual-state-cursor 'hollow
        ;; Only do highlighting in selected window so that Emacs has less work
        ;; to do highlighting them all.
        evil-ex-interactive-search-highlight 'selected-window
        ;; It's infuriating that innocuous "beginning of line" or "end of line"
        ;; errors will abort macros, so suppress them:
        evil-kbd-macro-suppress-motion-error t
        evil-undo-system
        (cond ((modulep! :emacs undo +tree) 'undo-tree)
              ((modulep! :emacs undo) 'undo-fu)
              ((> emacs-major-version 27) 'undo-redo)))

  ;; Fix #7141
  (defadvice! +evil--persist-state-a (fn &rest args)
    "When changing major modes, Evil's state is lost. This advice preserves it."
    :around #'set-auto-mode
    (if evil-state
        (evil-save-state (apply fn args))
      (apply fn args)))

  ;; Slow this down from 0.02 to prevent blocking in large or folded buffers
  ;; like magit while incrementally highlighting matches.
  (setq-hook! '(magit-mode-hook so-long-minor-mode-hook)
    evil-ex-hl-update-delay 0.25)

  :config
  (evil-select-search-module 'evil-search-module 'evil-search)

  ;; PERF: Stop copying the selection to the clipboard each time the cursor
  ;; moves in visual mode. Why? Because on most non-X systems (and in terminals
  ;; with clipboard plugins like xclip.el active), Emacs will spin up a new
  ;; process to communicate with the clipboard for each movement. On Windows,
  ;; older versions of macOS (pre-vfork), and Waylang (without pgtk), this is
  ;; super expensive and can lead to freezing and/or zombie processes.
  ;;
  ;; UX: It also clobbers clipboard managers (see emacs-evil/evil#336).
  (setq evil-visual-update-x-selection-p nil)

  ;; Start help-with-tutorial in emacs state
  (advice-add #'help-with-tutorial :after (lambda (&rest _) (evil-emacs-state +1)))

  ;; Done in a hook to ensure the popup rules load as late as possible
  (add-hook! 'doom-after-modules-config-hook
    (defun +evil--init-popup-rules-h ()
      (set-popup-rules!
        '(("^\\*evil-registers" :size 0.3)
          ("^\\*Command Line"   :size 8)))))

  ;; Change the cursor color in emacs state. We do it this roundabout way
  ;; to ensure changes in theme doesn't break these colors.
  (add-hook! '(doom-load-theme-hook doom-after-modules-config-hook)
    (defun +evil-update-cursor-color-h ()
      (put 'cursor 'evil-emacs-color  (face-foreground 'warning))
      (put 'cursor 'evil-normal-color (face-background 'cursor))))

  (defun +evil-default-cursor-fn ()
    (evil-set-cursor-color (get 'cursor 'evil-normal-color)))
  (defun +evil-emacs-cursor-fn ()
    (evil-set-cursor-color (get 'cursor 'evil-emacs-color)))

  ;; Ensure `evil-shift-width' always matches `tab-width'; evil does not police
  ;; this itself, so we must.
  (setq-hook! 'after-change-major-mode-hook evil-shift-width tab-width)


  ;; --- keybind fixes ----------------------
  (after! wgrep
    ;; A wrapper that invokes `wgrep-mark-deletion' across lines you use
    ;; `evil-delete' in wgrep buffers.
    (define-key wgrep-mode-map [remap evil-delete] #'+evil-delete))


  ;; --- evil hacks -------------------------
  (after! eldoc
    ;; Allow eldoc to trigger directly after changing modes
    (eldoc-add-command 'evil-normal-state
                       'evil-insert
                       'evil-change
                       'evil-delete
                       'evil-replace))

  (unless noninteractive
    (setq save-silently t)
    (add-hook! 'after-save-hook
      (defun +evil-display-vimlike-save-message-h ()
        "Shorter, vim-esque save messages."
        (message "\"%s\" %dL, %dC written"
                 (if buffer-file-name
                     (file-relative-name (file-truename buffer-file-name) (doom-project-root))
                   (buffer-name))
                 (count-lines (point-min) (point-max))
                 (buffer-size)))))

  ;; HACK '=' moves the cursor to the beginning of selection. Disable this,
  ;;      since it's more disruptive than helpful.
  (defadvice! +evil--dont-move-cursor-a (fn &rest args)
    :around #'evil-indent
    (save-excursion (apply fn args)))

  ;; REVIEW In evil, registers 2-9 are buffer-local. In vim, they're global,
  ;;        so... Perhaps this should be PRed upstream?
  (defadvice! +evil--make-numbered-markers-global-a (char)
    :after-until #'evil-global-marker-p
    (and (>= char ?2) (<= char ?9)))

  ;; REVIEW Fix #2493: dir-locals cannot target fundamental-mode when evil-mode
  ;;        is active. See hlissner/doom-emacs#2493. Revert this if
  ;;        emacs-evil/evil#1268 is resolved upstream.
  (defadvice! +evil--fix-local-vars-a (&rest _)
    :before #'turn-on-evil-mode
    (when (eq major-mode 'fundamental-mode)
      (hack-local-variables)))

  ;; HACK Invoking helpful from evil-ex throws a "No recursive edit is in
  ;;      progress" error because, between evil-ex and helpful,
  ;;      `abort-recursive-edit' gets called one time too many.
  (defadvice! +evil--fix-helpful-key-in-evil-ex-a (key-sequence)
    :before #'helpful-key
    (when (evil-ex-p)
      (run-at-time 0.1 nil #'helpful-key key-sequence)
      (abort-recursive-edit)))

  ;; Make J (evil-join) remove comment delimiters when joining lines.
  (advice-add #'evil-join :around #'+evil-join-a)

  ;; Prevent gw (`evil-fill') and gq (`evil-fill-and-move') from squeezing
  ;; spaces. It doesn't in vim, so it shouldn't in evil.
  (defadvice! +evil--no-squeeze-on-fill-a (fn &rest args)
    :around '(evil-fill evil-fill-and-move)
    (letf! (defun fill-region (from to &optional justify nosqueeze to-eop)
             (funcall fill-region from to justify t to-eop))
      (apply fn args)))


  ;; monkey patch `evil-ex-replace-special-filenames' to improve support for
  ;; file modifiers like %:p:h. This adds support for most of vim's modifiers,
  ;; and one custom one: %:P (expand to the project root).
  (advice-add #'evil-ex-replace-special-filenames :override #'+evil-replace-filename-modifiers-a)

  ;; make `try-expand-dabbrev' (from `hippie-expand') work in minibuffer
  (add-hook 'minibuffer-inactive-mode-hook #'+evil--fix-dabbrev-in-minibuffer-h)

  ;; Focus and recenter new splits
  (advice-add #'evil-window-split  :override #'+evil-window-split-a)
  (advice-add #'evil-window-vsplit :override #'+evil-window-vsplit-a)

  ;; Make o/O continue comments (see `+evil-want-o/O-to-continue-comments' to disable)
  ;;(advice-add #'evil-open-above :around #'+evil--insert-newline-above-and-respect-comments-a)
  ;;(advice-add #'evil-open-below :around #'+evil--insert-newline-below-and-respect-comments-a)

  ;; --- custom interactive codes -----------
  ;; These arg types will highlight matches in the current buffer
  (evil-ex-define-argument-type regexp-match
    :runner (lambda (flag &optional arg) (+evil-ex-regexp-match flag arg 'inverted)))
  (evil-ex-define-argument-type regexp-global-match
    :runner +evil-ex-regexp-match)

  (defun +evil--regexp-match-args (arg)
    (when (evil-ex-p)
      (cl-destructuring-bind (&optional arg flags)
          (evil-delimited-arguments arg 2)
        (list arg (string-to-list flags)))))

  ;; Other commands can make use of this
  (evil-define-interactive-code "<//>"
    :ex-arg regexp-match
    (+evil--regexp-match-args evil-ex-argument))

  (evil-define-interactive-code "<//!>"
    :ex-arg regexp-global-match
    (+evil--regexp-match-args evil-ex-argument))

  ;; Forward declare these so that ex completion works, even if the autoloaded
  ;; functions aren't loaded yet.
  (evil-add-command-properties '+evil:align :ex-arg 'regexp-match)
  (evil-add-command-properties '+evil:align-right :ex-arg 'regexp-match)
  (evil-add-command-properties '+multiple-cursors:evil-mc :ex-arg 'regexp-global-match)

  ;; Lazy load evil ex commands
  (delq! 'evil-ex features)
  (add-transient-hook! 'evil-ex (provide 'evil-ex))
  (after! evil-ex (load! "+commands")))

;;
;;; Packages

(use-package! evil-traces
  :after evil-ex
  :config
  (pushnew! evil-traces-argument-type-alist
            '(+evil:align . evil-traces-global)
            '(+evil:align-right . evil-traces-global))
  (evil-traces-mode))


;; Allows you to use the selection for * and #
(use-package! evil-visualstar
  :commands (evil-visualstar/begin-search
             evil-visualstar/begin-search-forward
             evil-visualstar/begin-search-backward)
  :init
  (evil-define-key* 'visual 'global
    "*" #'evil-visualstar/begin-search-forward
    "#" #'evil-visualstar/begin-search-backward))

(use-package evil-mc
  :diminish
  :hook (after-init . global-evil-mc-mode)
  :init
  (defvar evil-mc-key-map (make-sparse-keymap))
  :config
  (defhydra hydra-evil-mc (:color blue :hint nil)
    "
 _M_ all match          _m_ here           _u_ undo
 _n_ next match         _j_ next line      _s_ suspend
 _p_ prev match         _k_ previous line  _r_ resume
 _N_ skip & next match  _H_ first cursor   _q_ quit
 _P_ skip & prev match  _L_ last cursor    _O_ quit
    "
    ("m" evil-mc-make-cursor-here :exit nil)
    ("M" evil-mc-make-all-cursors :exit nil)
    ("n" evil-mc-make-and-goto-next-match :exit nil)
    ("p" evil-mc-make-and-goto-prev-match :exit nil)
    ("N" evil-mc-skip-and-goto-next-match :exit nil)
    ("P" evil-mc-skip-and-goto-prev-match :exit nil)
    ("j" evil-mc-make-cursor-move-next-line :exit nil)
    ("k" evil-mc-make-cursor-move-prev-line :exit nil)
    ("H" evil-mc-make-and-goto-first-cursor :exit nil)
    ("L" evil-mc-make-and-goto-last-cursor :exit nil)
    ("u" evil-mc-undo-last-added-cursor :exit nil)
    ("r" evil-mc-resume-cursors)
    ("s" evil-mc-pause-cursors)
    ("O" evil-mc-undo-all-cursors)
    ("q" evil-mc-undo-all-cursors))

  (evil-define-key* '(normal visual) 'global
    (kbd "M") 'hydra-evil-mc/body)

  (evil-define-key* 'visual evil-mc-key-map
    "A" 'evil-mc-make-cursor-in-visual-selection-end
    "I" 'evil-mc-make-cursor-in-visual-selection-beg))


;; Keybinds that have no Emacs+evil analogues (i.e. don't exist):
;;   zu{q,w} - undo last marking

(map! :v  "@"     #'+evil:apply-macro
      :m  [C-i]   #'evil-jump-forward

      ;; implement dictionary keybinds
      ;; evil already defines 'z=' to `ispell-word' = correct word at point
      (:when (modulep! :checkers spell)
       :n  "zg"   #'+spell/add-word
       :n  "zw"   #'+spell/remove-word
       :m  "[s"   #'+spell/previous-error
       :m  "]s"   #'+spell/next-error)

      ;; ported from vim-unimpaired
      :n  "] SPC" #'+evil/insert-newline-below
      :n  "[ SPC" #'+evil/insert-newline-above
      :n  "]b"    #'next-buffer
      :n  "[b"    #'previous-buffer
      :n  "]f"    #'+evil/next-file
      :n  "[f"    #'+evil/previous-file
      :m  "]u"    #'+evil:url-encode
      :m  "[u"    #'+evil:url-decode
      :m  "]y"    #'+evil:c-string-encode
      :m  "[y"    #'+evil:c-string-decode
      (:when (modulep! :lang web)
       :m "]x"   #'+web:encode-html-entities
       :m "[x"   #'+web:decode-html-entities)
      (:when (modulep! :ui vc-gutter)
       :m "]d"   #'+vc-gutter/next-hunk
       :m "[d"   #'+vc-gutter/previous-hunk)
      (:when (modulep! :ui hl-todo)
       :m "]t"   #'hl-todo-next
       :m "[t"   #'hl-todo-previous)
      (:when (modulep! :ui workspaces)
       :n "gt"   #'+workspace:switch-next
       :n "gT"   #'+workspace:switch-previous
       :n "]w"   #'+workspace/switch-right
       :n "[w"   #'+workspace/switch-left)
      (:when (modulep! :ui tabs)
       :n "gt"   #'+tabs:next-or-goto
       :n "gT"   #'+tabs:previous-or-goto)

      ;; custom vim-unmpaired-esque keys
      :m  "]#"    #'+evil/next-preproc-directive
      :m  "[#"    #'+evil/previous-preproc-directive
      :m  "]a"    #'evil-forward-arg
      :m  "[a"    #'evil-backward-arg
      :m  "]c"    #'+evil/next-comment
      :m  "[c"    #'+evil/previous-comment
      :m  "]e"    #'next-error
      :m  "[e"    #'previous-error
      :n  "]F"    #'+evil/next-frame
      :n  "[F"    #'+evil/previous-frame
      :m  "]h"    #'outline-next-visible-heading
      :m  "[h"    #'outline-previous-visible-heading
      :m  "]m"    #'+evil/next-beginning-of-method
      :m  "[m"    #'+evil/previous-beginning-of-method
      :m  "]M"    #'+evil/next-end-of-method
      :m  "[M"    #'+evil/previous-end-of-method
      :n  "[o"    #'+evil/insert-newline-above
      :n  "]o"    #'+evil/insert-newline-below
      :n  "gp"    #'+evil/reselect-paste
      :v  "gp"    #'+evil/alt-paste
      :nv "g@"    #'+evil:apply-macro
      :nv "gc"    #'evilnc-comment-operator
      :nv "gO"    #'imenu
      :nv "gy"    #'+evil:yank-unindented
      (:when (modulep! :tools lookup)
       :nv "K"   #'+lookup/documentation
       :nv "gd"  #'+lookup/definition
       :nv "gD"  #'+lookup/references
       :nv "gf"  #'+lookup/file
       :nv "gI"  #'+lookup/implementations
       :nv "gA"  #'+lookup/assignments)
      (:when (modulep! :tools eval)
       :nv "gr"  #'+eval:region
       :n  "gR"  #'+eval/buffer
       :v  "gR"  #'+eval:replace-region
       ;; Restore these keybinds, since the blacklisted/overwritten gr/gR will
       ;; undo them:
       (:after helpful
        :map helpful-mode-map
        :n "gr" #'helpful-update)
       (:after compile
        :map (compilation-mode-map compilation-minor-mode-map)
        :n "gr" #'recompile)
       (:after dired
        :map dired-mode-map
        :n "gr" #'revert-buffer)
       (:after notmuch
        :map notmuch-common-keymap
        :n "gr" #'notmuch-refresh-this-buffer
        :n "gR" #'notmuch-poll-and-refresh-this-buffer)
       (:after elfeed
        :map elfeed-search-mode-map
        :n "gr" #'elfeed-search-update--force
        :n "gR" #'elfeed-search-fetch))

      ;; custom evil keybinds
      :nv "zn"    #'+evil:narrow-buffer
      :n  "zN"    #'doom/widen-indirectly-narrowed-buffer
      :n  "zx"    #'kill-current-buffer
      :n  "ZX"    #'doom/save-and-kill-buffer
      ;; don't leave visual mode after shifting
      :v  "<"     #'+evil/shift-left  ; vnoremap < <gv
      :v  ">"     #'+evil/shift-right  ; vnoremap > >gv

      ;; window management (prefix "C-w")
      (:map evil-window-map
       ;; Navigation
       "C-h"     #'evil-window-left
       "C-j"     #'evil-window-down
       "C-k"     #'evil-window-up
       "C-l"     #'evil-window-right
       "C-w"     #'other-window
       ;; Extra split commands
       "S"       #'+evil/window-split-and-follow
       "V"       #'+evil/window-vsplit-and-follow
       ;; Swapping windows
       "H"       #'+evil/window-move-left
       "J"       #'+evil/window-move-down
       "K"       #'+evil/window-move-up
       "L"       #'+evil/window-move-right
       "C-S-w"   #'ace-swap-window
       ;; Window undo/redo
       (:prefix "m"
        "m"       #'doom/window-maximize-buffer
        "v"       #'doom/window-maximize-vertically
        "s"       #'doom/window-maximize-horizontally)
       "u"       #'winner-undo
       "C-u"     #'winner-undo
       "C-r"     #'winner-redo
       "o"       #'doom/window-enlargen
       ;; Delete window
       "d"       #'evil-window-delete
       "C-C"     #'ace-delete-window
       "T"       #'tear-off-window)

      ;; evil-lion
      :n "gl" #'evil-lion-left
      :n "gL" #'evil-lion-right
      :v "gl" #'evil-lion-left
      :v "gL" #'evil-lion-right

      ;; Omni-completion
      (:when (modulep! :completion company)
       (:prefix "C-x"
        :i "C-l"    #'+company/whole-lines
        :i "C-k"    #'+company/dict-or-keywords
        :i "C-f"    #'company-files
        :i "C-]"    #'company-etags
        :i "s"      #'company-ispell
        :i "C-s"    #'company-yasnippet
        :i "C-o"    #'company-capf
        :i "C-n"    #'+company/dabbrev
        :i "C-p"    #'+company/dabbrev-code-previous)))
