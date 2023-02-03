;; -*- no-byte-compile: t; -*-
;;; lang/python/packages.el

;; Major modes

;; LSP
(when (modulep! +lsp)
  (unless (modulep! :tools lsp +eglot)
    (if (modulep! +pyright)
        (package! lsp-pyright :pin "4cd2adbb32287278d9d9da59a3212a53ecdf8036")
      (package! lsp-python-ms :pin "f8e7c4bcaefbc3fd96e1ca53d17589be0403b828"))))
