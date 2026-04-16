;;; tmux-csi-u-data.el --- tmux CSI-u mapping data -*- lexical-binding: t; -*-

;;; Commentary:

;; Mapping data and candidate-table composition for tmux-csi-u.

;;; Code:

(defconst tmux-csi-u-data--modifier-prefixes
  '((2 . "S-")
    (3 . "M-")
    (4 . "M-S-")
    (5 . "C-")
    (6 . "C-S-")
    (7 . "C-M-")
    (8 . "C-M-S-"))
  "Exact tmux CSI-u modifier prefixes for generated printable coverage.")

(defun tmux-csi-u-data-modifier-prefix (modifier)
  "Return the canonical event prefix for tmux CSI-u MODIFIER."
  (alist-get modifier tmux-csi-u-data--modifier-prefixes))

(defun tmux-csi-u-data--printable-base-token (keycode)
  "Return the canonical base token for printable ASCII KEYCODE."
  (if (= keycode 32)
      "SPC"
    (char-to-string keycode)))

(defun tmux-csi-u-data--printable-sequence (keycode modifier)
  "Return the tmux CSI-u sequence for printable KEYCODE and MODIFIER."
  (format "\e[%d;%du" keycode modifier))

(defun tmux-csi-u-data--generated-printable-skip-entry (keycode modifier reason)
  "Return a generated printable skip-list entry.
KEYCODE and MODIFIER identify the skipped sequence and REASON explains why."
  (list :keycode keycode
        :modifier modifier
        :sequence (tmux-csi-u-data--printable-sequence keycode modifier)
        :reason reason))

(defun tmux-csi-u-data--printable-binding (keycode modifier)
  "Return the canonical generated printable event for KEYCODE and MODIFIER."
  (let ((prefix (tmux-csi-u-data-modifier-prefix modifier)))
    (unless prefix
      (error "Unsupported tmux CSI-u modifier: %S" modifier))
    (kbd (concat prefix
                 (tmux-csi-u-data--printable-base-token keycode)))))

(defun tmux-csi-u-data--printable-event-description (keycode modifier)
  "Return the canonical printable event description for KEYCODE and MODIFIER."
  (key-description (tmux-csi-u-data--printable-binding keycode modifier)))

(defun tmux-csi-u-data--xterm-native-exact-skip-reason (keycode modifier)
  "Return a skip reason when xterm.el already decodes KEYCODE and MODIFIER."
  (when (memq keycode
              (alist-get modifier '((3 . (32))
                                    (5 . (39 44 45 46 47 48 49 57 59 61 92))
                                    (7 . (32 39 44 45 46 47 48 49 50 51 52 53
                                             54 55 56 57 59 61 92)))))
    (format "xterm.el decodes %s natively"
            (tmux-csi-u-data--printable-event-description keycode modifier))))

(defun tmux-csi-u-data--xterm-native-lossy-skip-reason (keycode modifier)
  "Return a skip reason when xterm.el collapses KEYCODE and MODIFIER."
  (when (memq keycode
              (alist-get modifier '((6 . (33 34 35 36 37 38 40 41 42 43 58 60 62 63))
                                    (8 . (33 34 35 36 37 38 40 41 42 43 58 60 62 63)))))
    (let ((collapsed-modifier (alist-get modifier '((6 . 5)
                                                    (8 . 7)))))
      (format "xterm.el collapses %s to %s"
              (tmux-csi-u-data--printable-event-description keycode modifier)
              (tmux-csi-u-data--printable-event-description keycode
                                                            collapsed-modifier)))))

(defun tmux-csi-u-data--generated-uppercase-control-fold-reason (keycode modifier)
  "Return a skip reason for lossy KBD folding.
This covers uppercase control KEYCODE for MODIFIER."
  (when (and (<= 65 keycode 90)
             (memq modifier '(5 6 7 8))
             (not (memq keycode '(73 77))))
    (let* ((prefix (tmux-csi-u-data-modifier-prefix modifier))
           (uppercase (char-to-string keycode))
           (lowercase (char-to-string (downcase keycode))))
      (format "kbd normalizes %s%s to %s%s"
              prefix uppercase prefix lowercase))))

(defun tmux-csi-u-data--generated-printable-skip-reason (keycode modifier)
  "Return the documented skip reason for printable KEYCODE and MODIFIER."
  (cond
   ((tmux-csi-u-data--xterm-native-exact-skip-reason keycode modifier))
   ((tmux-csi-u-data--xterm-native-lossy-skip-reason keycode modifier))
   ((and (= keycode 73) (= modifier 5)) "kbd normalizes C-I to TAB")
   ((and (= keycode 73) (= modifier 6)) "kbd normalizes C-S-I to S-TAB")
   ((and (= keycode 73) (= modifier 7)) "kbd normalizes C-M-I to M-TAB")
   ((and (= keycode 73) (= modifier 8)) "kbd normalizes C-M-S-I to M-S-TAB")
   ((and (= keycode 77) (= modifier 5)) "kbd normalizes C-M to RET")
   ((and (= keycode 77) (= modifier 6)) "kbd normalizes C-S-M to S-RET")
   ((and (= keycode 77) (= modifier 7)) "kbd normalizes C-M-M to M-RET")
   ((and (= keycode 77) (= modifier 8)) "kbd normalizes C-M-S-M to M-S-RET")
   ((and (= keycode 91) (= modifier 5)) "kbd normalizes C-[ to ESC")
   ((and (= keycode 91) (= modifier 6)) "kbd normalizes C-S-[ to S-ESC")
   ((and (= keycode 91) (= modifier 7)) "kbd normalizes C-M-[ to M-ESC")
   ((and (= keycode 91) (= modifier 8)) "kbd normalizes C-M-S-[ to M-S-ESC")
   ((and (= keycode 105) (= modifier 5)) "kbd normalizes C-i to TAB")
   ((and (= keycode 105) (= modifier 6)) "kbd normalizes C-S-i to S-TAB")
   ((and (= keycode 105) (= modifier 7)) "kbd normalizes C-M-i to M-TAB")
   ((and (= keycode 105) (= modifier 8)) "kbd normalizes C-M-S-i to M-S-TAB")
   ((and (= keycode 109) (= modifier 5)) "kbd normalizes C-m to RET")
   ((and (= keycode 109) (= modifier 6)) "kbd normalizes C-S-m to S-RET")
   ((and (= keycode 109) (= modifier 7)) "kbd normalizes C-M-m to M-RET")
   ((and (= keycode 109) (= modifier 8)) "kbd normalizes C-M-S-m to M-S-RET")
   (t (tmux-csi-u-data--generated-uppercase-control-fold-reason
       keycode modifier))))

(defconst tmux-csi-u-data--generated-printable-skip-list
  (let (entries)
    (dolist (keycode (number-sequence 32 126))
      (dolist (modifier '(2 3 4 5 6 7 8))
        (let ((reason (tmux-csi-u-data--generated-printable-skip-reason
                       keycode modifier)))
          (when reason
            (push (tmux-csi-u-data--generated-printable-skip-entry
                   keycode modifier reason)
                  entries)))))
    (nreverse entries))
  "Generated printable CSI-u pairs skipped because native decoding covers them.")

(defun tmux-csi-u-data--generated-printable-skip-p (keycode modifier)
  "Return non-nil when printable KEYCODE and MODIFIER are skipped."
  (and (tmux-csi-u-data--generated-printable-skip-reason
        keycode modifier)
       t))

(defun tmux-csi-u-data--printable-entry (keycode modifier)
  "Return the generated printable CSI-u mapping for KEYCODE and MODIFIER."
  (cons (tmux-csi-u-data--printable-sequence keycode modifier)
        (tmux-csi-u-data--printable-binding keycode modifier)))

(defconst tmux-csi-u-data--generated-printable-table
  (let (table)
    (dolist (keycode (number-sequence 32 126))
      (dolist (modifier '(2 3 4 5 6 7 8))
        (unless (tmux-csi-u-data--generated-printable-skip-p keycode modifier)
          (push (tmux-csi-u-data--printable-entry keycode modifier)
                table))))
    (nreverse table))
  "Generated printable ASCII tmux CSI-u coverage for keycodes 32..126.")

(defconst tmux-csi-u-data--shifted-punctuation-modifier-prefixes
  '((4 . "M-")
    (6 . "C-")
    (8 . "C-M-"))
  "Modifier prefixes for explicit local shifted punctuation overrides.")

(defconst tmux-csi-u-data--shifted-punctuation-capture
  '((59 . ":")
    (47 . "?")
    (46 . ">")
    (44 . "<")
    (39 . "\"")
    (91 . "{")
    (93 . "}")
    (92 . "|")
    (61 . "+")
    (45 . "_")
    (96 . "~"))
  "Canonical local shifted punctuation capture entries.")

(defun tmux-csi-u-data--shifted-punctuation-entry (keycode modifier event)
  "Return an explicit shifted punctuation override.
Use KEYCODE, MODIFIER, and EVENT."
  (let ((prefix (alist-get modifier
                           tmux-csi-u-data--shifted-punctuation-modifier-prefixes)))
    (unless prefix
      (error "Unsupported shifted punctuation modifier: %S" modifier))
    (cons (tmux-csi-u-data--printable-sequence keycode modifier)
          (kbd (concat prefix event)))))

(defconst tmux-csi-u-data--shifted-punctuation-table
  (let (table)
    (dolist (entry tmux-csi-u-data--shifted-punctuation-capture)
      (dolist (modifier '(4 6 8))
        (push (tmux-csi-u-data--shifted-punctuation-entry
               (car entry) modifier (cdr entry))
              table)))
    (nreverse table))
  "Explicit local shifted punctuation modifier overrides after generation.")

(defconst tmux-csi-u-data--special-table
  `(("\e[32;2u" . ,(kbd "SPC"))
    ("\e[32;5u" . ,(kbd "C-SPC"))
    ("\e[32;6u" . ,(kbd "C-S-SPC"))
    ("\e[32;8u" . ,(kbd "C-M-S-SPC"))
    ("\e[13;3u" . ,(kbd "M-<return>"))
    ("\e[13;8u" . ,(kbd "C-M-S-<return>"))
    ("\e[9;3u" . ,(kbd "M-<tab>"))
    ("\e[127;2u" . [backspace])
    ("\e[127;3u" . [M-backspace])
    ("\e[127;5u" . [C-backspace])
    ("\e[127;6u" . [C-S-backspace])
    ("\e[127;7u" . [C-M-backspace])
    ("\e[27;3u" . ,(kbd "M-ESC"))
    ("\e[27;5u" . [C-escape])
    ("\e[27;6u" . [C-S-escape])
    ("\e[59;2u" . [?:])
    ("\e[47;2u" . ,(kbd "?"))
    ("\e[46;2u" . ,(kbd ">"))
    ("\e[44;2u" . ,(kbd "<"))
    ("\e[39;2u" . ,(kbd "\""))
    ("\e[91;2u" . ,(kbd "{"))
    ("\e[93;2u" . ,(kbd "}"))
    ("\e[92;2u" . ,(kbd "|"))
    ("\e[61;2u" . ,(kbd "+"))
    ("\e[45;2u" . ,(kbd "_"))
    ("\e[96;2u" . ,(kbd "~"))
    ,@tmux-csi-u-data--shifted-punctuation-table)
  "Explicit v1 special-key CSI-u mappings and shifted punctuation overrides.")

(defun tmux-csi-u-data--copy-binding (binding)
  "Return a detached copy of BINDING when needed."
  (cond
   ((or (stringp binding) (vectorp binding))
    (copy-sequence binding))
   ((consp binding)
    (copy-tree binding))
   (t binding)))

(defun tmux-csi-u-data--copy-entry (entry)
  "Return a detached copy of mapping ENTRY."
  (cons (copy-sequence (car entry))
        (tmux-csi-u-data--copy-binding (cdr entry))))

(defun tmux-csi-u-data-generated-printable-table ()
  "Return a copy of the generated printable ASCII mapping table."
  (mapcar #'tmux-csi-u-data--copy-entry
          tmux-csi-u-data--generated-printable-table))

(defun tmux-csi-u-data-generated-printable-skip-list ()
  "Return a copy of the generated printable skip list."
  (mapcar #'copy-tree
          tmux-csi-u-data--generated-printable-skip-list))

(defun tmux-csi-u-data-special-table ()
  "Return a copy of the explicit special-key mapping table."
  (mapcar #'tmux-csi-u-data--copy-entry
          tmux-csi-u-data--special-table))

(defun tmux-csi-u-data--merge-tables (&rest tables)
  "Merge TABLES with later entries replacing earlier matching sequences."
  (let (merged)
    (dolist (table tables)
      (dolist (entry table)
        (setq merged (assoc-delete-all (car entry) merged))
        (push (tmux-csi-u-data--copy-entry entry) merged)))
    (nreverse merged)))

(defun tmux-csi-u-data-build-candidate-table (&optional local-overrides)
  "Return the current candidate table with LOCAL-OVERRIDES applied last."
  (tmux-csi-u-data--merge-tables
   (tmux-csi-u-data-generated-printable-table)
   (tmux-csi-u-data-special-table)
   local-overrides))

(define-obsolete-function-alias
  'tmux-emacs-csi-u-data-modifier-prefix
  'tmux-csi-u-data-modifier-prefix
  "0.1.0")
(define-obsolete-function-alias
  'tmux-emacs-csi-u-data-generated-printable-table
  'tmux-csi-u-data-generated-printable-table
  "0.1.0")
(define-obsolete-function-alias
  'tmux-emacs-csi-u-data-generated-printable-skip-list
  'tmux-csi-u-data-generated-printable-skip-list
  "0.1.0")
(define-obsolete-function-alias
  'tmux-emacs-csi-u-data-special-table
  'tmux-csi-u-data-special-table
  "0.1.0")
(define-obsolete-function-alias
  'tmux-emacs-csi-u-data-build-candidate-table
  'tmux-csi-u-data-build-candidate-table
  "0.1.0")
(define-obsolete-function-alias
  'tmux-emacs-csi-u-data--copy-binding
  'tmux-csi-u-data--copy-binding
  "0.1.0")
(defconst tmux-emacs-csi-u-data--modifier-prefixes
  tmux-csi-u-data--modifier-prefixes
  "Obsolete alias for `tmux-csi-u-data--modifier-prefixes'.")
(make-obsolete-variable 'tmux-emacs-csi-u-data--modifier-prefixes
                        'tmux-csi-u-data--modifier-prefixes
                        "0.1.0")
(defconst tmux-emacs-csi-u-data--generated-printable-table
  tmux-csi-u-data--generated-printable-table
  "Obsolete alias for `tmux-csi-u-data--generated-printable-table'.")
(make-obsolete-variable 'tmux-emacs-csi-u-data--generated-printable-table
                        'tmux-csi-u-data--generated-printable-table
                        "0.1.0")
(defconst tmux-emacs-csi-u-data--generated-printable-skip-list
  tmux-csi-u-data--generated-printable-skip-list
  "Obsolete alias for `tmux-csi-u-data--generated-printable-skip-list'.")
(make-obsolete-variable 'tmux-emacs-csi-u-data--generated-printable-skip-list
                        'tmux-csi-u-data--generated-printable-skip-list
                        "0.1.0")
(defconst tmux-emacs-csi-u-data--special-table
  tmux-csi-u-data--special-table
  "Obsolete alias for `tmux-csi-u-data--special-table'.")
(make-obsolete-variable 'tmux-emacs-csi-u-data--special-table
                        'tmux-csi-u-data--special-table
                        "0.1.0")

(provide 'tmux-csi-u-data)
;;; tmux-csi-u-data.el ends here
