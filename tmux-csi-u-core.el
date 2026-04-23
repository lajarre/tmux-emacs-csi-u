;;; tmux-csi-u-core.el --- tmux CSI-u core helpers -*- lexical-binding: t; -*-

;; Copyright (C) 2026 lajarre

;; Author: lajarre <1884912+lajarre@users.noreply.github.com>
;; Maintainer: lajarre <1884912+lajarre@users.noreply.github.com>
;; Keywords: terminals, tools
;; URL: https://github.com/lajarre/tmux-csi-u.el
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Internal helpers shared by the public `tmux-csi-u' API.  Provides
;; the candidate-table installer, `input-decode-map' lookup helpers,
;; package-owned binding tracking, conflict record construction, and
;; human-readable formatting for the enable report.
;;
;; This file is not a public entrypoint; callers should use
;; `tmux-csi-u' instead.

;;; Code:

(require 'subr-x)
(require 'tmux-csi-u-data)

(defun tmux-csi-u-core-special-table ()
  "Return a copy of the explicit special-key mapping table."
  (tmux-csi-u-data-special-table))

(defun tmux-csi-u-core--escaped-sequence (sequence)
  "Render SEQUENCE with spec-style escaped ESC."
  (replace-regexp-in-string "\e" "\\\\e" sequence t t))

(defun tmux-csi-u-core--printed-binding (binding)
  "Render BINDING with a readable Lisp printed representation."
  (prin1-to-string binding))

(defun tmux-csi-u-core--readable-binding (binding)
  "Render BINDING for human-readable summaries."
  (or (and (integerp binding)
           (condition-case nil
               (let ((description (key-description (vector binding))))
                 (and (> (length description) 0) description))
             (error nil)))
      (and (or (stringp binding) (vectorp binding))
           (condition-case nil
               (let ((description (key-description binding)))
                 (and (> (length description) 0) description))
             (error nil)))
      (prin1-to-string binding)))

(defun tmux-csi-u-core--humanize-printed-binding (binding)
  "Render printed BINDING for human-readable summaries."
  (condition-case nil
      (let* ((parsed (read-from-string binding))
             (value (car parsed))
             (end (cdr parsed)))
        (if (= end (length binding))
            (tmux-csi-u-core--readable-binding value)
          binding))
    (error binding)))

(defun tmux-csi-u-core--canonical-binding (binding)
  "Return BINDING normalized to comparable key-sequence semantics."
  (cond
   ((integerp binding) (list binding))
   ((or (stringp binding) (vectorp binding))
    (listify-key-sequence binding))
   (t binding)))

(defun tmux-csi-u-core--binding-match-p (left right)
  "Return non-nil when LEFT and RIGHT encode the same key sequence."
  (equal (tmux-csi-u-core--canonical-binding left)
         (tmux-csi-u-core--canonical-binding right)))

(defun tmux-csi-u-core--sequence-with-sentinel (sequence)
  "Return SEQUENCE extended with a trailing sentinel event."
  (if (stringp sequence)
      (concat sequence "\0")
    (vconcat sequence [0])))

(defun tmux-csi-u-core--exact-integer-binding-p (keymap sequence)
  "Return non-nil when KEYMAP gives SEQUENCE an exact integer binding."
  (equal (lookup-key keymap
                     (tmux-csi-u-core--sequence-with-sentinel sequence))
         (length sequence)))

(defun tmux-csi-u-core--lookup-exact-binding (keymap sequence)
  "Return KEYMAP's exact binding for SEQUENCE, or nil when absent."
  (let ((binding (lookup-key keymap sequence)))
    (if (and (integerp binding)
             (not (tmux-csi-u-core--exact-integer-binding-p
                   keymap sequence)))
        nil
      binding)))

(defun tmux-csi-u-core--blocking-prefix-binding (keymap sequence)
  "Return KEYMAP's non-prefix binding that blocks defining SEQUENCE."
  (let ((index 1)
        blocking)
    (while (and (< index (length sequence)) (null blocking))
      (let ((binding (tmux-csi-u-core--lookup-exact-binding
                      keymap (substring sequence 0 index))))
        (when (and binding
                   (not (keymapp binding)))
          (setq blocking binding)))
      (setq index (1+ index)))
    blocking))

(defun tmux-csi-u-core--conflict (sequence existing candidate)
  "Build a conflict plist for SEQUENCE, EXISTING, and CANDIDATE.
The plist matches the public report contract."
  (list :sequence (tmux-csi-u-core--escaped-sequence sequence)
        :existing (tmux-csi-u-core--printed-binding existing)
        :candidate (tmux-csi-u-core--printed-binding candidate)))

(defun tmux-csi-u-core--status (support-signal installed conflicts unsupported)
  "Compute the report status.
Use SUPPORT-SIGNAL, INSTALLED, CONFLICTS, and UNSUPPORTED."
  (cond
   ((eq support-signal 'unsupported) 'skipped)
   ((and (zerop installed) (zerop conflicts) (zerop unsupported)) 'already-enabled)
   ((and (> installed 0) (zerop conflicts) (zerop unsupported)) 'installed)
   (t 'partial)))

(defconst tmux-csi-u-core--missing-owned-binding
  (make-symbol "tmux-csi-u-core--missing-owned-binding")
  "Sentinel for absent package-owned bindings.")

(defun tmux-csi-u-core--owned-binding (owned-bindings sequence)
  "Return the OWNED-BINDINGS entry for SEQUENCE."
  (if owned-bindings
      (gethash sequence owned-bindings
               tmux-csi-u-core--missing-owned-binding)
    tmux-csi-u-core--missing-owned-binding))

(defun tmux-csi-u-core--owned-binding-instance-p (existing owned)
  "Return non-nil when EXISTING is the package-installed OWNED binding.
Intentionally conservative: only object identity counts as proof
that the package still owns the current binding."
  (and (not (eq owned tmux-csi-u-core--missing-owned-binding))
       (or (stringp owned) (vectorp owned) (consp owned))
       (eq existing owned)))

(defun tmux-csi-u-core--record-owned-binding (owned-bindings sequence binding)
  "Record in OWNED-BINDINGS that SEQUENCE maps to BINDING.
This marks BINDING as the exact package-owned binding for SEQUENCE."
  (when owned-bindings
    (puthash sequence binding owned-bindings)))

(defun tmux-csi-u-core--forget-owned-binding (owned-bindings sequence)
  "Forget OWNED-BINDINGS' package-owned binding for SEQUENCE, if any."
  (when owned-bindings
    (remhash sequence owned-bindings)))

(defun tmux-csi-u-core-install-table (table keymap support-signal &optional owned-bindings)
  "Install TABLE into KEYMAP according to SUPPORT-SIGNAL.
OWNED-BINDINGS tracks bindings previously installed by the package.
Return a report plist matching the public enable schema."
  (let ((candidate-count (length table))
        (installed 0)
        (already-matching 0)
        (preserved-conflicts 0)
        conflicts)
    (if (eq support-signal 'unsupported)
        (setq conflicts nil)
      (dolist (entry table)
        (let* ((sequence (car entry))
               (candidate (cdr entry))
               (existing (tmux-csi-u-core--lookup-exact-binding
                          keymap sequence))
               (owned (tmux-csi-u-core--owned-binding
                       owned-bindings sequence)))
          (cond
           ((null existing)
            (if-let ((blocking (tmux-csi-u-core--blocking-prefix-binding
                                keymap sequence)))
                (progn
                  (setq preserved-conflicts (1+ preserved-conflicts))
                  (push (tmux-csi-u-core--conflict
                         sequence blocking candidate)
                        conflicts)
                  (tmux-csi-u-core--forget-owned-binding
                   owned-bindings sequence))
              (define-key keymap sequence candidate)
              (setq installed (1+ installed))
              (tmux-csi-u-core--record-owned-binding
               owned-bindings sequence candidate)))
           ((tmux-csi-u-core--binding-match-p existing candidate)
            (setq already-matching (1+ already-matching))
            (when (and (not (eq owned tmux-csi-u-core--missing-owned-binding))
                       (not (tmux-csi-u-core--owned-binding-instance-p
                             existing owned)))
              (tmux-csi-u-core--forget-owned-binding
               owned-bindings sequence)))
           ((and (not (eq owned tmux-csi-u-core--missing-owned-binding))
                 (tmux-csi-u-core--owned-binding-instance-p
                  existing owned))
            (define-key keymap sequence candidate)
            (setq installed (1+ installed))
            (tmux-csi-u-core--record-owned-binding
             owned-bindings sequence candidate))
           (t
            (setq preserved-conflicts (1+ preserved-conflicts))
            (push (tmux-csi-u-core--conflict sequence existing candidate)
                  conflicts)
            (tmux-csi-u-core--forget-owned-binding
             owned-bindings sequence)))))
      (when owned-bindings
        (let (orphans)
          (maphash (lambda (sequence owned)
                     (unless (assoc sequence table)
                       (push (cons sequence owned) orphans)))
                   owned-bindings)
          (dolist (orphan orphans)
            (let* ((sequence (car orphan))
                   (owned (cdr orphan))
                   (existing (tmux-csi-u-core--lookup-exact-binding
                              keymap sequence)))
              (when (tmux-csi-u-core--owned-binding-instance-p
                     existing owned)
                (define-key keymap sequence nil))
              (tmux-csi-u-core--forget-owned-binding owned-bindings sequence))))))
    (let ((unsupported-or-skipped (if (eq support-signal 'unsupported)
                                      candidate-count
                                    0)))
      (list :status (tmux-csi-u-core--status
                     support-signal installed preserved-conflicts unsupported-or-skipped)
            :support-signal support-signal
            :installed installed
            :already-matching already-matching
            :preserved-conflicts preserved-conflicts
            :unsupported-or-skipped unsupported-or-skipped
            :conflicts (nreverse conflicts)))))

(provide 'tmux-csi-u-core)
;;; tmux-csi-u-core.el ends here
