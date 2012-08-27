;;; rcodetools.el -- annotation / accurate completion / browsing documentation

;;; Copyright (c) 2006-2008 rubikitch <rubikitch@ruby-lang.org>
;;;
;;; Use and distribution subject to the terms of the Ruby license.

(defvar xmpfilter-command-name "ruby -S xmpfilter --dev --fork --detect-rbtest"
  "The xmpfilter command name.")
(defvar rct-doc-command-name "ruby -S rct-doc --dev --fork --detect-rbtest"
  "The rct-doc command name.")
(defvar rct-complete-command-name "ruby -S rct-complete --dev --fork --detect-rbtest"
  "The rct-complete command name.")
(defvar ruby-toggle-file-command-name "ruby -S ruby-toggle-file"
  "The ruby-toggle-file command name.")
(defvar rct-fork-command-name "ruby -S rct-fork")
(defvar rct-option-history nil)                ;internal
(defvar rct-option-local nil)     ;internal
(make-variable-buffer-local 'rct-option-local)
(defvar rct-debug nil
  "If non-nil, output debug message into *Messages*.")
;; (setq rct-debug t)

(defadvice comment-dwim (around rct-hack activate)
  "If comment-dwim is successively called, add => mark."
  (if (and (eq major-mode 'ruby-mode)
           (eq last-command 'comment-dwim)
           ;; TODO =>check
           )
      (insert "=>")
    ad-do-it))
;; To remove this advice.
;; (progn (ad-disable-advice 'comment-dwim 'around 'rct-hack) (ad-update 'comment-dwim)) 

(defun rct-current-line ()
  "Return the vertical position of point..."
  (+ (count-lines (point-min) (point))
     (if (= (current-column) 0) 1 0)))

(defun rct-save-position (proc)
  "Evaluate proc with saving current-line/current-column/window-start."
  (let ((line (rct-current-line))
        (col  (current-column))
        (wstart (window-start)))
    (funcall proc)
    (goto-char (point-min))
    (forward-line (1- line))
    (move-to-column col)
    (set-window-start (selected-window) wstart)))

(defun rct-interactive ()
  "All the rcodetools-related commands with prefix args read rcodetools' common option. And store option into buffer-local variable."
  (list
   (let ((option (or rct-option-local "")))
     (if current-prefix-arg
         (setq rct-option-local
               (read-from-minibuffer "rcodetools option: " option nil nil 'rct-option-history))
       option))))  

(defun rct-shell-command (command &optional buffer)
  "Replacement for `(shell-command-on-region (point-min) (point-max) command buffer t' because of encoding problem."
  (let ((input-rb (concat (make-temp-name "xmptmp-in") ".rb"))
        (output-rb (concat (make-temp-name "xmptmp-out") ".rb"))
        (coding-system-for-read buffer-file-coding-system))
    (write-region (point-min) (point-max) input-rb nil 'nodisp)
    (shell-command
     (rct-debuglog (format "%s %s > %s" command input-rb output-rb))
     t " *rct-error*")
    (with-current-buffer (or buffer (current-buffer))
      (insert-file-contents output-rb nil nil nil t))
    (delete-file input-rb)
    (delete-file output-rb)))

(defvar xmpfilter-command-function 'xmpfilter-command)
(defun xmp (&optional option)
  "Run xmpfilter for annotation/test/spec on whole buffer.
See also `rct-interactive'. "
  (interactive (rct-interactive))
  (rct-save-position
   (lambda ()
     (rct-shell-command (funcall xmpfilter-command-function option)))))

(defun xmpfilter-command (&optional option)
  "The xmpfilter command line, DWIM."
  (setq option (or option ""))
  (flet ((in-block (beg-re)
                   (save-excursion
                     (goto-char (point-min))
                     (when (re-search-forward beg-re nil t)
                       (let ((s (point)) e)
                         (when (re-search-forward "^end\n" nil t)
                           (setq e (point))
                           (goto-char s)
                           (re-search-forward "# => *$" e t)))))))
    (cond ((in-block "^class.+< Test::Unit::TestCase$")
           (format "%s --unittest %s" xmpfilter-command-name option))
          ((in-block "^\\(describe\\|context\\).+do$")
           (format "%s --spec %s" xmpfilter-command-name option))
          (t
           (format "%s %s" xmpfilter-command-name option)))))

;;;; Completion
(defvar rct-method-completion-table nil) ;internal
(defvar rct-complete-symbol-function 'rct-complete-symbol--normal
  "Function to use rct-complete-symbol.")
;; (setq rct-complete-symbol-function 'rct-complete-symbol--icicles)
(defvar rct-use-test-script t
  "Whether rct-complete/rct-doc use test scripts.")

(defun rct-complete-symbol (&optional option)
  "Perform ruby method and class completion on the text around point.
This command only calls a function according to `rct-complete-symbol-function'.
See also `rct-interactive', `rct-complete-symbol--normal', and `rct-complete-symbol--icicles'."
  (interactive (rct-interactive))
  (call-interactively rct-complete-symbol-function))

(defun rct-complete-symbol--normal (&optional option)
  "Perform ruby method and class completion on the text around point.
See also `rct-interactive'."
  (interactive (rct-interactive))
  (let ((end (point)) beg
	pattern alist
	completion)
    (setq completion (rct-try-completion)) ; set also pattern / completion
    (save-excursion
      (search-backward pattern)
      (setq beg (point)))
    (cond ((eq completion t)            ;sole completion
           (message "%s" "Sole completion"))
	  ((null completion)            ;no completions
	   (message "Can't find completion for \"%s\"" pattern)
	   (ding))
	  ((not (string= pattern completion)) ;partial completion
           (delete-region beg end)      ;delete word
	   (insert completion)
           (message ""))
	  (t
	   (message "Making completion list...")
	   (with-output-to-temp-buffer "*Completions*"
	     (display-completion-list
	      (all-completions pattern alist)))
	   (message "Making completion list...%s" "done")))))

;; (define-key ruby-mode-map "\M-\C-i" 'rct-complete-symbol)

(defun rct-debuglog (logmsg)
  "if `rct-debug' is non-nil, output LOGMSG into *Messages*. Returns LOGMSG."
  (if rct-debug
      (message "%s" logmsg))
  logmsg)

(defun rct-exec-and-eval (command opt)
  "Execute rct-complete/rct-doc and evaluate the output."
  (let ((eval-buffer  (get-buffer-create " *rct-eval*")))
    ;; copy to temporary buffer to do completion at non-EOL.
    (rct-shell-command
     (format "%s %s %s --line=%d --column=%d %s"
             command opt (or rct-option-local "")
             (rct-current-line)
             ;; specify column in BYTE
             (string-bytes
              (encode-coding-string
               (buffer-substring (point-at-bol) (point))
               buffer-file-coding-system))
             (if rct-use-test-script (rct-test-script-option-string) ""))
     eval-buffer)
    (message "")
    (eval (with-current-buffer eval-buffer
            (goto-char 1)
            (unwind-protect
                (read (current-buffer))
              (unless rct-debug (kill-buffer eval-buffer)))))))

(defun rct-test-script-option-string ()
  (if (null buffer-file-name)
      ""
    (let ((test-buf (rct-find-test-script-buffer))
          (bfn buffer-file-name)
          bfn2 t-opt test-filename)
      (if (and test-buf
               (setq bfn2 (buffer-local-value 'buffer-file-name test-buf))
               (file-exists-p bfn2))
          ;; pass test script's filename and lineno
          (with-current-buffer test-buf
            (setq t-opt (format "%s@%s" buffer-file-name (rct-current-line)))
            (format "-t %s --filename=%s" t-opt bfn))
        ""))))

(require 'cl)

(defun rct-find-test-script-buffer (&optional buffer-list)
  "Find the latest used Ruby test script buffer."
  (setq buffer-list (or buffer-list (buffer-list)))
  (dolist (buf buffer-list)
    (with-current-buffer buf
      (if (and buffer-file-name (string-match "test.*\.rb$" buffer-file-name))
          (return buf)))))

;; (defun rct-find-test-method (buffer)
;;   "Find test method on point on BUFFER."
;;   (with-current-buffer buffer
;;     (save-excursion
;;       (forward-line 1)
;;       (if (re-search-backward "^ *def *\\(test_[A-Za-z0-9?!_]+\\)" nil t)
;;           (match-string 1)))))

(defun rct-try-completion ()
  "Evaluate the output of rct-complete."
  (rct-exec-and-eval rct-complete-command-name "--completion-emacs"))

;;;; TAGS or Ri
(autoload 'ri "ri-ruby" nil t)
(defvar rct-find-tag-if-available t
  "If non-nil and the method location is in TAGS, go to the location instead of show documentation.")
(defun rct-ri (&optional option)
  "Browse Ri document at the point.
If `rct-find-tag-if-available' is non-nil, search the definition using TAGS.

See also `rct-interactive'. "
  (interactive (rct-interactive))
  (rct-exec-and-eval
   rct-doc-command-name
   (concat "--ri-emacs --use-method-analyzer "
           (if (buffer-file-name)
               (concat "--filename=" (buffer-file-name))
             ""))))

(defun rct-find-tag-or-ri (fullname)
  (if (not rct-find-tag-if-available)
      (ri fullname)
    (condition-case err
        (let ()
          (visit-tags-table-buffer)
          (find-tag-in-order (concat "::" fullname) 'search-forward '(tag-exact-match-p) nil  "containing" t))
      (error
       (ri fullname)))))

;;;;
(defun ruby-toggle-buffer ()
  "Open a related file to the current buffer. test<=>impl."
  (interactive)
  (find-file (shell-command-to-string
              (format "%s %s" ruby-toggle-file-command-name buffer-file-name))))

;;;; rct-fork support
(defun rct-fork (options)
  "Run rct-fork.
Rct-fork makes xmpfilter and completion MUCH FASTER because it pre-loads heavy libraries.
When rct-fork is running, the mode-line indicates it to avoid unnecessary run.
To kill rct-fork process, use \\[rct-fork-kill].
"
  (interactive (list
                (read-string "rct-fork options (-e CODE -I LIBDIR -r LIB): "
                             (rct-fork-default-options))))
  (rct-fork-kill)
  (rct-fork-minor-mode 1)
  (start-process-shell-command
   "rct-fork" "*rct-fork*" rct-fork-command-name options))

(defun rct-fork-default-options ()
  "Default options for rct-fork by collecting requires."
  (mapconcat
   (lambda (lib) (format "-r %s" lib))
   (save-excursion
     (goto-char (point-min))
     (loop while (re-search-forward "\\<require\\> ['\"]\\([^'\"]+\\)['\"]" nil t)
           collect (match-string-no-properties 1)))
   " "))

(defun rct-fork-kill ()
  "Kill rct-fork process invoked by \\[rct-fork]."
  (interactive)
  (when rct-fork-minor-mode
    (rct-fork-minor-mode -1)
    (interrupt-process "rct-fork")))
(define-minor-mode rct-fork-minor-mode
  "This minor mode is turned on when rct-fork is run.
It is nothing but an indicator."
  :lighter " <rct-fork>" :global t)

;;;; unit tests
(when (and (fboundp 'expectations))
  (require 'ruby-mode)
  (require 'el-mock nil t)
  (expectations
    (desc "comment-dwim advice")
    (expect "# =>"
      (with-temp-buffer
        (ruby-mode)
        (setq last-command nil)
        (call-interactively 'comment-dwim)
        (setq last-command 'comment-dwim)
        (call-interactively 'comment-dwim)
        (buffer-string)))
    (expect (regexp "^1 +# =>")
      (with-temp-buffer
        (ruby-mode)
        (insert "1")
        (setq last-command nil)
        (call-interactively 'comment-dwim)
        (setq last-command 'comment-dwim)
        (call-interactively 'comment-dwim)
        (buffer-string)))

    (desc "rct-current-line")
    (expect 1
      (with-temp-buffer
        (rct-current-line)))
    (expect 1
      (with-temp-buffer
        (insert "1")
        (rct-current-line)))
    (expect 2
      (with-temp-buffer
        (insert "1\n")
        (rct-current-line)))
    (expect 2
      (with-temp-buffer
        (insert "1\n2")
        (rct-current-line)))

    (desc "rct-save-position")
    (expect (mock (set-window-start * 7) => nil)
      (stub window-start => 7)
      (with-temp-buffer
        (insert "abcdef\nghi")
        (rct-save-position #'ignore)))
    (expect 2
      (with-temp-buffer
        (stub window-start => 1)
        (stub set-window-start => nil)
        (insert "abcdef\nghi")
        (rct-save-position #'ignore)
        (rct-current-line)))
    (expect 3
      (with-temp-buffer
        (stub window-start => 1)
        (stub set-window-start => nil)
        (insert "abcdef\nghi")
        (rct-save-position #'ignore)
        (current-column)))

    (desc "rct-interactive")
    (expect '("read")
      (let ((current-prefix-arg t))
        (stub read-from-minibuffer => "read")
        (rct-interactive)))
    (expect '("-S ruby19")
      (let ((current-prefix-arg nil)
            (rct-option-local "-S ruby19"))
        (stub read-from-minibuffer => "read")
        (rct-interactive)))
    (expect '("")
      (let ((current-prefix-arg nil)
            (rct-option-local))
        (stub read-from-minibuffer => "read")
        (rct-interactive)))

    (desc "rct-shell-command")
    (expect "1+1 # => 2\n"
      (with-temp-buffer
        (insert "1+1 # =>\n")
        (rct-shell-command "xmpfilter")
        (buffer-string)))

    (desc "xmp")

    (desc "xmpfilter-command")
    (expect "xmpfilter --rails"
      (let ((xmpfilter-command-name "xmpfilter"))
        (with-temp-buffer
          (insert "class TestFoo < Test::Unit::TestCase\n")
          (xmpfilter-command "--rails"))))
    (expect "xmpfilter "
      (let ((xmpfilter-command-name "xmpfilter"))
        (with-temp-buffer
          (insert "context 'foo' do\n")
          (xmpfilter-command))))
    (expect "xmpfilter "
      (let ((xmpfilter-command-name "xmpfilter"))
        (with-temp-buffer
          (insert "describe Array do\n")
          (xmpfilter-command))))
    (expect "xmpfilter --unittest --rails"
      (let ((xmpfilter-command-name "xmpfilter"))
        (with-temp-buffer
          (insert "class TestFoo < Test::Unit::TestCase\n"
                  "  def test_0\n"
                  "    1 + 1 # =>\n"
                  "  end\n"
                  "end\n")
          (xmpfilter-command "--rails"))))
    (expect "xmpfilter --spec "
      (let ((xmpfilter-command-name "xmpfilter"))
        (with-temp-buffer
          (insert "context 'foo' do\n"
                  "  specify \"foo\" do\n"
                  "    1 + 1 # =>\n"
                  "  end\n"
                  "end\n")
          (xmpfilter-command))))
    (expect "xmpfilter --spec "
      (let ((xmpfilter-command-name "xmpfilter"))
        (with-temp-buffer
          (insert "describe Array do\n"
                  "  it \"foo\" do\n"
                  "    [1] + [1] # =>\n"
                  "  end\n"
                  "end\n")
          (xmpfilter-command))))
    (expect "xmpfilter "
      (let ((xmpfilter-command-name "xmpfilter"))
        (with-temp-buffer
          (insert "1 + 2\n")
          (xmpfilter-command))))

    (desc "rct-fork")
    (expect t
      (stub start-process-shell-command => t)
      (stub interrupt-process => t)
      (rct-fork "-r activesupport")
      rct-fork-minor-mode)
    (expect nil
      (stub start-process-shell-command => t)
      (stub interrupt-process => t)
      (rct-fork "-r activesupport")
      (rct-fork-kill)
      rct-fork-minor-mode)
    ))

(provide 'rcodetools)
