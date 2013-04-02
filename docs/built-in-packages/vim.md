## Vim-mode

Fuses the power of [Vim](http://www.vim.org/) with the Atom.

### Configuration

To enable Vim-mode set `vim.enabled` to true.

config.cson:
```coffee-script
"vim":
  "enabled": true
```

To set a "leader" key add the following to your custom keymap:

```coffee-script
'.editor.command-mode':
  ',': 'vim:leader'
```

Now you can use the leader key for custom keybindings like this:

```coffee-script
'.editor.command-mode':
  'leader s': 'pane:split-down'
```

### Supported commands

#### Modes

**Insert mode**

Key: `i`

Event: `vim:insert-mode`

Variants:

* Append

  Key: `a`

  Event: `vim:insert-mode-append`

* Insert a newline below and enter insert mode

  Key: `o`

  Event: `vim:insert-mode-next-line`

* Insert a newline above and enter insert mode_

  Key: `O`

  Event: `vim:insert-mode-previous-line`

**Command mode**

Key: `esc`

Event: `vim:command-mode`

**Ex mode**

Key: `:`

Event: `vim:ex-mode`

**Visual mode**

Key: `v`

Event: `vim:visual-mode`

Variants:

* Visual line

  Key: `V`

  Event: `vim:visual-mode-lines`

#### Motions

**Move cursor to left/down/up/right**

Keys: `h` `j` `k` `l`

Event: `vim:motion-{left/down/up/right}`

**Move to beginning/end of line**

Keys: `0` `$`

Event: `vim:motion-{beginning/end}-of-line`

**Move to next/previous word**

Keys: `w` `b`

Event: `vim:motion-{next/previous}-word`

**Find character n forward/backward**

Key: `f n` `t n`

Event: `vim:motion-find-character` `vim:motion-find-character-reverse`

**Go to line**

Key: `g`

Event: `vim:motion-go-to-line`

Variants:

  * Go to last line

    Key: `G`

    Event: `vim:motion-go-to-line-bottom`

**Go to screen line**

Key: `H`

Event: `vim:motion-go-to-screen-line`

Variants:

  * Go to screen line from bottom

    Key: `L`

    Event: `vim:motion-go-to-screen-line-bottom`

**Scroll down/up half a screen**

Key: `ctrl-d` `ctrl-u`

Event: `vim:motion-{down/up}-screen`

**Place cursor in the middle of the screen**

Key: `M`

Event: `vim:motion-center-screen`

**Select next/previous pane**

Key: `ctrl-w l` `ctrl-w h`

Event: `window:focus-{next/previous}-pane`

#### Operators

**Delete**

Key: `d`

Event: `vim:operation-delete`

Variants:

  * Delete character

    Key: `x`

    Event: `vim:alias-delete-character`

  * Delete until end of line

    Key: `D`

    Event: `vim:alias-delete-until-end-of-line`

**Change**

Key: `c`

Event: `vim:operation-change`

Variants:

  * Substitute character

    Key: `s`

    Event: `vim:alias-substitute-character`

  * Substitute line

    Key: `S`

    Event: `vim:alias-substitute-line`

**Change character**

Key: `r`

Event: `vim:operation-change-character`

**Repeat last operation**

Key: `.`

Event: `vim:operation-repeat`

**Undo/redo**

Keys: `u` `ctrl-r`

Event: `core:{undo/redo}`

**Yank/paste**

Keys: `y` `p`

Event: `vim:operation-{yank/paste}`

**Join lines**

Keys: `J`

Event: `vim:alias-join-lines`

**Record/replay a series of actions in register n**

Keys: `q n` `@ n`

Events: `vim:command-start-recording` `vim:command-replay-recording`

Notes: There is also the `vim:command-stop-recording` event that should
be bound in the `.editor.recording` context instead of
`.editor.command-mode`

#### Ex mode

**Save**

Command: `:w`

**Close window**

Command: `:q`