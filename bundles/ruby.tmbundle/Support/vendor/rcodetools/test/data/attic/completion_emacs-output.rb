(progn
(setq rct-method-completion-table '(("uniq") ("uniq!") ))
(setq alist '(("uniq\t[Array#uniq]") ("uniq!\t[Array#uniq!]") ))
(setq pattern "uni")
(try-completion pattern rct-method-completion-table nil)
)
