{{{
"title": "Getting Started"
}}}

# Getting Started

Welcome to Atom! This guide provides a quick introduction so you can be
productive as quickly as possible. There are also guides which cover
[configuring][configuring], [theming][theming], and [extending][extending] Atom.

## The Command Palette

If there's one key-command you must remember in Atom, it should be `⌘-p`. You
can always hit `⌘-p` to bring up a list of commands that are relevant to the
currently focused UI element. If there is a key binding for a given command, it
is also displayed. This is a great way to explore the system and get to know the
key commands interactively. If you'd like to learn about adding or changing a
binding for a command, refer to the [key bindings](#customizing-key-bindings)
section below.

![Command Palette](http://f.cl.ly/items/32041o3w471F3C0F0V2O/Screen%20Shot%202013-02-13%20at%207.27.41%20PM.png)

## The Basics

### Working With Files

#### Finding Files

The fastest way to find a file in your project is to use the fuzzy finder. Just
hit `⌘-t` and start typing the name of the file you're looking for. If you
already have the file open as a tab and want to jump to it, hit `⌘-b` to bring
up a searchable list of open buffers.

You can also use the tree view to navigate to a file. To open or move focus to
the tree view, hit `⌘-\`. You can then navigate to a file and select it with
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

FIXME: Describe https://github.com/atom/find-and-replace

#### Navigating By Symbols

If you want to jump to a method, the `⌘-j` binding opens a list of all symbols
in the current file. `⌘-.` jumps to the tag for the word currently under the cursor.

To search for symbols across your project use `cmd-shift-j`, but you'll need to
make sure you have a tags file generated for the project Also, if you're editing
CoffeeScript, it's a good idea to update your `~/.ctags` file to understand the
language. Here is [a good example](https://github.com/kevinsawicki/dotfiles/blob/master/.ctags).

### Split Panes

You can split any editor pane horizontally or vertically by using `ctrl-\` or
`ctrl-w v`. Once you have a split pane, you can move focus between them with
`ctrl-tab` or `ctrl-w w`. To close a pane, close all tabs inside it.

### Folding

You can fold everything with `ctrl-{` and unfold everything with
`ctrl-}`. Or, you can fold / unfold by a single level with `ctrl-[` and
`ctrl-]`. The user interaction around folds is still a bit rough, but we're
planning to improve it soon.

### Soft-Wrap

If you want to toggle soft wrap, trigger the command from the command palette.
Hit `⌘-p` to open the palette, then type "wrap" to find the correct
command.

## Configuration

If you press `⌘-,`, a configuration panel will appear in the currently focused
pane. This will serve as the primary interface for adjusting configuration
settings, adding and changing key bindings, tweaking styles, etc.

For more advanced configuration see the [customization guide][customization].

## Installing Packages

To install a package, open the configuration panel and select the packages tab.

FIXME: Needs more details.

[configuring]: customizing-atom.html
[theming]: creating-a-theme.html
[extending]: creating-a-package.html
[customization]: customizing-atom.html
