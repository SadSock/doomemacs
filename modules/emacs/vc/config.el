;;; emacs/vc/config.el -*- lexical-binding: t; -*-

;; Remove RCS, CVS, SCCS, SRC, and Bzr, because it's a lot less work for vc to
;; check them all (especially in TRAMP buffers), and who uses any of these in
;; 2021, amirite?
(setq-default vc-handled-backends '(SVN Git Hg))

(when IS-WINDOWS
  (setenv "GIT_ASKPASS" "git-gui--askpass"))

;; In case the user is using `bug-reference-mode'
(map! :when (fboundp 'bug-reference-mode)
      :map bug-reference-map
      "RET" (cmds! (and (bound-and-true-p evil-mode)
                        (evil-normal-state-p))
                   #'bug-reference-push-button))

(after! log-view
  (set-evil-initial-state!
    '(log-view-mode
      vc-git-log-view-mode
      vc-hg-log-view-mode
      vc-bzr-log-view-mode
      vc-svn-log-view-mode)
    'emacs)
  (map! :map log-view-mode-map
        "j" #'log-view-msg-next
        "k" #'log-view-msg-prev))


(after! vc-annotate
  (set-popup-rules!
    '(("^\\*vc-diff" :select nil)   ; *vc-diff*
      ("^\\*vc-change" :select t))) ; *vc-change-log*
  (set-evil-initial-state! 'vc-annotate-mode 'normal)

  ;; Clean up after itself
  (define-key vc-annotate-mode-map [remap quit-window] #'kill-current-buffer))


(after! vc-dir
  (set-evil-initial-state! 'vc-dir-mode 'emacs))

