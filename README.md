# Atom — Futuristic Text Editing
![atom](http://www.gvsd.org/1891205613507883/lib/1891205613507883/atom_animated.gif)

## Be forwarned: Atom is pre-alpha software!

## Download

1. Download [atom.zip](https://github.com/downloads/github/atom/atom.zip)

2. Unzip and open the app

## Basic Keyboard shortcuts

`cmd-o` : open file/directory
`cmd-n` : new window
`cmd-alt-ctrl-s` : run specs
`cmd-t` : open fuzzy finder
`cmd-:` : open command prompt
`cmd-f` : open command prompt with /
`cmd-g` : repeat the last search
`cmd-alt-w` : toggle word wrap
`cmd-alt-f` : fold selected lines

Most default OS X keybindings also work.

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

## Build from source

1. Get [xcode 4.2](http://itunes.apple.com/us/app/xcode/id448457090?mt=12)

2. Install CoffeeScript http://coffeescript.org/ (try `npm i -g coffee-script`)

3. `git clone git@github.com:github/atom.git`

4. `cd atom`

5. `rake run`