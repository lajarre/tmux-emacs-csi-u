;;; gate.el --- repo gate helpers -*- lexical-binding: t; -*-

;;; Commentary:

;; Batch helpers for repo-level format, lint, and compile commands.

;;; Code:

(require 'bytecomp)
(require 'checkdoc)
(require 'cl-lib)
(require 'package)
(require 'subr-x)

(declare-function package-lint-buffer "package-lint")

(defconst tmux-emacs-csi-u-script--repo-root
  (file-name-as-directory
   (or (getenv "TMUX_EMACS_CSI_U_REPO_ROOT")
       (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name)))))
  "Absolute repo root with a trailing slash.")

(defconst tmux-emacs-csi-u-script--allowed-package-lint-warnings
  '("The word \"emacs\" is redundant in Emacs package names.")
  "Package-lint warning messages tolerated for this repo.")

(defun tmux-emacs-csi-u-script--tracked-files ()
  "Return Git-tracked files in the repo as absolute paths."
  (mapcar #'tmux-emacs-csi-u-script--repo-file
          (process-lines "git" "-C" tmux-emacs-csi-u-script--repo-root
                         "ls-files")))

(defun tmux-emacs-csi-u-script--repo-file (relative-path)
  "Return RELATIVE-PATH resolved from the repo root."
  (expand-file-name relative-path tmux-emacs-csi-u-script--repo-root))

(defun tmux-emacs-csi-u-script--relative-path (path)
  "Return PATH relative to the repo root."
  (file-relative-name path tmux-emacs-csi-u-script--repo-root))

(defun tmux-emacs-csi-u-script--extension-in-p (path extensions)
  "Return non-nil when PATH has an extension in EXTENSIONS."
  (member (downcase (or (file-name-extension path) "")) extensions))

(defun tmux-emacs-csi-u-script--format-files ()
  "Return repo files covered by the canonical formatter."
  (sort
   (delete-dups
    (cl-remove-if-not
     (lambda (path)
       (tmux-emacs-csi-u-script--extension-in-p
        path '("el" "json" "md" "yml" "yaml")))
     (tmux-emacs-csi-u-script--tracked-files)))
   #'string<))

(defun tmux-emacs-csi-u-script--lint-files ()
  "Return Elisp files covered by `checkdoc'."
  (cl-remove-if-not
   (lambda (path)
     (string= (downcase (or (file-name-extension path) "")) "el"))
   (tmux-emacs-csi-u-script--tracked-files)))

(defun tmux-emacs-csi-u-script--compile-files ()
  "Return Elisp files covered by byte compilation."
  (cl-remove-if-not
   (lambda (path)
     (and (string= (file-name-directory path)
                   tmux-emacs-csi-u-script--repo-root)
          (string= (downcase (or (file-name-extension path) "")) "el")))
   (tmux-emacs-csi-u-script--tracked-files)))

(defun tmux-emacs-csi-u-script--normalize-current-buffer (path)
  "Apply canonical formatting rules to the current buffer for PATH."
  (when (string= (downcase (or (file-name-extension path) "")) "el")
    (delay-mode-hooks
      (emacs-lisp-mode))
    (let ((inhibit-message t))
      (indent-region (point-min) (point-max))))
  (delete-trailing-whitespace)
  (goto-char (point-max))
  (skip-chars-backward "\n")
  (delete-region (point) (point-max))
  (insert "\n"))

(defun tmux-emacs-csi-u-script--format-file (path check-only)
  "Format PATH and return non-nil when formatting would change it.
When CHECK-ONLY is non-nil, do not write the formatted contents."
  (with-temp-buffer
    (insert-file-contents path)
    (let ((before (buffer-string)))
      (tmux-emacs-csi-u-script--normalize-current-buffer path)
      (let ((after (buffer-string)))
        (unless (equal before after)
          (unless check-only
            (write-region nil nil path nil 'silent))
          t)))))

(defun tmux-emacs-csi-u-script--run-format (check-only)
  "Run the formatter with CHECK-ONLY semantics."
  (let (changed)
    (dolist (path (tmux-emacs-csi-u-script--format-files))
      (when (tmux-emacs-csi-u-script--format-file path check-only)
        (push (tmux-emacs-csi-u-script--relative-path path) changed)))
    (setq changed (nreverse changed))
    (cond
     (check-only
      (if changed
          (progn
            (princ "format drift:\n")
            (dolist (path changed)
              (princ (format "- %s\n" path)))
            (kill-emacs 1))
        (princ "format clean\n")))
     (changed
      (princ "formatted files:\n")
      (dolist (path changed)
        (princ (format "- %s\n" path))))
     (t
      (princ "format already clean\n")))))

(defun tmux-emacs-csi-u-script-format ()
  "Apply canonical formatting to repo files in scope."
  (tmux-emacs-csi-u-script--run-format nil))

(defun tmux-emacs-csi-u-script-format-check ()
  "Fail when repo files are not in canonical format."
  (tmux-emacs-csi-u-script--run-format t))

(defun tmux-emacs-csi-u-script--checkdoc-output (path)
  "Return `checkdoc' output for PATH, or nil when PATH is clean."
  (let ((diagnostic-buffer " *tmux-emacs-csi-u-checkdoc*"))
    (when-let ((buffer (get-buffer diagnostic-buffer)))
      (kill-buffer buffer))
    (let* ((existing-buffer (find-buffer-visiting path))
           (buffer (find-file-noselect path)))
      (unwind-protect
          (with-current-buffer buffer
            (let ((checkdoc-diagnostic-buffer diagnostic-buffer)
                  (checkdoc-spellcheck-documentation-flag nil))
              (checkdoc-current-buffer t)))
        (unless existing-buffer
          (kill-buffer buffer))))
    (when-let ((buffer (get-buffer diagnostic-buffer)))
      (prog1
          (with-current-buffer buffer
            (let* ((output (replace-regexp-in-string "\f" "" (buffer-string)))
                   (lines (split-string output "\n" t "[[:space:]]+"))
                   (issue-lines (cl-remove-if
                                 (lambda (line)
                                   (string-prefix-p "*** " line))
                                 lines)))
              (when issue-lines
                (string-join issue-lines "\n"))))
        (kill-buffer buffer)))))

(defun tmux-emacs-csi-u-script--activate-package-archives ()
  "Initialize repo-local package archives for gate helpers."
  (require 'package)
  (setq package-user-dir (tmux-emacs-csi-u-script--repo-file ".tmp/elpa"))
  (setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                           ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
  (package-initialize)
  t)

(defun tmux-emacs-csi-u-script-bootstrap-package-lint ()
  "Install `package-lint' into the repo-local package dir."
  (tmux-emacs-csi-u-script--activate-package-archives)
  (unless (package-installed-p 'package-lint)
    (unless package-archive-contents
      (package-refresh-contents))
    (package-install 'package-lint))
  (princ "package-lint ready\n"))

(defun tmux-emacs-csi-u-script--package-lint-issues ()
  "Return `package-lint' issues for the package entrypoint."
  (tmux-emacs-csi-u-script--activate-package-archives)
  (unless (require 'package-lint nil t)
    (tmux-emacs-csi-u-script-bootstrap-package-lint)
    (package-initialize)
    (require 'package-lint))
  (with-current-buffer (find-file-noselect
                        (tmux-emacs-csi-u-script--repo-file "tmux-emacs-csi-u.el"))
    (package-lint-buffer)))

(defun tmux-emacs-csi-u-script--print-package-lint-issues (issues)
  "Print package-lint ISSUES in a grep-friendly format."
  (dolist (issue issues)
    (pcase-let ((`(,line ,column ,level ,message) issue))
      (princ
       (format "%s:%d:%d: %s: %s\n"
               "tmux-emacs-csi-u.el"
               line
               column
               (upcase (symbol-name level))
               message)))))

(defun tmux-emacs-csi-u-script--package-lint-warning-allowed-p (issue)
  "Return non-nil when package-lint ISSUE is explicitly allowed."
  (member (nth 3 issue)
          tmux-emacs-csi-u-script--allowed-package-lint-warnings))

(defun tmux-emacs-csi-u-script-lint ()
  "Run repo lint gates."
  (let (checkdoc-failures)
    (dolist (path (tmux-emacs-csi-u-script--lint-files))
      (when-let ((output (tmux-emacs-csi-u-script--checkdoc-output path)))
        (push (cons path output) checkdoc-failures)))
    (setq checkdoc-failures (nreverse checkdoc-failures))
    (when checkdoc-failures
      (princ "checkdoc failures:\n")
      (dolist (failure checkdoc-failures)
        (princ (format "[%s]\n%s\n"
                       (tmux-emacs-csi-u-script--relative-path (car failure))
                       (cdr failure)))))
    (let* ((issues (tmux-emacs-csi-u-script--package-lint-issues))
           (warnings (cl-remove-if-not (lambda (issue)
                                         (eq (nth 2 issue) 'warning))
                                       issues))
           (allowed-warnings (cl-remove-if-not
                              #'tmux-emacs-csi-u-script--package-lint-warning-allowed-p
                              warnings))
           (unexpected-warnings (cl-set-difference warnings allowed-warnings :test #'equal))
           (errors (cl-remove-if-not (lambda (issue)
                                       (eq (nth 2 issue) 'error))
                                     issues)))
      (when allowed-warnings
        (princ "package-lint allowed warnings:\n")
        (tmux-emacs-csi-u-script--print-package-lint-issues allowed-warnings))
      (when unexpected-warnings
        (princ "package-lint warnings:\n")
        (tmux-emacs-csi-u-script--print-package-lint-issues unexpected-warnings))
      (when errors
        (princ "package-lint errors:\n")
        (tmux-emacs-csi-u-script--print-package-lint-issues errors))
      (if (or checkdoc-failures unexpected-warnings errors)
          (kill-emacs 1)
        (princ "lint ok\n")))))

(defvar tmux-emacs-csi-u-script--compile-output-dir nil
  "Dynamic output dir used by `byte-compile-dest-file-function'.")

(defun tmux-emacs-csi-u-script--compile-dest-file (filename)
  "Return the byte-compile destination for FILENAME."
  (let* ((relative (tmux-emacs-csi-u-script--relative-path filename))
         (destination (expand-file-name relative
                                        tmux-emacs-csi-u-script--compile-output-dir)))
    (make-directory (file-name-directory destination) t)
    (concat (file-name-sans-extension destination) ".elc")))

(defun tmux-emacs-csi-u-script--compile-file-or-die (path)
  "Byte-compile PATH and exit non-zero on any compile log entry."
  (when-let ((buffer (get-buffer byte-compile-log-buffer)))
    (kill-buffer buffer))
  (byte-compile-file path)
  (when-let ((buffer (get-buffer byte-compile-log-buffer)))
    (let ((output (with-current-buffer buffer
                    (string-trim (buffer-string)))))
      (kill-buffer buffer)
      (unless (string-empty-p output)
        (princ (format "[%s]\n%s\n"
                       (tmux-emacs-csi-u-script--relative-path path)
                       output))
        (kill-emacs 1)))))

(defun tmux-emacs-csi-u-script-compile ()
  "Byte-compile package files with warnings treated as failures."
  (let* ((tmux-emacs-csi-u-script--compile-output-dir
          (tmux-emacs-csi-u-script--repo-file ".tmp/elc"))
         (byte-compile-error-on-warn t)
         (load-prefer-newer t)
         (byte-compile-dest-file-function
          #'tmux-emacs-csi-u-script--compile-dest-file))
    (dolist (path (tmux-emacs-csi-u-script--compile-files))
      (tmux-emacs-csi-u-script--compile-file-or-die path))
    (princ "compile ok\n")))

(provide 'gate)
;;; gate.el ends here
