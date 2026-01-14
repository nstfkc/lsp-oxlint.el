;;; lsp-oxlint.el --- LSP client for Oxlint -*- lexical-binding: t -*-

;; Author: Enes Tufekci
;; URL: https://github.com/nstfkc/lsp-oxlint.el
;; Keywords: languages, tools, javascript, typescript, lsp
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (lsp-mode "8.0.0"))

;; This file is not part of GNU Emacs.

;;; Commentary:

;; This package provides an LSP client for Oxlint, a fast JavaScript/TypeScript
;; linter written in Rust.  It integrates with lsp-mode to provide real-time
;; linting diagnostics and code actions.
;;
;; Features:
;; - Automatic activation for JS/TS/MD files when oxlint is available
;; - Supports: .js, .jsx, .ts, .tsx, .mjs, .cjs, .mts, .cts, .md, .mdx
;; - Monorepo support (searches upward for config and binary)
;; - Auto-fix on save support
;; - Runs as an add-on alongside other LSP servers (e.g., typescript-language-server)
;; - Auto-loads when lsp-mode is enabled (no manual require needed)
;;
;; Usage:
;; 1. Install oxlint in your project: npm install -D oxlint
;; 2. Create .oxlintrc.json in your project root
;; 3. Open a supported file and run M-x lsp
;;
;; Configuration:
;; (setq lsp-oxlint-autofix-on-save t)  ; Enable auto-fix on save
;;
;; Commands:
;; M-x lsp-oxlint-fix  - Apply fixable issues in current buffer
;; M-x lsp-oxlint-verify-setup - Debug activation issues

;;; Code:

(require 'lsp-mode)

(defgroup lsp-oxlint nil
  "LSP support for Oxlint."
  :group 'lsp-mode
  :link '(url-link "https://oxc.rs/docs/guide/usage/linter"))

(defcustom lsp-oxlint-active-file-types
  (list (rx "." (or "tsx" "jsx" "ts" "js" "mts" "mjs" "cts" "cjs" "md" "mdx") eos))
  "File types that lsp-oxlint should activate for."
  :type '(repeat regexp)
  :group 'lsp-oxlint)

(defcustom lsp-oxlint-autofix-on-save nil
  "When non-nil, automatically apply oxlint fixes before saving."
  :type 'boolean
  :group 'lsp-oxlint)

(defcustom lsp-oxlint-config-file ".oxlintrc.json"
  "Name of the oxlint configuration file."
  :type 'string
  :group 'lsp-oxlint)

(defvar-local lsp-oxlint--bin-path nil
  "Buffer-local path to the oxlint binary.")

(defvar-local lsp-oxlint--activated-p nil
  "Buffer-local flag indicating if oxlint LSP is active.")

(defun lsp-oxlint--find-config (start-dir)
  "Find oxlint config file starting from START-DIR and searching upward."
  (locate-dominating-file start-dir lsp-oxlint-config-file))

(defun lsp-oxlint--find-bin (start-dir)
  "Find oxlint binary starting from START-DIR and searching upward.
Searches for node_modules/.bin/oxlint in parent directories."
  (when-let* ((bin-root (locate-dominating-file
                         start-dir "node_modules/.bin/oxlint")))
    (expand-file-name "node_modules/.bin/oxlint" bin-root)))

(defun lsp-oxlint--file-can-be-activated (filename)
  "Check if FILENAME matches any of the active file types."
  (seq-some (lambda (pattern) (string-match-p pattern filename))
            lsp-oxlint-active-file-types))

(defun lsp-oxlint--activate-p (filename &optional _)
  "Check if oxlint LSP should activate for FILENAME.
Returns non-nil if:
- File type is supported
- Config file exists in project tree
- Oxlint binary is found in node_modules"
  (when-let* ((file-dir (file-name-directory filename))
              ((lsp-oxlint--file-can-be-activated filename))
              ((lsp-oxlint--find-config file-dir))
              (bin (lsp-oxlint--find-bin file-dir)))
    (setq-local lsp-oxlint--bin-path bin)
    t))

;;;###autoload
(defun lsp-oxlint-fix ()
  "Apply all fixable oxlint issues in the current buffer."
  (interactive)
  (condition-case nil
      (lsp-execute-code-action-by-kind "source.fixAll.oxlint")
    (lsp-no-code-actions
     (when (called-interactively-p 'any)
       (message "Oxlint: No fixes available")))))

;;;###autoload
(defun lsp-oxlint-verify-setup ()
  "Verify oxlint LSP setup and display diagnostic information.
Useful for debugging activation issues."
  (interactive)
  (let* ((filename (buffer-file-name))
         (file-dir (and filename (file-name-directory filename)))
         (file-type-ok (and filename (lsp-oxlint--file-can-be-activated filename)))
         (config-dir (and file-dir (lsp-oxlint--find-config file-dir)))
         (config-path (and config-dir
                           (expand-file-name lsp-oxlint-config-file config-dir)))
         (bin-path (and file-dir (lsp-oxlint--find-bin file-dir)))
         (bin-exists (and bin-path (file-exists-p bin-path)))
         (bin-executable (and bin-exists (file-executable-p bin-path))))
    (with-current-buffer (get-buffer-create "*lsp-oxlint-verify*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "=== Oxlint LSP Setup Verification ===\n\n")
        (insert (format "Current file: %s\n" (or filename "N/A")))
        (insert (format "File directory: %s\n\n" (or file-dir "N/A")))
        (insert "--- Checks ---\n\n")
        (insert (format "[%s] File type supported: %s\n"
                        (if file-type-ok "OK" "FAIL")
                        (if filename (file-name-extension filename) "no file")))
        (insert (format "[%s] Config file (%s): %s\n"
                        (if config-path "OK" "FAIL")
                        lsp-oxlint-config-file
                        (or config-path "not found")))
        (insert (format "[%s] Binary found: %s\n"
                        (if bin-exists "OK" "FAIL")
                        (or bin-path "not found")))
        (insert (format "[%s] Binary executable: %s\n"
                        (if bin-executable "OK" "FAIL")
                        (if bin-executable "yes" "no")))
        (insert "\n--- Summary ---\n\n")
        (if (and file-type-ok config-path bin-exists bin-executable)
            (insert "All checks passed! Run M-x lsp to start.\n")
          (insert "Issues found:\n")
          (unless file-type-ok
            (insert "  - Open a supported file (.js, .ts, .md, .mdx, etc.)\n"))
          (unless config-path
            (insert (format "  - Create %s in your project root\n"
                            lsp-oxlint-config-file)))
          (unless bin-exists
            (insert "  - Run: npm install -D oxlint\n"))))
      (special-mode)
      (goto-char (point-min))
      (display-buffer (current-buffer)))))

(defun lsp-oxlint--workspace-p (workspace)
  "Return non-nil if WORKSPACE is an oxlint workspace."
  (eq (lsp--client-server-id (lsp--workspace-client workspace)) 'oxlint))

(defun lsp-oxlint--before-save-hook ()
  "Hook function to run oxlint fixes before save."
  (when lsp-oxlint-autofix-on-save
    (ignore-errors
      (lsp-oxlint-fix))))

(defun lsp-oxlint--setup-hooks ()
  "Set up buffer-local hooks for oxlint."
  (when lsp-oxlint-autofix-on-save
    (add-hook 'before-save-hook #'lsp-oxlint--before-save-hook nil t)))

(defun lsp-oxlint--teardown-hooks ()
  "Remove buffer-local hooks for oxlint."
  (remove-hook 'before-save-hook #'lsp-oxlint--before-save-hook t))

(lsp-register-client
 (make-lsp-client
  :new-connection (lsp-stdio-connection
                   (lambda ()
                     (setq-local lsp-oxlint--activated-p t)
                     (list lsp-oxlint--bin-path "--lsp")))
  :activation-fn #'lsp-oxlint--activate-p
  :server-id 'oxlint
  :priority -1
  :add-on? t))

(with-eval-after-load 'lsp-mode
  (add-hook 'lsp-after-open-hook
            (lambda ()
              (when (and lsp-oxlint--activated-p
                         (lsp-oxlint--workspace-p lsp--cur-workspace))
                (lsp-oxlint--setup-hooks))))

  (add-hook 'lsp-after-uninitialized-functions
            (lambda (workspace)
              (when (lsp-oxlint--workspace-p workspace)
                (lsp-oxlint--teardown-hooks)
                (setq-local lsp-oxlint--activated-p nil)))))

(provide 'lsp-oxlint)
;;; lsp-oxlint.el ends here
