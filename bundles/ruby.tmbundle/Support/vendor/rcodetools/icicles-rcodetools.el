;;; icicles-rcodetools.el -- accurate completion with icicles

;;; Copyright (c) 2006-2007 rubikitch <rubikitch@ruby-lang.org>
;;;
;;; Use and distribution subject to the terms of the Ruby license.

(require 'icicles)
(require 'rcodetools)

(setq rct-complete-symbol-function 'rct-complete-symbol--icicles)
(icicle-define-command rct-complete-symbol--icicles
                         "Perform ruby method and class completion on the text around point with icicles.
C-M-RET shows RI documentation on each candidate.
See also `rct-interactive'."

                       (lambda (result)
                         (save-excursion
                           (search-backward pattern)
                           (setq beg (point)))
                         (delete-region beg end)
                         (insert result)) ;/function
                       "rct-complete: "       ;prompt
                       rct-method-completion-table
                       nil nil pattern nil nil nil
                       ((end (point)) beg
                        (icicle-list-join-string "\t")
                        (icicle-list-use-nth-parts '(1))
                        (icicle-point-position-in-candidate 'input-end)
                        pattern klass alist
                        (icicle-candidate-help-fn
                         (lambda (result)
                           (ri (cdr (assoc result alist)))))) ;bindings
                       (rct-exec-and-eval rct-complete-command-name "--completion-emacs-icicles"))

(provide 'icicles-rcodetools)
