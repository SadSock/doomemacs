;; -*- no-byte-compile: t; -*-
;;; lang/cc/packages.el

(if (modulep! +lsp)
    (unless (modulep! :tools lsp +eglot)
      ;; ccls package is necessary only for lsp-mode.
      (package! ccls :pin "29d231590fad39b4d658d9262859e60669edb9b0"))
  )
