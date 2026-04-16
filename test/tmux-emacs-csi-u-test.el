;;; tmux-emacs-csi-u-test.el --- tests -*- lexical-binding: t; -*-

;;; Commentary:

;; ERT coverage for tmux-emacs-csi-u.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'json)

(defconst tmux-emacs-csi-u-test--root-dir
  (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name)))
  "Repo root for source-first test loading.")

(defun tmux-emacs-csi-u-test--fixture-path (name)
  "Return the absolute path for fixture file NAME."
  (expand-file-name (concat "test/fixture/" name)
                    tmux-emacs-csi-u-test--root-dir))

(defun tmux-emacs-csi-u-test--escaped-sequence (sequence)
  "Render SEQUENCE with spec-style escaped ESC."
  (replace-regexp-in-string "\e" "\\\\e" sequence t t))

(defun tmux-emacs-csi-u-test--read-json-fixture (name)
  "Return parsed JSON fixture NAME as alists and lists."
  (with-temp-buffer
    (insert-file-contents (tmux-emacs-csi-u-test--fixture-path name))
    (json-parse-buffer :object-type 'alist :array-type 'list)))

(defun tmux-emacs-csi-u-test--read-repo-file (path)
  "Return the contents of repo-relative PATH as a string."
  (with-temp-buffer
    (insert-file-contents (expand-file-name path tmux-emacs-csi-u-test--root-dir))
    (buffer-string)))

(defun tmux-emacs-csi-u-test--assert-repo-file-contains (path snippets)
  "Assert repo-relative PATH exists and contain each string in SNIPPETS."
  (let ((absolute-path (expand-file-name path tmux-emacs-csi-u-test--root-dir)))
    (should (file-exists-p absolute-path))
    (let ((contents (tmux-emacs-csi-u-test--read-repo-file path)))
      (dolist (snippet snippets)
        (should (string-match-p (regexp-quote snippet) contents))))))

(defun tmux-emacs-csi-u-test--sequence-keycode/modifier (sequence)
  "Return (KEYCODE MODIFIER) parsed from printable CSI-u SEQUENCE."
  (when (string-match "\\`\e\\[\\([0-9]+\\);\\([0-9]+\\)u\\'" sequence)
    (list (string-to-number (match-string 1 sequence))
          (string-to-number (match-string 2 sequence)))))

(defun tmux-emacs-csi-u-test--expected-generated-matrix-fixture ()
  "Return the expected generated-matrix fixture payload."
  (list
   (cons 'format_version 1)
   (cons 'encoding
         (list (cons 'sequence "escaped-csi-u")
               (cons 'event "canonical-event")))
   (cons 'entries
         (mapcar (lambda (entry)
                   (pcase-let ((`(,keycode ,modifier)
                                (tmux-emacs-csi-u-test--sequence-keycode/modifier
                                 (car entry))))
                     (list (cons 'keycode keycode)
                           (cons 'modifier modifier)
                           (cons 'sequence
                                 (tmux-emacs-csi-u-test--escaped-sequence
                                  (car entry)))
                           (cons 'event (key-description (cdr entry))))))
                 (tmux-emacs-csi-u-data-generated-printable-table)))
   (cons 'skip_list
         (mapcar (lambda (entry)
                   (list (cons 'keycode (plist-get entry :keycode))
                         (cons 'modifier (plist-get entry :modifier))
                         (cons 'sequence
                               (tmux-emacs-csi-u-test--escaped-sequence
                                (plist-get entry :sequence)))
                         (cons 'reason (plist-get entry :reason))))
                 (tmux-emacs-csi-u-data-generated-printable-skip-list)))))

(defconst tmux-emacs-csi-u-test--canonical-punctuation-entries
  '((":" "\e[59;2u" ":")
    ("?" "\e[47;2u" "?")
    (">" "\e[46;2u" ">")
    ("<" "\e[44;2u" "<")
    ("\"" "\e[39;2u" "\"")
    ("{" "\e[91;2u" "{")
    ("}" "\e[93;2u" "}")
    ("|" "\e[92;2u" "|")
    ("+" "\e[61;2u" "+")
    ("_" "\e[45;2u" "_")
    ("~" "\e[96;2u" "~"))
  "Canonical local shifted punctuation capture entries.")

(defconst tmux-emacs-csi-u-test--canonical-punctuation-modifier-prefixes
  '((2 . "")
    (4 . "M-")
    (6 . "C-")
    (8 . "C-M-"))
  "Modifier prefixes for explicit local shifted punctuation overrides.")

(defun tmux-emacs-csi-u-test--canonical-punctuation-family-entries ()
  "Return explicit override expectations for the captured punctuation family."
  (apply #'append
         (mapcar
          (lambda (entry)
            (pcase-let* ((`(,char ,sequence ,event) entry)
                         (`(,keycode ,_modifier)
                          (tmux-emacs-csi-u-test--sequence-keycode/modifier
                           sequence)))
              (mapcar
               (lambda (modifier/prefix)
                 (pcase-let ((`(,modifier . ,prefix) modifier/prefix))
                   (list char
                         (format "\e[%d;%du" keycode modifier)
                         (concat prefix event))))
               tmux-emacs-csi-u-test--canonical-punctuation-modifier-prefixes)))
          tmux-emacs-csi-u-test--canonical-punctuation-entries)))

(defun tmux-emacs-csi-u-test--expected-punctuation-fixture ()
  "Return the expected punctuation fixture payload."
  (list
   (cons 'format_version 1)
   (cons 'capture
         (list (cons 'command "cat -v")
               (cons 'tmux_version "tmux 3.6a")
               (cons 'emacs_version "GNU Emacs 30.2")
               (cons 'terminal_app "Ghostty 1.3.1")
               (cons 'input_source "ABC")))
   (cons 'entries
         (mapcar
          (lambda (entry)
            (pcase-let ((`(,char ,sequence ,event) entry))
              (list (cons 'char char)
                    (cons 'sequence
                          (tmux-emacs-csi-u-test--escaped-sequence sequence))
                    (cons 'event event))))
          tmux-emacs-csi-u-test--canonical-punctuation-entries))))

;; Keep byte-compilation self-contained while runtime tests still load exact
;; source files below.
(defvar tmux-emacs-csi-u-auto-enable)
(defvar tmux-emacs-csi-u-force-enable)
(defvar tmux-emacs-csi-u-last-report)
(defvar tmux-emacs-csi-u-local-overrides)
(defvar tmux-emacs-csi-u--owned-bindings-by-keymap)
(defvar tmux-emacs-csi-u-core--missing-owned-binding)

(declare-function tmux-emacs-csi-u-data-generated-printable-table
                  "tmux-emacs-csi-u-data"
                  ())
(declare-function tmux-emacs-csi-u-data-generated-printable-skip-list
                  "tmux-emacs-csi-u-data"
                  ())
(declare-function tmux-emacs-csi-u-data-special-table
                  "tmux-emacs-csi-u-data"
                  ())
(declare-function tmux-emacs-csi-u-data-build-candidate-table
                  "tmux-emacs-csi-u-data"
                  (&optional local-overrides))
(declare-function tmux-emacs-csi-u-core-special-table
                  "tmux-emacs-csi-u-core"
                  ())
(declare-function tmux-emacs-csi-u-core-install-table
                  "tmux-emacs-csi-u-core"
                  (table keymap support-signal &optional owned-bindings))
(declare-function tmux-emacs-csi-u-core--owned-binding
                  "tmux-emacs-csi-u-core"
                  (owned-bindings sequence))
(declare-function tmux-emacs-csi-u-supported-p
                  "tmux-emacs-csi-u"
                  (&optional frame))
(declare-function tmux-emacs-csi-u--set-auto-enable
                  "tmux-emacs-csi-u"
                  (symbol value))
(declare-function tmux-emacs-csi-u--sync-tty-setup-hook
                  "tmux-emacs-csi-u"
                  (enabled))
(declare-function tmux-emacs-csi-u--tty-setup-enable
                  "tmux-emacs-csi-u"
                  ())
(declare-function tmux-emacs-csi-u--support-signal
                  "tmux-emacs-csi-u"
                  (&optional frame))
(declare-function tmux-emacs-csi-u--support-state
                  "tmux-emacs-csi-u"
                  (&optional frame))
(declare-function tmux-emacs-csi-u--annotate-report-with-support-state
                  "tmux-emacs-csi-u"
                  (report support-state))
(declare-function tmux-emacs-csi-u--render-report
                  "tmux-emacs-csi-u"
                  (report))
(declare-function tmux-emacs-csi-u-enable
                  "tmux-emacs-csi-u"
                  (&optional frame))
(declare-function tmux-emacs-csi-u--candidate-table
                  "tmux-emacs-csi-u"
                  ())
(declare-function tmux-emacs-csi-u--owned-bindings
                  "tmux-emacs-csi-u"
                  (keymap))
(declare-function tmux-emacs-csi-u-describe
                  "tmux-emacs-csi-u"
                  ())
(declare-function tmux-emacs-csi-u--warn-on-new-conflicts
                  "tmux-emacs-csi-u"
                  (frame conflicts))

(add-to-list 'load-path tmux-emacs-csi-u-test--root-dir)
(load (expand-file-name "tmux-emacs-csi-u-data.el" tmux-emacs-csi-u-test--root-dir)
      nil 'nomessage)
(load (expand-file-name "tmux-emacs-csi-u-core.el" tmux-emacs-csi-u-test--root-dir)
      nil 'nomessage)
(load (expand-file-name "tmux-emacs-csi-u.el" tmux-emacs-csi-u-test--root-dir)
      nil 'nomessage)

(defmacro tmux-emacs-csi-u-test-with-live-tty (&rest body)
  "Run BODY with a deterministic live TTY frame state."
  (declare (debug t) (indent 0))
  `(cl-letf (((symbol-function 'selected-frame) (lambda () 'selected-frame))
             ((symbol-function 'display-graphic-p) (lambda (&optional _frame) nil))
             ((symbol-function 'frame-terminal) (lambda (_frame) 'terminal))
             ((symbol-function 'terminal-live-p) (lambda (_terminal) t)))
     ,@body))

(defun tmux-emacs-csi-u-test--printable-base-token (keycode)
  "Return the canonical base token for printable ASCII KEYCODE."
  (if (= keycode 32)
      "SPC"
    (char-to-string keycode)))

(defun tmux-emacs-csi-u-test--printable-event-description (keycode modifier)
  "Return the canonical event description for printable KEYCODE and MODIFIER."
  (key-description
   (kbd (concat (alist-get modifier '((2 . "S-")
                                      (3 . "M-")
                                      (4 . "M-S-")
                                      (5 . "C-")
                                      (6 . "C-S-")
                                      (7 . "C-M-")
                                      (8 . "C-M-S-")))
                (tmux-emacs-csi-u-test--printable-base-token keycode)))))

(defun tmux-emacs-csi-u-test--expected-xterm-native-exact-skip-reason (keycode modifier)
  "Return the expected native exact skip reason for KEYCODE and MODIFIER."
  (when (memq keycode
              (alist-get modifier '((3 . (32))
                                    (5 . (39 44 45 46 47 48 49 57 59 61 92))
                                    (7 . (32 39 44 45 46 47 48 49 50 51 52 53
                                             54 55 56 57 59 61 92)))))
    (format "xterm.el decodes %s natively"
            (tmux-emacs-csi-u-test--printable-event-description keycode modifier))))

(defun tmux-emacs-csi-u-test--expected-xterm-native-lossy-skip-reason (keycode modifier)
  "Return the expected native lossy skip reason for KEYCODE and MODIFIER."
  (when (memq keycode
              (alist-get modifier '((6 . (33 34 35 36 37 38 40 41 42 43 58 60 62 63))
                                    (8 . (33 34 35 36 37 38 40 41 42 43 58 60 62 63)))))
    (let ((collapsed-modifier (alist-get modifier '((6 . 5)
                                                    (8 . 7)))))
      (format "xterm.el collapses %s to %s"
              (tmux-emacs-csi-u-test--printable-event-description keycode modifier)
              (tmux-emacs-csi-u-test--printable-event-description keycode
                                                                  collapsed-modifier)))))

(defun tmux-emacs-csi-u-test--expected-generated-printable-skip-reason (keycode modifier)
  "Return the expected skip reason for printable KEYCODE and MODIFIER."
  (cond
   ((tmux-emacs-csi-u-test--expected-xterm-native-exact-skip-reason keycode modifier))
   ((tmux-emacs-csi-u-test--expected-xterm-native-lossy-skip-reason keycode modifier))
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
   ((and (<= 65 keycode 90)
         (memq modifier '(5 6 7 8))
         (not (memq keycode '(73 77))))
    (let* ((prefix (alist-get modifier '((5 . "C-")
                                         (6 . "C-S-")
                                         (7 . "C-M-")
                                         (8 . "C-M-S-"))))
           (uppercase (char-to-string keycode))
           (lowercase (char-to-string (downcase keycode))))
      (format "kbd normalizes %s%s to %s%s"
              prefix uppercase prefix lowercase)))))

(defun tmux-emacs-csi-u-test--expected-generated-printable-skip-list ()
  "Return the expected generated printable skip list."
  (let (entries)
    (dolist (keycode (number-sequence 32 126))
      (dolist (modifier '(2 3 4 5 6 7 8))
        (let ((reason (tmux-emacs-csi-u-test--expected-generated-printable-skip-reason
                       keycode modifier)))
          (when reason
            (push (list (format "\e[%d;%du" keycode modifier)
                        keycode
                        modifier
                        reason)
                  entries)))))
    (nreverse entries)))

(defun tmux-emacs-csi-u-test--find-generated-printable-skip-entry (sequence)
  "Return the generated printable skip entry for SEQUENCE."
  (cl-find-if (lambda (entry)
                (equal (plist-get entry :sequence) sequence))
              (tmux-emacs-csi-u-data-generated-printable-skip-list)))

(ert-deftest tmux-emacs-csi-u-test-support-signals ()
  (tmux-emacs-csi-u-test-with-live-tty
   (cl-letf (((symbol-function 'tty-type) (lambda (&optional _terminal) nil)))
     (should-not (tmux-emacs-csi-u-supported-p)))
   (cl-letf (((symbol-function 'tty-type)
              (lambda (&optional _terminal) "tmux-256color")))
     (should (tmux-emacs-csi-u-supported-p)))
   (let ((tmux-emacs-csi-u-force-enable t))
     (should (eq (tmux-emacs-csi-u--support-signal) 'force-enable)))
   (cl-letf (((symbol-function 'display-graphic-p) (lambda (&optional _frame) t)))
     (let ((tmux-emacs-csi-u-force-enable t))
       (should-not (tmux-emacs-csi-u-supported-p))))
   (cl-letf (((symbol-function 'terminal-live-p) (lambda (_terminal) nil)))
     (let ((tmux-emacs-csi-u-force-enable t))
       (should-not (tmux-emacs-csi-u-supported-p))))))

(ert-deftest tmux-emacs-csi-u-test-support-signals-for-explicit-frame ()
  (cl-letf (((symbol-function 'display-graphic-p)
             (lambda (&optional frame)
               (eq frame 'graphic-frame)))
            ((symbol-function 'frame-terminal)
             (lambda (frame)
               (pcase frame
                 ('dead-frame 'dead-terminal)
                 (_ 'live-terminal))))
            ((symbol-function 'terminal-live-p)
             (lambda (terminal)
               (eq terminal 'live-terminal)))
            ((symbol-function 'tty-type)
             (lambda (frame)
               (pcase frame
                 ('tmux-frame "tmux")
                 (_ "xterm-256color")))))
    (let ((tmux-state (tmux-emacs-csi-u--support-state 'tmux-frame))
          (xterm-state (tmux-emacs-csi-u--support-state 'xterm-frame))
          (graphic-state (tmux-emacs-csi-u--support-state 'graphic-frame))
          (dead-state (tmux-emacs-csi-u--support-state 'dead-frame)))
      (should (eq (plist-get tmux-state :support-signal) 'tty-type))
      (should (eq (tmux-emacs-csi-u--support-signal 'tmux-frame) 'tty-type))
      (should (eq (plist-get xterm-state :support-signal) 'unsupported))
      (should (eq (plist-get xterm-state :unsupported-reason) 'non-tmux-tty))
      (should (equal (plist-get xterm-state :tty-type) "xterm-256color"))
      (should-not (tmux-emacs-csi-u-supported-p 'xterm-frame))
      (should (eq (plist-get graphic-state :unsupported-reason) 'graphical-frame))
      (should-not (tmux-emacs-csi-u-supported-p 'graphic-frame))
      (should (eq (plist-get dead-state :unsupported-reason) 'dead-terminal))
      (should-not (tmux-emacs-csi-u-supported-p 'dead-frame)))))

(ert-deftest tmux-emacs-csi-u-test-render-report-distinguishes-unsupported-reasons ()
  (dolist (case '((graphical-frame nil "skip-reason: graphical-frame" nil)
                  (dead-terminal nil "skip-reason: dead-terminal" nil)
                  (non-tmux-tty "xterm-256color"
                                "skip-reason: non-tmux-tty"
                                "tty-type: xterm-256color")))
    (pcase-let ((`(,reason ,tty-type ,reason-text ,tty-text) case))
      (let ((report (tmux-emacs-csi-u--annotate-report-with-support-state
                     (list :status 'skipped
                           :support-signal 'unsupported
                           :installed 0
                           :already-matching 0
                           :preserved-conflicts 0
                           :unsupported-or-skipped 1
                           :conflicts nil)
                     (list :support-signal 'unsupported
                           :unsupported-reason reason
                           :tty-type tty-type))))
        (let ((rendered (tmux-emacs-csi-u--render-report report)))
          (should (string-match-p (regexp-quote reason-text) rendered))
          (if tty-text
              (should (string-match-p (regexp-quote tty-text) rendered))
            (should-not (string-match-p (regexp-quote "tty-type:") rendered))))))))

(ert-deftest tmux-emacs-csi-u-test-special-table-keeps-only-non-native-return-tab-delta ()
  (let ((special-table (tmux-emacs-csi-u-core-special-table)))
    (dolist (sequence '("\e[32;3u"
                        "\e[32;7u"
                        "\e[9;2u"
                        "\e[9;5u"
                        "\e[9;6u"
                        "\e[13;2u"
                        "\e[13;5u"
                        "\e[13;6u"
                        "\e[13;7u"))
      (should-not (assoc sequence special-table)))
    (dolist (entry `(("\e[9;3u" . ,(kbd "M-<tab>"))
                     ("\e[13;3u" . ,(kbd "M-<return>"))
                     ("\e[13;8u" . ,(kbd "C-M-S-<return>"))))
      (should (equal (cdr (assoc (car entry) special-table))
                     (cdr entry))))))

(ert-deftest tmux-emacs-csi-u-test-special-table-detaches-mutable-bindings ()
  (let* ((binding-a (cdr (assoc "\e[32;2u" (tmux-emacs-csi-u-core-special-table))))
         (binding-b (cdr (assoc "\e[32;2u" (tmux-emacs-csi-u-core-special-table))))
         (original (aref binding-a 0)))
    (should-not (eq binding-a binding-b))
    (unwind-protect
        (progn
          (aset binding-a 0 ?X)
          (should (equal binding-b (kbd "SPC")))
          (should (equal (cdr (assoc "\e[32;2u"
                                     (tmux-emacs-csi-u-core-special-table)))
                         (kbd "SPC"))))
      (aset binding-a 0 original))))

(ert-deftest tmux-emacs-csi-u-test-generated-printable-table-covers-full-ascii-matrix ()
  (let* ((table (tmux-emacs-csi-u-data-generated-printable-table))
         (skip-list (tmux-emacs-csi-u-data-generated-printable-skip-list))
         (skip-sequences (mapcar (lambda (entry) (plist-get entry :sequence))
                                 skip-list))
         (legacy-alias-descriptions '("TAB" "S-TAB"
                                      "RET" "S-RET" "M-RET" "M-S-RET"
                                      "ESC" "S-ESC" "M-ESC" "M-S-ESC"
                                      "DEL" "S-DEL" "M-DEL" "M-S-DEL"
                                      "C-M-i" "C-M-S-i"))
         (expected-skip-list
          (tmux-emacs-csi-u-test--expected-generated-printable-skip-list))
         duplicate-bindings)
    (should (= (+ (length table) (length skip-list)) (* (- 127 32) 7)))
    (should (equal (mapcar (lambda (entry)
                             (list (plist-get entry :sequence)
                                   (plist-get entry :keycode)
                                   (plist-get entry :modifier)
                                   (plist-get entry :reason)))
                           skip-list)
                   expected-skip-list))
    (let ((seen-bindings (make-hash-table :test 'equal)))
      (dolist (entry table)
        (let* ((signature (key-description (cdr entry)))
               (other-sequence (gethash signature seen-bindings)))
          (if other-sequence
              (push (list signature other-sequence (car entry)) duplicate-bindings)
            (puthash signature (car entry) seen-bindings)))))
    (should-not duplicate-bindings)
    (dolist (keycode (number-sequence 32 126))
      (dolist (modifier '(2 3 4 5 6 7 8))
        (let ((sequence (format "\e[%d;%du" keycode modifier)))
          (should (or (assoc sequence table)
                      (member sequence skip-sequences))))))
    (dolist (sequence skip-sequences)
      (should-not (assoc sequence table)))
    (should (equal (caar table) "\e[32;2u"))
    (should (equal (cadr table)
                   (cons "\e[32;4u" (kbd "M-S-SPC"))))
    (should (equal (nth 4 table)
                   (cons "\e[32;8u" (kbd "C-M-S-SPC"))))
    (should (equal (nth 5 table)
                   (cons "\e[33;2u" (kbd "S-!"))))
    (should (equal (cdr (assoc "\e[59;2u" table))
                   (kbd "S-;")))
    (should (equal (cdr (assoc "\e[97;6u" table))
                   (kbd "C-S-a")))
    (should (equal (cdr (assoc "\e[63;5u" table))
                   (kbd "C-?")))
    (should (equal (key-description (cdr (assoc "\e[63;5u" table)))
                   "C-?"))
    (dolist (entry table)
      (should-not (member (key-description (cdr entry))
                          legacy-alias-descriptions)))
    (should (equal (caar (last table))
                   "\e[126;8u"))))

(ert-deftest tmux-emacs-csi-u-test-generated-matrix-fixture-matches-printable-baseline ()
  (let ((fixture-path (tmux-emacs-csi-u-test--fixture-path "generated-matrix.json")))
    (should (file-exists-p fixture-path))
    (should (equal (tmux-emacs-csi-u-test--read-json-fixture "generated-matrix.json")
                   (tmux-emacs-csi-u-test--expected-generated-matrix-fixture)))))

(ert-deftest tmux-emacs-csi-u-test-generated-skip-list-covers-xterm-native-overlaps ()
  (let ((table (tmux-emacs-csi-u-data-generated-printable-table)))
    (dolist (sequence '("\e[32;3u"
                        "\e[32;7u"
                        "\e[39;5u"
                        "\e[58;6u"
                        "\e[63;8u"))
      (should-not (assoc sequence table)))
    (dolist (case '(("\e[32;3u" "xterm.el decodes M-SPC natively")
                    ("\e[32;7u" "xterm.el decodes C-M-SPC natively")
                    ("\e[39;5u" "xterm.el decodes C-' natively")
                    ("\e[58;6u" "xterm.el collapses C-S-: to C-:")
                    ("\e[63;8u" "xterm.el collapses C-M-S-? to C-M-?")))
      (pcase-let ((`(,sequence ,reason) case))
        (let ((entry (tmux-emacs-csi-u-test--find-generated-printable-skip-entry
                      sequence)))
          (should entry)
          (should (equal (plist-get entry :reason) reason)))))))

(ert-deftest tmux-emacs-csi-u-test-shifted-punctuation-family-stays-owned-while-codepoint-form-is-skipped ()
  (let* ((generated (tmux-emacs-csi-u-data-generated-printable-table))
         (special (tmux-emacs-csi-u-data-special-table))
         (table (tmux-emacs-csi-u-data-build-candidate-table))
         (native-skip (tmux-emacs-csi-u-test--find-generated-printable-skip-entry
                       "\e[58;6u")))
    (should (equal (key-description (cdr (assoc "\e[59;6u" generated))) "C-S-;"))
    (should (equal (key-description (cdr (assoc "\e[59;6u" special))) "C-:"))
    (should (equal (key-description (cdr (assoc "\e[59;6u" table))) "C-:"))
    (should-not (tmux-emacs-csi-u-test--find-generated-printable-skip-entry
                 "\e[59;6u"))
    (should native-skip)
    (should (equal (plist-get native-skip :reason)
                   "xterm.el collapses C-S-: to C-:"))
    (should-not (assoc "\e[58;6u" table))))

(ert-deftest tmux-emacs-csi-u-test-shifted-punctuation-overrides-follow-canonical-char-capture ()
  (let* ((generated (tmux-emacs-csi-u-data-generated-printable-table))
         (special (tmux-emacs-csi-u-data-special-table))
         (table (tmux-emacs-csi-u-data-build-candidate-table)))
    (should (equal (key-description (cdr (assoc "\e[47;2u" generated))) "S-/"))
    (should (equal (key-description (cdr (assoc "\e[46;2u" generated))) "S-."))
    (should (equal (key-description (cdr (assoc "\e[44;2u" generated))) "S-,"))
    (should (equal (key-description (cdr (assoc "\e[59;4u" generated))) "M-S-;"))
    (should (equal (key-description (cdr (assoc "\e[96;2u" generated))) "S-`"))
    (dolist (entry (tmux-emacs-csi-u-test--canonical-punctuation-family-entries))
      (pcase-let ((`(,char ,sequence ,event) entry))
        (let ((special-binding (cdr (assoc sequence special)))
              (candidate-binding (cdr (assoc sequence table))))
          (when (equal sequence (nth 1 (assoc char tmux-emacs-csi-u-test--canonical-punctuation-entries)))
            (should (equal char event)))
          (should special-binding)
          (should candidate-binding)
          (should (equal (key-description special-binding) event))
          (should (equal (key-description candidate-binding) event)))))))

(ert-deftest tmux-emacs-csi-u-test-punctuation-fixture-matches-canonical-char-capture ()
  (let ((fixture-path (tmux-emacs-csi-u-test--fixture-path "punctuation.json")))
    (should (file-exists-p fixture-path))
    (should (equal (tmux-emacs-csi-u-test--read-json-fixture "punctuation.json")
                   (tmux-emacs-csi-u-test--expected-punctuation-fixture)))))

(ert-deftest tmux-emacs-csi-u-test-entrypoint-includes-package-metadata ()
  (let ((contents (tmux-emacs-csi-u-test--read-repo-file "tmux-emacs-csi-u.el")))
    (should (string-match-p "^;; Version: " contents))
    (should (string-match-p "^;; Package-Requires: " contents))
    (should (string-match-p "^;; Keywords: " contents))
    (should (string-match-p "^;; URL: https://" contents))))

(ert-deftest tmux-emacs-csi-u-test-authoritative-gate-scripts-exist ()
  (dolist (path '("script/bootstrap-package-lint"
                  "script/qa-smoke"
                  "script/format"
                  "script/lint"
                  "script/compile"
                  "script/test"
                  "script/check"))
    (let ((absolute-path (expand-file-name path tmux-emacs-csi-u-test--root-dir)))
      (should (file-exists-p absolute-path))
      (should (file-executable-p absolute-path)))))

(ert-deftest tmux-emacs-csi-u-test-qa-smoke-enforces-clean-canonical-report ()
  (tmux-emacs-csi-u-test--assert-repo-file-contains
   "script/qa-smoke"
   '("wait_for_condition"
     ">/dev/null 2>&1"
     "rm -f \"$init_file\" \"$ready_file\" \"$result_file\""
     "Emacs daemon"
     "tty client ready"
     "qa result file"
     "':status already-enabled'"
     "':preserved-conflicts 0'")))

(ert-deftest tmux-emacs-csi-u-test-lefthook-wires-authoritative-commands ()
  (let ((contents (tmux-emacs-csi-u-test--read-repo-file "lefthook.yml")))
    (dolist (snippet '("run: script/format"
                       "run: script/lint"
                       "run: script/check"))
      (should (string-match-p (regexp-quote snippet) contents)))))

(ert-deftest tmux-emacs-csi-u-test-repo-docs-cover-user-and-maintainer-contract ()
  (tmux-emacs-csi-u-test--assert-repo-file-contains
   "README.md"
   '("# tmux-emacs-csi-u"
     "tmux stays on `csi-u`"
     "delta over Emacs native tmux/xterm decode"
     "path/to/tmux-emacs-csi-u"
     "(require 'tmux-emacs-csi-u)"
     "Delete the ad hoc `input-decode-map` entries"
     "derived from `test/fixture/punctuation.json` (`;2`, `;4`, `;6`, `;8`"
     "\\e[9;2u"
     "\\e[58;6u"
     "\\e[13;4u"
     "tmux-emacs-csi-u-supported-p"
     "script/qa-smoke"
     "M-x tmux-emacs-csi-u-describe RET"
     "git status --short"
     "Pi"))
  (tmux-emacs-csi-u-test--assert-repo-file-contains
   "doc/ref/protocol.md"
   '("# protocol reference"
     "ESC [ keycode ; modifier u"
     "delta over Emacs native tmux/xterm decode"
     "`test/fixture/generated-matrix.json`"
     "`test/fixture/punctuation.json`"
     "generated space baseline still covers `\\e[32;4u`"
     "including modifiers `2`, `4`, `6`, and `8`"
     "`\\e[13;4u` (`M-S-RET`)"
     "xterm.el decodes"
     "xterm.el collapses"
     "kbd normalizes"
     "Bug #50699"))
  (tmux-emacs-csi-u-test--assert-repo-file-contains
   "AGENTS.md"
   '("# AGENTS"
     "warn-and-preserve"
     "script/check"
     "README.md"
     "non-goals")))

(ert-deftest tmux-emacs-csi-u-test-minimal-maintainer-files-exist ()
  (dolist (path '("LICENSE"
                  ".github/release.yml"
                  ".github/workflows/ci.yml"))
    (should (file-exists-p (expand-file-name path tmux-emacs-csi-u-test--root-dir))))
  (tmux-emacs-csi-u-test--assert-repo-file-contains
   "LICENSE"
   '("MIT License"
     "lajarre and contributors"))
  (tmux-emacs-csi-u-test--assert-repo-file-contains
   ".github/release.yml"
   '("changelog:"
     "title: docs"
     "title: testing"))
  (tmux-emacs-csi-u-test--assert-repo-file-contains
   ".github/workflows/ci.yml"
   '("name: ci"
     "script/bootstrap-package-lint"
     "script/check"
     "emacs-nox tmux"))
  (dolist (path '("CONTRIBUTING.md"
                  "CODE_OF_CONDUCT.md"
                  ".github/CODEOWNERS"
                  ".github/ISSUE_TEMPLATE/bug_report.yml"
                  ".github/ISSUE_TEMPLATE/feature_request.yml"
                  ".github/ISSUE_TEMPLATE/conduct-report.md"
                  ".github/pull_request_template.md"))
    (should-not (file-exists-p (expand-file-name path tmux-emacs-csi-u-test--root-dir)))))

(ert-deftest tmux-emacs-csi-u-test-candidate-table-applies-local-overrides ()
  (let* ((overrides '(("\e[59;2u" . [f13])
                      ("\e[120;2u" . [f14])))
         (generated (tmux-emacs-csi-u-data-generated-printable-table))
         (special (tmux-emacs-csi-u-data-special-table))
         (table (tmux-emacs-csi-u-data-build-candidate-table overrides))
         (unique-sequences (cl-remove-duplicates
                            (mapcar #'car (append generated special overrides))
                            :test #'equal)))
    (should (= (length table) (length unique-sequences)))
    (should (= (cl-count "\e[59;2u" table :key #'car :test #'equal) 1))
    (should (equal (cdr (assoc "\e[59;2u" generated))
                   (kbd "S-;")))
    (should (equal (cdr (assoc "\e[59;2u" table)) [f13]))
    (should (equal (cdr (assoc "\e[63;2u" table))
                   (kbd "S-?")))
    (should (equal (cdr (assoc "\e[120;2u" table)) [f14]))
    (should (equal (cdr (assoc "\e[59;2u"
                               (tmux-emacs-csi-u-data-special-table)))
                   [?:]))))

(ert-deftest tmux-emacs-csi-u-test-install-special-table ()
  (let* ((table (tmux-emacs-csi-u-core-special-table))
         (keymap (make-sparse-keymap))
         (report (tmux-emacs-csi-u-core-install-table table keymap 'force-enable)))
    (should (eq (plist-get report :status) 'installed))
    (should (= (plist-get report :installed) (length table)))
    (dolist (entry table)
      (should (equal (lookup-key keymap (car entry)) (cdr entry))))))

(ert-deftest tmux-emacs-csi-u-test-install-preserves-blocking-prefix-conflict ()
  (let* ((keymap (make-sparse-keymap))
         (table '(("\e[59;2u" . [?:]))))
    (define-key keymap "\e" [f13])
    (let* ((report (tmux-emacs-csi-u-core-install-table table keymap 'force-enable))
           (conflict (car (plist-get report :conflicts))))
      (should (eq (plist-get report :status) 'partial))
      (should (zerop (plist-get report :installed)))
      (should (= (plist-get report :preserved-conflicts) 1))
      (should (equal (plist-get conflict :sequence) "\\\\e[59;2u"))
      (should (equal (plist-get conflict :existing) "[f13]"))
      (should (equal (plist-get conflict :candidate) "[58]"))
      (should (equal (lookup-key keymap "\e") [f13]))
      (should (= (lookup-key keymap "\e[59;2u") 1)))))

(ert-deftest tmux-emacs-csi-u-test-integer-full-sequence-binding-preserves-exact-semantics ()
  (let ((table '(("\e[59;2u" . [?:]))))
    (let ((matching-keymap (make-sparse-keymap)))
      (define-key matching-keymap "\e[59;2u" ?:)
      (let ((report (tmux-emacs-csi-u-core-install-table table matching-keymap 'force-enable)))
        (should (eq (plist-get report :status) 'already-enabled))
        (should (zerop (plist-get report :installed)))
        (should (= (plist-get report :already-matching) 1))
        (should (zerop (plist-get report :preserved-conflicts)))
        (should-not (plist-get report :conflicts))
        (should (= (lookup-key matching-keymap "\e[59;2u") ?:))))
    (let ((conflicting-keymap (make-sparse-keymap)))
      (define-key conflicting-keymap "\e[59;2u" ?X)
      (let* ((report (tmux-emacs-csi-u-core-install-table table conflicting-keymap 'force-enable))
             (conflict (car (plist-get report :conflicts))))
        (should (eq (plist-get report :status) 'partial))
        (should (zerop (plist-get report :installed)))
        (should (zerop (plist-get report :already-matching)))
        (should (= (plist-get report :preserved-conflicts) 1))
        (should (equal (plist-get conflict :sequence) "\\\\e[59;2u"))
        (should (equal (plist-get conflict :existing) "88"))
        (should (equal (plist-get conflict :candidate) "[58]"))
        (should (= (lookup-key conflicting-keymap "\e[59;2u") ?X))))))

(ert-deftest tmux-emacs-csi-u-test-integer-shorter-prefix-binding-is-preserved ()
  (let* ((keymap (make-sparse-keymap))
         (table '(("\e[59;2u" . [?:]))))
    (define-key keymap "\e[5" ?X)
    (let* ((report (tmux-emacs-csi-u-core-install-table table keymap 'force-enable))
           (conflict (car (plist-get report :conflicts))))
      (should (eq (plist-get report :status) 'partial))
      (should (zerop (plist-get report :installed)))
      (should (zerop (plist-get report :already-matching)))
      (should (= (plist-get report :preserved-conflicts) 1))
      (should (equal (plist-get conflict :sequence) "\\\\e[59;2u"))
      (should (equal (plist-get conflict :existing) "88"))
      (should (equal (plist-get conflict :candidate) "[58]"))
      (should (= (lookup-key keymap "\e[5") ?X))
      (should (= (lookup-key keymap "\e[59;2u") 3)))))

(ert-deftest tmux-emacs-csi-u-test-idempotent-reporting ()
  (let* ((table (tmux-emacs-csi-u-core-special-table))
         (keymap (make-sparse-keymap)))
    (tmux-emacs-csi-u-core-install-table table keymap 'force-enable)
    (let ((report (tmux-emacs-csi-u-core-install-table table keymap 'force-enable)))
      (should (eq (plist-get report :status) 'already-enabled))
      (should (zerop (plist-get report :installed)))
      (should (= (plist-get report :already-matching) (length table))))))

(ert-deftest tmux-emacs-csi-u-test-equivalent-binding-encoding-counts-as-already-matching ()
  (let* ((keymap (make-sparse-keymap))
         (table '(("\e[59;2u" . [?:]))))
    (define-key keymap "\e[59;2u" ":")
    (let ((report (tmux-emacs-csi-u-core-install-table table keymap 'force-enable)))
      (should (eq (plist-get report :status) 'already-enabled))
      (should (zerop (plist-get report :installed)))
      (should (= (plist-get report :already-matching) 1))
      (should (zerop (plist-get report :preserved-conflicts)))
      (should-not (plist-get report :conflicts)))))

(ert-deftest tmux-emacs-csi-u-test-already-matching-external-binding-does-not-reclaim-ownership ()
  (let* ((sequence "\e[59;2u")
         (keymap (make-sparse-keymap))
         (owned-bindings (make-hash-table :test 'equal)))
    (tmux-emacs-csi-u-core-install-table
     `((,sequence . [?:])) keymap 'force-enable owned-bindings)
    (define-key keymap sequence [f13])
    (let ((match-report (tmux-emacs-csi-u-core-install-table
                         `((,sequence . [f13]))
                         keymap
                         'force-enable
                         owned-bindings)))
      (should (eq (plist-get match-report :status) 'already-enabled))
      (should (zerop (plist-get match-report :installed)))
      (should (= (plist-get match-report :already-matching) 1))
      (should (eq (tmux-emacs-csi-u-core--owned-binding owned-bindings sequence)
                  tmux-emacs-csi-u-core--missing-owned-binding)))
    (let* ((report (tmux-emacs-csi-u-core-install-table
                    `((,sequence . [f14]))
                    keymap
                    'force-enable
                    owned-bindings))
           (conflict (car (plist-get report :conflicts))))
      (should (eq (plist-get report :status) 'partial))
      (should (zerop (plist-get report :installed)))
      (should (= (plist-get report :preserved-conflicts) 1))
      (should (equal (plist-get conflict :existing) "[f13]"))
      (should (equal (plist-get conflict :candidate) "[f14]"))
      (should (equal (lookup-key keymap sequence) [f13])))))

(ert-deftest tmux-emacs-csi-u-test-conflict-reporting ()
  (let* ((keymap (make-sparse-keymap))
         (table '(("\e[59;2u" . [?:]))))
    (define-key keymap "\e[59;2u" [f13])
    (let* ((report (tmux-emacs-csi-u-core-install-table table keymap 'force-enable))
           (conflict (car (plist-get report :conflicts)))
           (rendered (tmux-emacs-csi-u--render-report report)))
      (should (eq (plist-get report :status) 'partial))
      (should (= (plist-get report :preserved-conflicts) 1))
      (should (equal (plist-get conflict :sequence) "\\\\e[59;2u"))
      (should (equal (plist-get conflict :existing) "[f13]"))
      (should (equal (plist-get conflict :candidate) "[58]"))
      (should (string-match-p (regexp-quote "existing=<f13>") rendered))
      (should (string-match-p (regexp-quote "candidate=:") rendered))
      (should-not (string-match-p (regexp-quote "candidate=[58]") rendered)))))

(ert-deftest tmux-emacs-csi-u-test-conflict-reporting-humanizes-modified-baseline-keys ()
  (let* ((keymap (make-sparse-keymap))
         (table `(("\e[32;6u" . ,(kbd "C-S-SPC")))))
    (define-key keymap "\e[32;6u" [f13])
    (let* ((report (tmux-emacs-csi-u-core-install-table table keymap 'force-enable))
           (conflict (car (plist-get report :conflicts)))
           (rendered (tmux-emacs-csi-u--render-report report)))
      (should (equal (plist-get conflict :existing) "[f13]"))
      (should (equal (plist-get conflict :candidate) "[100663328]"))
      (should (string-match-p (regexp-quote "candidate=C-S-SPC") rendered))
      (should-not (string-match-p (regexp-quote "candidate=[100663328]") rendered)))))

(ert-deftest tmux-emacs-csi-u-test-batch-suite-loads-source-files ()
  (should (equal (file-truename
                  (symbol-file 'tmux-emacs-csi-u-data-generated-printable-table
                               'defun))
                 (file-truename
                  (expand-file-name "tmux-emacs-csi-u-data.el"
                                    tmux-emacs-csi-u-test--root-dir))))
  (should (equal (file-truename (symbol-file 'tmux-emacs-csi-u-enable 'defun))
                 (file-truename
                  (expand-file-name "tmux-emacs-csi-u.el"
                                    tmux-emacs-csi-u-test--root-dir))))
  (should (equal (file-truename
                  (symbol-file 'tmux-emacs-csi-u-core-install-table 'defun))
                 (file-truename
                  (expand-file-name "tmux-emacs-csi-u-core.el"
                                    tmux-emacs-csi-u-test--root-dir)))))

(ert-deftest tmux-emacs-csi-u-test-enable-uses-explicit-frame-terminal-map ()
  (let* ((selected 'selected-frame)
         (target 'target-frame)
         (selected-keymap (make-sparse-keymap))
         (target-keymap (make-sparse-keymap))
         requested-frame
         report)
    (cl-letf (((symbol-function 'selected-frame) (lambda () selected))
              ((symbol-function 'tmux-emacs-csi-u--support-state)
               (lambda (frame)
                 (should (eq frame target))
                 '(:support-signal force-enable)))
              ((symbol-function 'tmux-emacs-csi-u--frame-input-decode-map)
               (lambda (frame)
                 (setq requested-frame frame)
                 target-keymap))
              ((symbol-function 'tmux-emacs-csi-u--warn-on-new-conflicts)
               (lambda (&rest _args)
                 (ert-fail "Unexpected conflict warning"))))
      (let ((input-decode-map selected-keymap)
            (tmux-emacs-csi-u-last-report nil))
        (setq report (tmux-emacs-csi-u-enable target))))
    (should (eq requested-frame target))
    (should (eq (plist-get report :status) 'installed))
    (should (equal (lookup-key target-keymap "\e[59;2u") [?:]))
    (should-not (equal (lookup-key selected-keymap "\e[59;2u") [?:]))))

(ert-deftest tmux-emacs-csi-u-test-enable-installs-per-terminal-map ()
  (let* ((frame-a 'frame-a)
         (frame-b 'frame-b)
         (selected-keymap (make-sparse-keymap))
         (keymap-a (make-sparse-keymap))
         (keymap-b (make-sparse-keymap))
         report-a
         report-b)
    (cl-letf (((symbol-function 'tmux-emacs-csi-u--support-state)
               (lambda (_frame) '(:support-signal force-enable)))
              ((symbol-function 'tmux-emacs-csi-u--frame-input-decode-map)
               (lambda (frame)
                 (pcase frame
                   ('frame-a keymap-a)
                   ('frame-b keymap-b)
                   (_ (ert-fail (format "Unexpected frame %S" frame))))))
              ((symbol-function 'tmux-emacs-csi-u--warn-on-new-conflicts)
               (lambda (&rest _args)
                 (ert-fail "Unexpected conflict warning"))))
      (let ((input-decode-map selected-keymap)
            (tmux-emacs-csi-u-last-report nil))
        (setq report-a (tmux-emacs-csi-u-enable frame-a))
        (setq report-b (tmux-emacs-csi-u-enable frame-b))))
    (should (eq (plist-get report-a :status) 'installed))
    (should (eq (plist-get report-b :status) 'installed))
    (should (equal (lookup-key keymap-a "\e[59;2u") [?:]))
    (should (equal (lookup-key keymap-b "\e[59;2u") [?:]))
    (should-not (equal (lookup-key selected-keymap "\e[59;2u") [?:]))))

(ert-deftest tmux-emacs-csi-u-test-enable-skips-unsupported-without-resolving-terminal-map ()
  (let* ((frame 'unsupported-frame)
         (selected-keymap (make-sparse-keymap))
         report)
    (cl-letf (((symbol-function 'tmux-emacs-csi-u--support-state)
               (lambda (requested-frame)
                 (should (eq requested-frame frame))
                 '(:support-signal unsupported
				   :unsupported-reason non-tmux-tty
				   :tty-type "xterm-256color")))
              ((symbol-function 'tmux-emacs-csi-u--frame-input-decode-map)
               (lambda (&rest _args)
                 (ert-fail "Unsupported enable must not resolve the terminal-local decode map")))
              ((symbol-function 'tmux-emacs-csi-u--warn-on-new-conflicts)
               (lambda (&rest _args)
                 (ert-fail "Unexpected conflict warning"))))
      (let ((input-decode-map selected-keymap)
            (tmux-emacs-csi-u-last-report nil))
        (setq report (tmux-emacs-csi-u-enable frame))))
    (should (eq (plist-get report :support-signal) 'unsupported))
    (should (eq (plist-get report :status) 'skipped))
    (should (zerop (plist-get report :installed)))
    (should (= (plist-get report :unsupported-or-skipped)
               (length (tmux-emacs-csi-u--candidate-table))))
    (let ((rendered (tmux-emacs-csi-u--render-report report)))
      (should (string-match-p (regexp-quote "skip-reason: non-tmux-tty") rendered))
      (should (string-match-p (regexp-quote "tty-type: xterm-256color") rendered)))
    (should-not (equal (lookup-key selected-keymap "\e[59;2u") [?:]))))

(ert-deftest tmux-emacs-csi-u-test-enable-updates-last-report ()
  (let ((input-decode-map (make-sparse-keymap))
        (tmux-emacs-csi-u-last-report nil))
    (cl-letf (((symbol-function 'tmux-emacs-csi-u--support-state)
               (lambda (&optional _frame) '(:support-signal force-enable)))
              ((symbol-function 'tmux-emacs-csi-u--warn-on-new-conflicts)
               (lambda (&rest _args)
                 (ert-fail "Unexpected conflict warning"))))
      (let ((report (tmux-emacs-csi-u-enable)))
        (should (eq (plist-get report :support-signal) 'force-enable))
        (should (eq (plist-get report :status) 'installed))
        (should (equal report (tmux-emacs-csi-u-describe)))))))

(ert-deftest tmux-emacs-csi-u-test-auto-enable-syncs-tty-setup-hook ()
  (let ((saved-hook tty-setup-hook)
        (saved-value tmux-emacs-csi-u-auto-enable))
    (unwind-protect
        (progn
          (setq tty-setup-hook
                '(user-hook-a tmux-emacs-csi-u--tty-setup-enable user-hook-b))
          (tmux-emacs-csi-u--sync-tty-setup-hook nil)
          (should (equal tty-setup-hook '(user-hook-a user-hook-b)))
          (tmux-emacs-csi-u--set-auto-enable 'tmux-emacs-csi-u-auto-enable t)
          (should (equal tty-setup-hook
                         '(user-hook-a user-hook-b
				       tmux-emacs-csi-u--tty-setup-enable)))
          (should (= (cl-count #'tmux-emacs-csi-u--tty-setup-enable tty-setup-hook) 1))
          (tmux-emacs-csi-u--sync-tty-setup-hook t)
          (should (equal tty-setup-hook
                         '(user-hook-a user-hook-b
				       tmux-emacs-csi-u--tty-setup-enable)))
          (tmux-emacs-csi-u--set-auto-enable 'tmux-emacs-csi-u-auto-enable nil)
          (should (equal tty-setup-hook '(user-hook-a user-hook-b))))
      (setq tty-setup-hook saved-hook)
      (setq tmux-emacs-csi-u-auto-enable saved-value)
      (tmux-emacs-csi-u--sync-tty-setup-hook tmux-emacs-csi-u-auto-enable))))

(ert-deftest tmux-emacs-csi-u-test-owned-bindings-cache-uses-weak-keys ()
  (let* ((keymap (make-sparse-keymap))
         (owned-a (tmux-emacs-csi-u--owned-bindings keymap))
         (owned-b (tmux-emacs-csi-u--owned-bindings keymap)))
    (should (eq (hash-table-weakness tmux-emacs-csi-u--owned-bindings-by-keymap)
                'key))
    (should (hash-table-p owned-a))
    (should (eq owned-a owned-b))
    (should (eq (gethash keymap tmux-emacs-csi-u--owned-bindings-by-keymap)
                owned-a))))

(ert-deftest tmux-emacs-csi-u-test-tty-setup-hook-enables-selected-frame ()
  (let (called-frame)
    (cl-letf (((symbol-function 'selected-frame) (lambda () 'hook-frame))
              ((symbol-function 'tmux-emacs-csi-u-enable)
               (lambda (&optional frame)
                 (setq called-frame frame)
                 '(:status installed))))
      (should (equal (tmux-emacs-csi-u--tty-setup-enable)
                     '(:status installed)))
      (should (eq called-frame 'hook-frame)))))

(ert-deftest tmux-emacs-csi-u-test-enable-installs-local-override-binding ()
  (let ((input-decode-map (make-sparse-keymap))
        (tmux-emacs-csi-u-last-report nil)
        (tmux-emacs-csi-u-local-overrides '(("\e[59;2u" . [f13]))))
    (cl-letf (((symbol-function 'tmux-emacs-csi-u--support-state)
               (lambda (&optional _frame) '(:support-signal force-enable)))
              ((symbol-function 'tmux-emacs-csi-u--warn-on-new-conflicts)
               (lambda (&rest _args)
                 (ert-fail "Unexpected conflict warning"))))
      (let ((report (tmux-emacs-csi-u-enable)))
        (should (eq (plist-get report :status) 'installed))
        (should (= (plist-get report :installed)
                   (length (tmux-emacs-csi-u--candidate-table))))
        (should (equal (lookup-key input-decode-map "\e[59;2u") [f13]))
        (should (equal report tmux-emacs-csi-u-last-report))))))

(ert-deftest tmux-emacs-csi-u-test-enable-replaces-package-owned-binding-on-reenable ()
  (let ((input-decode-map (make-sparse-keymap))
        (tmux-emacs-csi-u-last-report nil)
        (tmux-emacs-csi-u-local-overrides nil))
    (cl-letf (((symbol-function 'tmux-emacs-csi-u--support-state)
               (lambda (&optional _frame) '(:support-signal force-enable)))
              ((symbol-function 'tmux-emacs-csi-u--warn-on-new-conflicts)
               (lambda (&rest _args)
                 (ert-fail "Unexpected conflict warning"))))
      (let ((initial-report (tmux-emacs-csi-u-enable)))
        (should (eq (plist-get initial-report :status) 'installed))
        (should (equal (lookup-key input-decode-map "\e[59;2u") [?:]))
        (setq tmux-emacs-csi-u-local-overrides '(("\e[59;2u" . [f13])))
        (let ((override-report (tmux-emacs-csi-u-enable)))
          (should (eq (plist-get override-report :status) 'installed))
          (should (= (plist-get override-report :installed) 1))
          (should (zerop (plist-get override-report :preserved-conflicts)))
          (should (equal (lookup-key input-decode-map "\e[59;2u") [f13]))
          (should (equal override-report tmux-emacs-csi-u-last-report)))))))

(ert-deftest tmux-emacs-csi-u-test-enable-removes-package-owned-binding-when-sequence-is-no-longer-claimed ()
  (let ((input-decode-map (make-sparse-keymap))
        (tmux-emacs-csi-u-last-report nil)
        (tmux-emacs-csi-u-local-overrides '(("\e[1000;2u" . [f14])))
        (sequence "\e[1000;2u"))
    (cl-letf (((symbol-function 'tmux-emacs-csi-u--support-state)
               (lambda (&optional _frame) '(:support-signal force-enable)))
              ((symbol-function 'tmux-emacs-csi-u--warn-on-new-conflicts)
               (lambda (&rest _args)
                 (ert-fail "Unexpected conflict warning"))))
      (let ((initial-report (tmux-emacs-csi-u-enable)))
        (should (eq (plist-get initial-report :status) 'installed))
        (should (equal (lookup-key input-decode-map sequence) [f14]))
        (setq tmux-emacs-csi-u-local-overrides nil)
        (let ((report (tmux-emacs-csi-u-enable)))
          (should (eq (plist-get report :status) 'already-enabled))
          (should (null (lookup-key input-decode-map sequence)))
          (should (equal report tmux-emacs-csi-u-last-report)))))))

(ert-deftest tmux-emacs-csi-u-test-enable-preserves-same-valued-external-binding-when-sequence-is-no-longer-claimed ()
  (let ((input-decode-map (make-sparse-keymap))
        (tmux-emacs-csi-u-last-report nil)
        (tmux-emacs-csi-u-local-overrides '(("\e[1000;2u" . [f14])))
        (sequence "\e[1000;2u"))
    (cl-letf (((symbol-function 'tmux-emacs-csi-u--support-state)
               (lambda (&optional _frame) '(:support-signal force-enable)))
              ((symbol-function 'tmux-emacs-csi-u--warn-on-new-conflicts)
               (lambda (&rest _args)
                 (ert-fail "Unexpected conflict warning"))))
      (let ((initial-report (tmux-emacs-csi-u-enable)))
        (should (eq (plist-get initial-report :status) 'installed))
        (let ((external-binding (vector 'f14)))
          (define-key input-decode-map sequence external-binding)
          (setq tmux-emacs-csi-u-local-overrides nil)
          (let ((report (tmux-emacs-csi-u-enable)))
            (should (eq (plist-get report :status) 'already-enabled))
            (should (eq (lookup-key input-decode-map sequence)
                        external-binding))
            (should (eq (tmux-emacs-csi-u-core--owned-binding
                         (tmux-emacs-csi-u--owned-bindings input-decode-map)
                         sequence)
                        tmux-emacs-csi-u-core--missing-owned-binding))
            (should (equal report tmux-emacs-csi-u-last-report))))))))

(ert-deftest tmux-emacs-csi-u-test-enable-preserves-truly-external-binding-on-reenable ()
  (let ((input-decode-map (make-sparse-keymap))
        (tmux-emacs-csi-u-local-overrides nil)
        warned-conflicts)
    (cl-letf (((symbol-function 'tmux-emacs-csi-u--support-state)
               (lambda (&optional _frame) '(:support-signal force-enable)))
              ((symbol-function 'tmux-emacs-csi-u--warn-on-new-conflicts)
               (lambda (_frame conflicts)
                 (setq warned-conflicts conflicts))))
      (should (eq (plist-get (tmux-emacs-csi-u-enable) :status) 'installed))
      (define-key input-decode-map "\e[59;2u" [f14])
      (setq tmux-emacs-csi-u-local-overrides '(("\e[59;2u" . [f13])))
      (let ((report (tmux-emacs-csi-u-enable)))
        (should (eq (plist-get report :status) 'partial))
        (should (zerop (plist-get report :installed)))
        (should (= (plist-get report :preserved-conflicts) 1))
        (should (equal (lookup-key input-decode-map "\e[59;2u") [f14]))
        (should (equal warned-conflicts (plist-get report :conflicts)))))))

(ert-deftest tmux-emacs-csi-u-test-warn-on-new-conflicts-reports-current-preserved-count ()
  (let* ((frame 'frame)
         (terminal 'terminal)
         (param 'tmux-emacs-csi-u--warned-conflicts)
         (existing-conflict '(:sequence "\\\\e[59;2u" :existing "[f13]" :candidate "[58]"))
         (new-conflict '(:sequence "\\\\e[63;2u" :existing "[f14]" :candidate "[63]"))
         (terminal-params
          `((,param . (,(prin1-to-string existing-conflict)))))
         warnings)
    (cl-letf (((symbol-function 'frame-terminal)
               (lambda (requested-frame)
                 (should (eq requested-frame frame))
                 terminal))
              ((symbol-function 'terminal-parameter)
               (lambda (requested-terminal requested-param)
                 (should (eq requested-terminal terminal))
                 (alist-get requested-param terminal-params)))
              ((symbol-function 'set-terminal-parameter)
               (lambda (requested-terminal requested-param value)
                 (should (eq requested-terminal terminal))
                 (setf (alist-get requested-param terminal-params) value)))
              ((symbol-function 'display-warning)
               (lambda (_type message &optional level)
                 (should (eq level :warning))
                 (push message warnings))))
      (tmux-emacs-csi-u--warn-on-new-conflicts
       frame
       (list existing-conflict new-conflict))
      (tmux-emacs-csi-u--warn-on-new-conflicts
       frame
       (list existing-conflict new-conflict)))
    (should (equal warnings
                   '("2 CSI-u conflicts preserved; inspect (tmux-emacs-csi-u-describe) for details")))
    (should (= (length (alist-get param terminal-params)) 2))))

;;; tmux-emacs-csi-u-test.el ends here
