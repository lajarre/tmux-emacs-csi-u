;;; tmux-emacs-csi-u.el --- compatibility shim for tmux-csi-u -*- lexical-binding: t; -*-

;;; Commentary:

;; Compatibility shim for the renamed tmux-csi-u package.

;;; Code:

(require 'tmux-csi-u)

(defvaralias 'tmux-emacs-csi-u-auto-enable 'tmux-csi-u-auto-enable)
(make-obsolete-variable 'tmux-emacs-csi-u-auto-enable
                        'tmux-csi-u-auto-enable
                        "0.1.0")
(defvaralias 'tmux-emacs-csi-u-force-enable 'tmux-csi-u-force-enable)
(make-obsolete-variable 'tmux-emacs-csi-u-force-enable
                        'tmux-csi-u-force-enable
                        "0.1.0")
(defvaralias 'tmux-emacs-csi-u-local-overrides 'tmux-csi-u-local-overrides)
(make-obsolete-variable 'tmux-emacs-csi-u-local-overrides
                        'tmux-csi-u-local-overrides
                        "0.1.0")
(defvaralias 'tmux-emacs-csi-u-last-report 'tmux-csi-u-last-report)
(make-obsolete-variable 'tmux-emacs-csi-u-last-report
                        'tmux-csi-u-last-report
                        "0.1.0")
(defvaralias 'tmux-emacs-csi-u--owned-bindings-by-keymap
  'tmux-csi-u--owned-bindings-by-keymap)
(make-obsolete-variable 'tmux-emacs-csi-u--owned-bindings-by-keymap
                        'tmux-csi-u--owned-bindings-by-keymap
                        "0.1.0")
(defvaralias 'tmux-emacs-csi-u--support-state-by-report
  'tmux-csi-u--support-state-by-report)
(make-obsolete-variable 'tmux-emacs-csi-u--support-state-by-report
                        'tmux-csi-u--support-state-by-report
                        "0.1.0")
(defvaralias 'tmux-emacs-csi-u--supported-tty-types
  'tmux-csi-u--supported-tty-types)
(make-obsolete-variable 'tmux-emacs-csi-u--supported-tty-types
                        'tmux-csi-u--supported-tty-types
                        "0.1.0")

(defgroup tmux-emacs-csi-u nil
  "Compatibility group for `tmux-csi-u'."
  :group 'tmux-csi-u)

(provide 'tmux-emacs-csi-u)
;;; tmux-emacs-csi-u.el ends here
