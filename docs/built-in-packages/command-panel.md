# Command Panel

The command panel contains a  partial implementation of the [Sam command language](http://man.cat-v.org/plan_9/1/sam).
In addition, packages are free to design and define any scoped command.

Pop open the command line by hitting .
You can get a list of commands available to Atom (including any keybindings) by hitting `meta-p`.

## Examples

`,` selects the entire file

`1,4` selects lines 1-4 in the current file

`/pattern` selects the first match after the cursor/selection

`s/pattern/replacement` replaces the first text matching pattern in current selection

`s/pattern/replacement/g` replaces all text matching pattern in current selection

`,s/pattern/replacement/g` replaces all text matching pattern in file

`1,4s/pattern/replacement` replaces all text matching pattern in lines 1-4

`x/pattern` selects all matches in the current selections

`,x/pattern` selects all matches in the file

`,x/pattern1/ x/pattern2` "structural regex" - selects all matches of pattern2 inside matches of pattern1
