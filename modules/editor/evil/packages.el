;; -*- no-byte-compile: t; -*-
;;; editor/evil/packages.el

(package! evil :pin "2ce03d412c4e93b0b89eb43d796c991806415b8a")
(package! evil-lion :pin "a55eb647422342f6b1cf867f797b060b3645d9d8")
(package! evil-traces :pin "290b5323542c46af364ec485c8ec9000040acf90")
(package! evil-visualstar :pin "06c053d8f7381f91c53311b1234872ca96ced752")

(when (modulep! +everywhere)
  ;; `evil-collection-neotree' uses the `neotree-make-executor' macro, but this
  ;; requires neotree be available during byte-compilation (while installing).
  (when (modulep! :ui neotree)
    (package! neotree)
    (autoload 'neotree-make-executor "neotree" nil nil 'macro))

  (package! evil-collection :pin "aaf3e0038e9255659fe0455729239c08498c4c0b"))
