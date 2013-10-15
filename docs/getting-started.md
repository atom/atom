# Getting Started

Welcome to Atom! This guide provides a quick introduction so you can be
productive as quickly as possible. There are also guides which cover
[configuring], [theming], and [extending] Atom.

## The Command Palette

If there's one key-command you must remember in Atom, it should be `cmd-p`. You
can always hit `cmd-p` to bring up a list of commands that are relevant to the
currently focused interface element. If there is a key binding for a given
command, it is also displayed. This is a great way to explore the system and get
to know the key commands interactively. If you'd like to learn about adding or
changing a binding for a command, refer to the [key bindings][key-bindings]
section below.

![Command Palette]

## The Basics

### Working With Files

Atom windows are scoped to the directory in which they're opened from. So if you
launch Atom from the command line, everything will be relative to the current
directory. This means that the tree view on the left will only show files
contained within that directory.

This can be a useful way to organize multiple projects, as each project will be
contained within it's own window and it's state will be unique to that window.

#### Finding Files

The fastest way to find a file in your project is to use the fuzzy finder. Just
hit `cmd-t` and start typing the name of the file you're looking for. If you
already have the file open as a tab and want to jump to it, hit `cmd-b` to bring
up a searchable list of open buffers.

You can also use the tree view to navigate to a file. To open or move focus to
the tree view, hit `cmd-\`. You can then navigate to a file and select it with
`return`.

#### Adding, Moving, Deleting Files

Currently, all file modification is performed via the tree view. To add a file,
select a directory in the tree view and press `a`. Then type the name of the
file. Any intermediate directories you type will be created automatically if
needed.

To move or rename a file or directory, select it in the tree view and hit `m`.
To delete a file, select it in the tree view and hit `delete`.

### Searching

#### Find and Replace

To search within a buffer use `cmd-f`. To search the entire project use
`cmd-shift-f`. To find and replace within the current buffer use `cmd-alt-f`.

#### Navigating By Symbols

If you want to jump to a method, the `cmd-j` binding opens a list of all symbols
in the current file. `cmd-.` jumps to the tag for the word currently under the
cursor.

To search for symbols across your project use `cmd-shift-j`, but you'll need to
make sure you have a tags file generated for the project Also, if you're editing
CoffeeScript, it's a good idea to update your `~/.ctags` file to understand the
language. Here is [a good example][ctags].

### Split Panes

You can split any editor pane horizontally or vertically by using `ctrl-w s` or
`ctrl-w v`. Once you have a split pane, you can move focus between them with
`ctrl-tab` or `ctrl-w w`. To close a pane, close all tabs inside it.

### Folding

You can fold everything with `ctrl-{` and unfold everything with
`ctrl-}`. Or, you can fold / unfold by a single level with `ctrl-[` and
`ctrl-]`.

### Soft-Wrap

If you want to toggle soft wrap, trigger the command from the command palette.
Hit `cmd-p` to open the palette, then type "wrap" to find the correct
command.

## Configuration

If you press `cmd-,`, a configuration panel will appear in the currently focused
pane. This serves as the primary interface for adjusting settings, installing
packages and changing themes.

For more advanced configuration see the [customization guide][customization].

[configuring]: customizing-atom.md
[theming]: creating-a-theme.md
[extending]: creating-a-package.md
[customization]: customizing-atom.md
[key-bindings]: #customizing-key-bindings
[command palette]: https://f.cloud.github.com/assets/1424/1091618/ee7c3554-166a-11e3-9955-aaa61bb5509c.png
[ctags]: https://github.com/kevinsawicki/dotfiles/blob/master/.ctags
