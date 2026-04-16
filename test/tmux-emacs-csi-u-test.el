;;; tmux-emacs-csi-u-test.el --- compatibility loader -*- lexical-binding: t; -*-

;;; Commentary:

;; Compatibility loader for the renamed tmux-csi-u test suite.

;;; Code:

(load (expand-file-name "tmux-csi-u-test.el"
                        (file-name-directory (or load-file-name buffer-file-name)))
      nil 'nomessage)

;;; tmux-emacs-csi-u-test.el ends here
