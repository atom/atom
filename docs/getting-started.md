# Getting Started

Welcome to Atom! This guide provides a quick introduction so you can be
productive as quickly as possible. There are also guides which cover
[configuring], [theming], and [extending] Atom.

## The Command Palette

If there's one key-command you remember in Atom, it should be `cmd-shift-P`. You
can always press `cmd-shift-P` to bring up a list of commands (and key bindings)
that are relevant to the currently focused interface element. This is a great
way to explore the system and learn key bindings interactively. For information
about adding or changing a key binding refer to the [customizing key
bindings][key-bindings] section.

![Command Palette]

## The Basics

### Working With Files

Atom windows are scoped to the directory they're opened from. If you launch Atom
from the command line everything will be relative to the current directory. This
means that the tree view on the left will only show files contained within that
directory.

This can be a useful way to organize multiple projects, as each project will be
contained within its own window.

#### Finding Files

The fastest way to find a file is to use the fuzzy finder. Press `cmd-t` and
begin typing the name of the file you're looking for. If you are looking for a
file that is already open press `cmd-b` to bring up a searchable list of open
files.

You can also use the tree view to navigate to a file. To open or move focus to
the tree view, press `cmd-\`. You can then navigate to a file using the arrow
keys and select it with `return`.

#### Adding, Moving, Deleting Files

Currently, all file modification is performed via the tree view. To add a file,
select a directory in the tree view and press `a`. Then type the name of the
file. Any intermediate directories you type will be created automatically if
needed.

To move or rename a file or directory, select it in the tree view and press `m`.

To delete a file, select it in the tree view and press `delete`.

### Searching

#### Find and Replace

To search within a buffer use `cmd-f`. To search the entire project use
`cmd-shift-f`.

#### Navigating By Symbols

If you want to jump to a method press `cmd-r`. It opens a list of all symbols
in the current file.

To search for symbols across your project use `cmd-shift-r`, but you'll need to
make sure you have a ctags installed and a tags file generated for your project.
Also, if you're editing CoffeeScript, it's a good idea to update your `~/.ctags`
file to understand the language. Here is [a good example][ctags].

### Split Panes

You can split any editor pane horizontally or vertically by using `cmd-k right` or
`cmd-k down`. Once you have a split pane, you can move focus between them with
`cmd-k cmd-right` or `cmd-k cmd-down`. To close a pane, close all tabs inside it.

### Folding

You can fold everything with `alt-cmd-{` and unfold everything with
`alt-cmd-}`. Or, you can fold / unfold by a single level with `alt-cmd-[` and
`alt-cmd-]`.

### Soft-Wrap

If you want to toggle soft wrap, trigger the command from the command palette.
Press `cmd-shift-P` to open the palette, then type "wrap" to find the correct
command.

## Configuration

Press `cmd-,` to display the a settings pane. This serves as the primary
interface for adjusting config settings, installing packages and changing
themes.

For more advanced configuration see the [customization guide][customization].

[configuring]: customizing-atom.md
[theming]: creating-a-theme.md
[extending]: creating-a-package.md
[customization]: customizing-atom.md
[key-bindings]: customizing-atom.md#customizing-key-bindings
[command palette]: https://f.cloud.github.com/assets/1424/1091618/ee7c3554-166a-11e3-9955-aaa61bb5509c.png
[ctags]: https://github.com/kevinsawicki/dotfiles/blob/master/.ctags
