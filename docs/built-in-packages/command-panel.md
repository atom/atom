## Command Panel

A partial implementation of the [Sam command language](http://man.cat-v.org/plan_9/1/sam)

*Examples*

`,` selects entire file

`1,4` selects lines 1-4

`/pattern` selects the first match after the cursor/selection

`s/pattern/replacement` replace first text matching pattern in current selection

`s/pattern/replacement/g` replace all text matching pattern in current selection

`,s/pattern/replacement/g` replace all text matching pattern in file

`1,4s/pattern/replacement` replace all text matching pattern in lines 1-4

`x/pattern` selects all matches in the current selections

`,x/pattern` selects all matches in the file

`,x/pattern1/ x/pattern2` "structural regex" - selects all matches of pattern2 inside matches of pattern1
