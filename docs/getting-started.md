# Getting Started

Welcome to Atom. This documentation is intented to offer a basic introduction
of how to get productive with this editor. Then we'll delve into more details
about configuring, theming, and extending Atom.

## The Command Palette

If there's one key-command you learn in Atom, it should be `meta-p`. You can
always hit `meta-p` to bring up a list of commands that are relevant to the
currently focused UI element. If there is a key binding for a given command, it
is also displayed. This is a great way to explore the system and get to know the
key commands interactively. If you'd like to add or change a binding for a
command, refer to the [keymaps](#keymaps) section to learn how.

![Command Palette](http://f.cl.ly/items/32041o3w471F3C0F0V2O/Screen%20Shot%202013-02-13%20at%207.27.41%20PM.png)

## Working With Files

### Finding Files

The fastest way to find a file in your project is to use the fuzzy finder. Just
hit `meta-t` and start typing the name of the file you're looking for. If you
already have the file open and want to jump to it, hit `meta-b` to bring up a
searchable list of open buffers.

You can also use the tree view to navigate to a file. To open or move focus to
the tree view, hit `meta-\`. You can then navigate to a file and select it with
`return`.

### Adding, Moving, Deleting Files

Currently, all file modification is performed via the tree view. To add a file,
select a directory in the tree view and press `a`. Then type the name of the
file. Any intermediate directories you type will be created automatically if
needed.

To move or rename a file or directory, select it in the tree view and hit `m`.
To delete a file, select it in the tree view and hit `delete`.

## Searching For Stuff

### Using the Command Line

Atom has a command line similar to editors Emacs and Vim, which is currently the
only interface for performing searches. Hitting `meta-f` will open the command
line prepopulated with the `/` command, which finds forward in the current
buffer from the location of the cursor. Pressing `meta-g` will repeat the
search. Hitting `meta-shift-f` will open the command line prepopulated with
`Xx/`, which is a composite command that performs a global search. The results
of the search will appear in the operation preview list, which you can focus
with `meta-:`.

Atom's command language is still under construction and is loosely based on
the [Sam editor](http://doc.cat-v.org/bell_labs/sam_lang_tutorial/) from the
Plan 9 operating system. It's similar to Ex mode in Vim, but is selection-based
rather than line-based. It allows you to compose commands together in
interesting ways.

### Navigating By Symbols

If you want to jump to a method, you can use the ctags-based symbols package.
The `meta-j` binding will open a list of all symbols in the current file. The
`meta-shift-j` binding will open a list of all symbols for the current project
based on a tags file. And `meta-.` will jump to the tag for the word currently
under the cursor. Make sure you have a tags file generated for the project for
the latter of these two bindings to work. Also, if you're editing CoffeeScript,
it's a good idea to update your `~/.ctags` file to understand the language. Here
is [a good example](https://github.com/kevinsawicki/dotfiles/blob/master/.ctags).

## Replacing Stuff

To perform a replacement, open up the command line with `meta-;` and use the `s`
command, as follows: `s/foo/bar/g`. Note that if you have a selection, the
replacement will only occur inside the selected text. An empty selection will
cause the replacement to occur across the whole buffer. If you want to run the
command on the whole buffer even if you have a selection, precede your
substitution with the `,` address, which specifies that the command following it
operate on the whole buffer.

## Split Panes

You can split any editor pane horizontally or vertically by using `alt-command`
plus the arrow in the direction you wand to split. Once you have a split pane,
you can move focus between them with `ctrl-w w`. To close a pane, close all tabs
inside it.
