;;; tmux-csi-u.el --- Tmux CSI-u decoder -*- lexical-binding: t; -*-

;; Copyright (C) 2026 lajarre

;; Author: lajarre <1884912+lajarre@users.noreply.github.com>
;; Maintainer: lajarre <1884912+lajarre@users.noreply.github.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "25.1"))
;; Keywords: terminals, tools
;; URL: https://github.com/lajarre/tmux-csi-u.el
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; tmux-csi-u installs explicit `input-decode-map' entries so terminal
;; Emacs can decode tmux CSI-u key sequences (ESC [ keycode ; modifier u)
;; that neither Emacs native tmux/xterm input translation nor `xterm.el'
;; handle on the tmux TTY path.
;;
;; Scope: the delta over the native decode, not a replacement.  Pi users
;; keep tmux on `extended-keys-format csi-u' and rely on this package to
;; recover shifted space, modified backspace, modified escape, the
;; `M-<return>' / `M-<tab>' gap, and the shifted punctuation family
;; captured in `test/fixture/punctuation.json'.
;;
;; Usage:
;;
;;   (require 'tmux-csi-u)
;;
;; `tmux-csi-u-auto-enable' defaults to t and installs via
;; `tty-setup-hook' when the frame is a supported tmux TTY.  Manual
;; activation is `M-x tmux-csi-u-enable'.  `M-x tmux-csi-u-describe'
;; renders the latest enable report for debugging.
;;
;; Collision policy is warn-and-preserve: conflicting external bindings
;; stay in place and are surfaced via `display-warning' and the report
;; buffer.  User-local mappings applied after package defaults go in
;; `tmux-csi-u-local-overrides'.
;;
;; See README.md for the full install, migration, and verification
;; matrix, and `doc/ref/protocol.md' for the tmux CSI-u wire shape.

;;; Code:

(require 'subr-x)
(require 'tmux-csi-u-data)
(require 'tmux-csi-u-core)

(defgroup tmux-csi-u nil
  "Decode tmux CSI-u key sequences in terminal Emacs."
  :group 'keyboard)

(defconst tmux-csi-u--supported-tty-types '("tmux" "tmux-256color")
  "TTY types that count as tmux evidence.")

(defun tmux-csi-u--tty-setup-enable ()
  "Enable tmux CSI-u decoding for the current tty frame."
  (tmux-csi-u-enable (selected-frame)))

(defun tmux-csi-u--sync-tty-setup-hook (enabled)
  "Synchronize `tty-setup-hook' according to ENABLED."
  (remove-hook 'tty-setup-hook #'tmux-csi-u--tty-setup-enable)
  (when enabled
    (add-hook 'tty-setup-hook #'tmux-csi-u--tty-setup-enable t)))

(defun tmux-csi-u--set-auto-enable (symbol value)
  "Set SYMBOL to VALUE and synchronize `tty-setup-hook'."
  (set-default symbol value)
  (tmux-csi-u--sync-tty-setup-hook value))

;;;###autoload
(defcustom tmux-csi-u-auto-enable t
  "Enable tmux CSI-u decoding automatically from `tty-setup-hook'."
  :type 'boolean
  :set #'tmux-csi-u--set-auto-enable
  :group 'tmux-csi-u)

;;;###autoload
(defcustom tmux-csi-u-force-enable nil
  "Force-enable tmux CSI-u support for daemon/client edge cases."
  :type 'boolean
  :group 'tmux-csi-u)

;;;###autoload
(defcustom tmux-csi-u-local-overrides nil
  "Extra CSI-u mappings applied after the package defaults.

Each entry is a cons cell of the form (SEQUENCE . BINDING).  A local
entry with the same SEQUENCE as a package mapping replaces the package
candidate before installation."
  :type '(repeat (cons (string :tag "CSI-u sequence")
                       (sexp :tag "Binding")))
  :group 'tmux-csi-u)

(defvar tmux-csi-u-last-report nil
  "Latest report returned by `tmux-csi-u-enable'.")

(defvar tmux-csi-u--owned-bindings-by-keymap nil
  "Package-owned CSI-u bindings keyed by terminal-local decode maps.")

(defun tmux-csi-u--owned-bindings-cache ()
  "Return the per-keymap cache for package-owned CSI-u bindings."
  (unless (and (hash-table-p tmux-csi-u--owned-bindings-by-keymap)
               (eq (hash-table-weakness
                    tmux-csi-u--owned-bindings-by-keymap)
                   'key))
    (let ((existing-cache tmux-csi-u--owned-bindings-by-keymap)
          (cache (make-hash-table :test 'eq :weakness 'key)))
      (when (hash-table-p existing-cache)
        (maphash (lambda (key value)
                   (puthash key value cache))
                 existing-cache))
      (setq tmux-csi-u--owned-bindings-by-keymap cache)))
  tmux-csi-u--owned-bindings-by-keymap)

(defvar tmux-csi-u--support-state-by-report
  (make-hash-table :test 'eq :weakness 'key)
  "Support-state sidecar keyed by enable report plists.")

(defun tmux-csi-u--support-state (&optional frame)
  "Return the support state plist for FRAME."
  (let ((frame (or frame (selected-frame))))
    (cond
     ((display-graphic-p frame)
      (list :support-signal 'unsupported
            :unsupported-reason 'graphical-frame))
     ((not (terminal-live-p (frame-terminal frame)))
      (list :support-signal 'unsupported
            :unsupported-reason 'dead-terminal))
     (tmux-csi-u-force-enable
      (list :support-signal 'force-enable))
     (t
      (let ((current-tty-type (tty-type frame)))
        (if (member current-tty-type tmux-csi-u--supported-tty-types)
            (list :support-signal 'tty-type)
          (list :support-signal 'unsupported
                :unsupported-reason 'non-tmux-tty
                :tty-type current-tty-type)))))))

(defun tmux-csi-u--support-signal (&optional frame)
  "Return the support signal for FRAME."
  (plist-get (tmux-csi-u--support-state frame) :support-signal))

;;;###autoload
(defun tmux-csi-u-supported-p (&optional frame)
  "Return non-nil when FRAME is a supported tmux TTY context."
  (not (eq (tmux-csi-u--support-signal frame) 'unsupported)))

(defun tmux-csi-u--warn-on-new-conflicts (frame conflicts)
  "Warn once on FRAME's live terminal for any new CONFLICTS."
  (let* ((terminal (frame-terminal frame))
         (param 'tmux-csi-u--warned-conflicts)
         (seen (copy-sequence (or (terminal-parameter terminal param) '())))
         fresh)
    (dolist (conflict conflicts)
      (let ((signature (prin1-to-string conflict)))
        (unless (member signature seen)
          (push signature fresh)
          (push signature seen))))
    (when fresh
      (set-terminal-parameter terminal param seen)
      (display-warning
       'tmux-csi-u
       (format
        "%d CSI-u conflicts preserved; inspect (tmux-csi-u-describe) for details"
        (length conflicts))
       :warning))))

(defun tmux-csi-u--frame-input-decode-map (frame)
  "Return `input-decode-map' for FRAME's terminal."
  (with-selected-frame frame
    input-decode-map))

(defun tmux-csi-u--candidate-table ()
  "Return the current candidate table."
  (tmux-csi-u-data-build-candidate-table
   tmux-csi-u-local-overrides))

(defun tmux-csi-u--owned-bindings (keymap)
  "Return package-owned binding state for KEYMAP."
  (let ((cache (tmux-csi-u--owned-bindings-cache)))
    (or (gethash keymap cache)
        (let ((owned-bindings (make-hash-table :test 'equal)))
          (puthash keymap owned-bindings cache)
          owned-bindings))))

(defun tmux-csi-u--annotate-report-with-support-state (report support-state)
  "Annotate REPORT with SUPPORT-STATE and return REPORT."
  (puthash report support-state tmux-csi-u--support-state-by-report)
  report)

;;;###autoload
(defun tmux-csi-u-enable (&optional frame)
  "Install explicit CSI-u overrides for FRAME's terminal.
Return the enable report plist."
  (interactive)
  (let* ((frame (or frame (selected-frame)))
         (support-state (tmux-csi-u--support-state frame))
         (support-signal (plist-get support-state :support-signal))
         (candidate-table (tmux-csi-u--candidate-table))
         (keymap (unless (eq support-signal 'unsupported)
                   (tmux-csi-u--frame-input-decode-map frame)))
         (owned-bindings (and keymap
                              (tmux-csi-u--owned-bindings keymap)))
         (report (tmux-csi-u--annotate-report-with-support-state
                  (tmux-csi-u-core-install-table
                   candidate-table
                   keymap
                   support-signal
                   owned-bindings)
                  support-state)))
    (setq tmux-csi-u-last-report report)
    (when-let ((conflicts (plist-get report :conflicts)))
      (tmux-csi-u--warn-on-new-conflicts frame conflicts))
    report))

(defun tmux-csi-u--render-skip-reason (report)
  "Render the unsupported activation reason from REPORT."
  (let ((support-state (gethash report tmux-csi-u--support-state-by-report)))
    (pcase (plist-get support-state :unsupported-reason)
      ('graphical-frame
       "skip-reason: graphical-frame\n")
      ('dead-terminal
       "skip-reason: dead-terminal\n")
      ('non-tmux-tty
       (concat
        "skip-reason: non-tmux-tty\n"
        (format "tty-type: %s\n" (plist-get support-state :tty-type))))
      (_ ""))))

(defun tmux-csi-u--render-report (report)
  "Render REPORT for humans."
  (if (null report)
      "No enable report recorded yet.\n"
    (concat
     (format "status: %s\n" (plist-get report :status))
     (format "support-signal: %s\n" (plist-get report :support-signal))
     (tmux-csi-u--render-skip-reason report)
     (format "installed: %d\n" (plist-get report :installed))
     (format "already-matching: %d\n" (plist-get report :already-matching))
     (format "preserved-conflicts: %d\n" (plist-get report :preserved-conflicts))
     (format "unsupported-or-skipped: %d\n" (plist-get report :unsupported-or-skipped))
     (if-let ((conflicts (plist-get report :conflicts)))
         (concat
          "conflicts:\n"
          (mapconcat
           (lambda (conflict)
             (format "- %s existing=%s candidate=%s"
                     (plist-get conflict :sequence)
                     (tmux-csi-u-core--humanize-printed-binding
                      (plist-get conflict :existing))
                     (tmux-csi-u-core--humanize-printed-binding
                      (plist-get conflict :candidate))))
           conflicts
           "\n")
          "\n")
       ""))))

;;;###autoload
(defun tmux-csi-u-describe ()
  "Return the latest enable report.
When called interactively, render it in `*tmux-csi-u*'."
  (interactive)
  (when (called-interactively-p 'interactive)
    (with-current-buffer (get-buffer-create "*tmux-csi-u*")
      (special-mode)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (tmux-csi-u--render-report tmux-csi-u-last-report))
        (goto-char (point-min)))
      (display-buffer (current-buffer))))
  tmux-csi-u-last-report)

(tmux-csi-u--sync-tty-setup-hook tmux-csi-u-auto-enable)

(provide 'tmux-csi-u)
;;; tmux-csi-u.el ends here
