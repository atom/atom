;;; anything-rcodetools.el --- accurate Ruby method completion with anything
;; $Id: anything-rcodetools.el,v 1.13 2009/04/20 16:25:37 rubikitch Exp $

;;; Copyright (c) 2007 rubikitch

;; Author: rubikitch <rubikitch@ruby-lang.org>
;; URL: http://www.emacswiki.org/cgi-bin/wiki/download/anything-rcodetools.el

;;; Use and distribution subject to the terms of the Ruby license.

;;; Commentary:

;; (0) You need rcodetools, anything.el and FastRI. Note that you do not have to
;;     configure anything.el if you use anything.el for this package.
;; (1) You need to add to .emacs:
;;       (require 'anything)
;;       (require 'anything-rcodetools)
;;       ;; Command to get all RI entries.
;;       (setq rct-get-all-methods-command "PAGER=cat fri -l")
;;       ;; See docs
;;       (define-key anything-map "\C-z" 'anything-execute-persistent-action)

;;; Commands:
;;
;; Below are complete command list:
;;
;;
;;; Customizable Options:
;;
;; Below are customizable option list:
;;

;;; History:

;; $Log: anything-rcodetools.el,v $
;; Revision 1.13  2009/04/20 16:25:37  rubikitch
;; Set anything-samewindow to nil
;;
;; Revision 1.12  2009/04/18 10:12:02  rubikitch
;; Adjust to change of `use-anything-show-completion'
;;
;; Revision 1.11  2009/04/17 20:21:47  rubikitch
;; * require anything
;; * require anything-show-completion.el if available
;;
;; Revision 1.10  2009/04/17 20:11:03  rubikitch
;; removed old code
;;
;; Revision 1.9  2009/04/17 20:07:52  rubikitch
;; * use --completion-emacs-anything option
;; * New implementation of `anything-c-source-complete-ruby-all'
;;
;; Revision 1.8  2009/04/15 10:25:25  rubikitch
;; Set `anything-execute-action-at-once-if-one' t
;;
;; Revision 1.7  2009/04/15 10:24:23  rubikitch
;; regexp bug fix
;;
;; Revision 1.6  2008/01/14 17:59:34  rubikitch
;; * uniform format (anything-c-source-complete-ruby, anything-c-source-complete-ruby-all)
;; * rename command: anything-c-ri -> anything-rct-ri
;;
;; Revision 1.5  2008/01/13 17:54:04  rubikitch
;; anything-current-buffer advice.
;;
;; Revision 1.4  2008/01/08 14:47:34  rubikitch
;; Added (require 'rcodetools).
;; Revised commentary.
;;
;; Revision 1.3  2008/01/04 09:32:29  rubikitch
;; *** empty log message ***
;;
;; Revision 1.2  2008/01/04 09:21:23  rubikitch
;; fixed typo
;;
;; Revision 1.1  2008/01/04 09:21:05  rubikitch
;; Initial revision
;;

;;; Code:

(require 'anything)
(require 'rcodetools)
(when (require 'anything-show-completion nil t)
  (use-anything-show-completion 'rct-complete-symbol--anything
                                '(length pattern)))

(defun anything-rct-ri (meth)
  (ri (get-text-property 0 'desc meth)))

(defun anything-rct-complete  (meth)
  (save-excursion
    (set-buffer anything-current-buffer)
    (search-backward pattern)
    (delete-char (length pattern)))
  (insert meth))

(setq rct-complete-symbol-function 'rct-complete-symbol--anything)
(defvar anything-c-source-complete-ruby
  '((name . "Ruby Method Completion")
    (candidates . rct-method-completion-table)
    (init
     . (lambda ()
         (condition-case x
             (rct-exec-and-eval rct-complete-command-name "--completion-emacs-anything")
           ((error) (setq rct-method-completion-table nil)))))
    (action
     ("Completion" . anything-rct-complete)
     ("RI" . anything-rct-ri))
    (volatile)
    (persistent-action . anything-rct-ri)))

(defvar rct-get-all-methods-command "PAGER=cat fri -l")
(defvar anything-c-source-complete-ruby-all
  '((name . "Ruby Method Completion (ALL)")
    (init
     . (lambda ()
         (unless (anything-candidate-buffer)
           (with-current-buffer (anything-candidate-buffer 'global)
             (call-process-shell-command rct-get-all-methods-command nil t)
             (goto-char 1)
             (while (re-search-forward "^.+[:#.]\\([^:#.]+\\)$" nil t)
               (replace-match "\\1\t[\\&]"))))))
    (candidates-in-buffer
     . (lambda ()
         (let ((anything-pattern (format "^%s.*%s" (regexp-quote pattern) anything-pattern)))
           (anything-candidates-in-buffer))))
    (display-to-real
     . (lambda (line)
         (if (string-match "\t\\[\\(.+\\)\\]$" line)
             (propertize (substring line 0 (match-beginning 0))
                         'desc (match-string 1 line))
           line)))
    (action
     ("Completion" . anything-rct-complete)
     ("RI" . anything-rct-ri))
    (persistent-action . anything-rct-ri)))


(defun rct-complete-symbol--anything ()
  (interactive)
  (let ((anything-execute-action-at-once-if-one t)
        anything-samewindow)
    (anything '(anything-c-source-complete-ruby
                anything-c-source-complete-ruby-all))))

(provide 'anything-rcodetools)

;; How to save (DO NOT REMOVE!!)
;; (emacswiki-post "anything-rcodetools.el")
;;; install-elisp.el ends here
