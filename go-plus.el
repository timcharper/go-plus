;;;  go-plus.el -- A handful of helpers for go-mode.

;; Copyright (c) 2015 Tim Harper <tim@spacemonkey.com>

;; Licensed under the same terms as Emacs.

;; Keywords: go
;; Created: 14 Dec 2015
;; Author: Tim Harper <tim@spacemonkey.com>
;; Version: 1

;; This file is NOT part of GNU Emacs.

;;; Commentary:

;; Contains helpers to:
;; - toggle between a test suite and implementation ({name}_test.go convention assumed)
;; - copy command to killring to run a test as apoint.
;; - compile and run a buffer / test suite.

(require 'ansi-color)

(defun colorize-compilation-buffer ()
  (toggle-read-only)
  (ansi-color-apply-on-region (point-min) (point-max))
  (toggle-read-only))

(defun go-plus:run-command-in-compile-mode (cmd)
  (let* ((wrapped (format "bash -x -c %S" cmd))
         (buffer (compile wrapped)))
    (set-buffer buffer)
    (add-hook 'compilation-filter-hook 'colorize-compilation-buffer t)))

(defun go-plus:compile-and-run-buffer ()
  "Run the current go file in a compile buffer"
  (interactive)
  (save-buffer)
  (let ((cmd (if (go-plus:is-test (buffer-file-name))
                 (go-plus:test-command-for-point)
               (format "cd %S; go run %S"
                      (file-name-directory (buffer-file-name))
                      (file-name-nondirectory (buffer-file-name))))))
    (go-plus:run-command-in-compile-mode cmd)))

(defun go-plus:guess-test-name ()
  "Returns the go function containing the current point."
  (let ((point-start))
    (condition-case nil
        (save-excursion
          (search-backward-regexp "^func Test")
          (search-forward-regexp "^func \*")
          (setq point-start (point))
          (forward-sexp)
          (buffer-substring-no-properties point-start (point)))
      (error nil))))

(defun go-plus:test-command-for-point ()
  (let* ((test-name (go-plus:guess-test-name))
         (path (file-name-directory buffer-file-name))
         (cmd (if test-name
                  (format "cd %S; go test --run %S" path test-name)
                (format "cd %S; go test" path))))
    cmd))

(defun go-plus:copy-test-command ()
  "Copies expression necessary to run the current test suite in an sbt repl"
  (interactive)
  (let* ((cmd (go-plus:test-command-for-point)))
    (kill-new cmd)
    (message "Copied '%s' to the killring" cmd)))

(defun go-plus:is-test (path)
  (let ((test-regex "^\\(.+\\)_test.go" ))
    (if (string-match test-regex path)
        t
      nil)))

(defun go-plus:toggle-test ()
  "Toggle between test and code"
  (interactive)
  (let* ((path buffer-file-name)
         (main-regex "^\\(.+\\).go")
         (other-path 
          (cond ((go-plus:is-test path)
                 (format "%s.go" 
                         (match-string 1 path)))
                ((string-match main-regex path)
                 (format "%s_test.go" 
                         (match-string 1 path))))))
    (message "%s" other-path)
    (find-file other-path)))

(eval-after-load 'go-mode
  '(progn
     (define-key go-mode-map (kbd "s-R") 'go-plus:copy-test-command)
     (define-key go-mode-map (kbd "s-r") 'go-plus:compile-and-run-buffer)
     (define-key go-mode-map (kbd "C-c , t") 'go-plus:toggle-test)))
