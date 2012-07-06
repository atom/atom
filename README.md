# Atom — Futuristic Text Editing
## Be forwarned: Atom is pre-alpha software!


## Building from source

1. Get [xcode 4.2 or above](http://itunes.apple.com/us/app/xcode/id448457090?mt=12)

2. Install CoffeeScript http://coffeescript.org/
```
brew install nodejs
curl http://npmjs.org/install.sh | sh
npm i -g coffee-script
```

3. `git clone git@github.com:github/atom.git`

4. `cd atom`

5. `rake run`


## Setup Your ~/.atom Directory
An example .atom directory can be found at the root of the source tree

## Basic Keyboard shortcuts
Atom doesn't have much in the way of menus yet. Use these keyboard shortcuts to
explore features.

`cmd-o` : open file/directory

`cmd-n` : new window

`cmd-t` : open fuzzy file finder

`cmd-:` : open command prompt

`cmd-f` : open command prompt with /

`cmd-g` : repeat the last search

`cmd-r` : reload the current window

`cmd-alt-ctrl-s` : run specs

`cmd-alt-arrows` : split screen in direction of arrow

`cmd-alt-w` : toggle word wrap

`cmd-alt-f` : fold selected lines

Most default OS X keybindings also work.

## Init Script

Atom will require `~/.atom/atom.coffee` whenever a window is opened or reloaded if it is present in your
home directory. This is a rudimentary jumping off point for your own customizations.

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

## Key Bindings

Atom has a CSS based key binding scheme. We will add a nicer loading mechanism, but for now you can bind
keys by calling `window.keymap.bindKeys` with a CSS selector and a hash of key-pattern -> event mappings.

```coffeescript
window.keymap.bindKeys '.editor'
  'ctrl-p': 'party-time'
  'ctrl-q': 'open-dialog-q'
```

When a keypress matches a pattern on an element that matches the selector, it will be translated to the
named event, which will bubble up the DOM from the site of the keypress. Extension code can listen for
the named event and react to it.


