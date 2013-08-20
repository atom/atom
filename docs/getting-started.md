{{{
"title": "Getting Started"
}}}

# Getting Started

Welcome to Atom. This documentation provides a basic introduction to being
productive with this editor. We'll then delve into more details about configuring,
theming, and extending Atom.

## The Command Palette

If there's one key-command you must remember in Atom, it should be `meta-p` (`meta` is
synonymous with the ⌘ key). You can always hit `meta-p` to bring up a list of
commands that are relevant to the currently focused UI element. If there is a
key binding for a given command, it is also displayed. This is a great way to
explore the system and get to know the key commands interactively. If you'd like
to learn about adding or changing a binding for a command, refer to the [key
bindings](#customizing-key-bindings) section.

![Command Palette](http://f.cl.ly/items/32041o3w471F3C0F0V2O/Screen%20Shot%202013-02-13%20at%207.27.41%20PM.png)

## Basic Key Bindings

You can always use `meta-p` to explore available commands and their
bindings, but here's a list of a few useful commands.

- `meta-o` : open a file or directory
- `meta-shift-n` : open new window
- `meta-r` : reload the current window
- `meta-alt-ctrl-s` : run test specs
- `meta-t` : open file finder to navigate files in your project
- `meta-;` : open command prompt
- `meta-f` : open command prompt with `/` for a local file search
- `meta-g` : repeat the last local search
- `meta-shift-f` : open command prompt with `Xx/` for a project-wide search
- `meta-\` : focus/open tree view, or close it when it is focused
- `meta-|` : open tree view with the current file selected
- `ctrl-w v`, `ctrl-|` : split screen vertically
- `ctrl-w s`, `ctrl--` : split screen horizontally
- `meta-l` : go to line

## Usage Basics

### If You See A Rendering Bug

Things are pretty stable, but we think we have a couple rendering bugs lurking
that are hard to reproduce. If you see one, please hit `meta-p` and type
"save debug snapshot". Run that command to save a snapshot of the misbehaving
editor and send it to us, along with a screenshot and your best description of
how you produced the bug. Refreshing with `meta-r` should usually resolve the
issue so you can keep working.

### Working With Files

#### Finding Files

The fastest way to find a file in your project is to use the fuzzy finder. Just
hit `meta-t` and start typing the name of the file you're looking for. If you
already have the file open as a tab and want to jump to it, hit `meta-b` to bring
up a searchable list of open buffers.

You can also use the tree view to navigate to a file. To open or move focus to
the tree view, hit `meta-\`. You can then navigate to a file and select it with
`return`.

#### Adding, Moving, Deleting Files

Currently, all file modification is performed via the tree view. To add a file,
select a directory in the tree view and press `a`. Then type the name of the
file. Any intermediate directories you type will be created automatically if
needed.

To move or rename a file or directory, select it in the tree view and hit `m`.
To delete a file, select it in the tree view and hit `delete`.

### Searching For Stuff

#### Using the Command Line

Atom has a command line similar to old-school editors such as emacs and vim. Nearly
every command has a key binding which you can discover with `meta-p`.

The command line is also (currently) the only place you can perform a search. Hitting
`meta-f` opens the command line and prepopulates it with the `/` command. This finds
text in the current buffer, starting at the location of the cursor. Pressing `meta-g`
repeats the search. Hitting `meta-shift-f` opens the command line and prepopulates
it with `Xx/`, which is a composite command that performs a global search. The results
of the search appear in the operation preview list, which you can focus
with `meta-:`.

Atom's command language is still under construction, and is loosely based on
the [Sam editor](http://doc.cat-v.org/bell_labs/sam_lang_tutorial/) from the
Plan 9 operating system. It's similar to Ex mode in vim, but is selection-based
rather than line-based. It allows you to compose commands together in
interesting ways.

#### Navigating By Symbols

If you want to jump to a method, you can use the ctags-based symbols package.
The `meta-j` binding opens a list of all symbols in the current file. The
`meta-shift-j` binding opens a list of all symbols for the current project
based on a tags file. `meta-.` jumps to the tag for the word currently
under the cursor.

Make sure you have a tags file generated for the project for
the latter of these two bindings to work. Also, if you're editing CoffeeScript,
it's a good idea to update your `~/.ctags` file to understand the language. Here
is [a good example](https://github.com/kevinsawicki/dotfiles/blob/master/.ctags).

### Replacing Stuff

To perform a replacement, open up the command line with `meta-;` and use the `s`
command, as follows: `s/foo/bar/g`. Note that if you have a selection, the
replacement will only occur inside the selected text. An empty selection will
cause the replacement to occur across the whole buffer. If you want to run the
command on the whole buffer even if you have a selection, precede your
substitution with the `,` address; this indicates that the following command should
run on the whole buffer.

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
Hit `meta-p` to open the palette, then type "wrap" to find the correct
command.

## Your .atom Directory

When you install Atom, an `.atom` directory is created in your home directory.
If you press `meta-,`, that directory will be opened in a new window. For the
time being, this will serve as the primary interface for adjusting configuration
settings, adding and changing key bindings, tweaking styles, etc.

## Configuration Settings

Atom loads configuration settings from the `config.cson` file in your `~/.atom`
directory, which contains CoffeeScript-style JSON:

```coffeescript
'editor':
  'fontSize': 16
'core':
  'themes': [
    'atom-dark-ui'
    'atom-dark-syntax'
  ]
```

Configuration is broken into namespaces, which are defined by the config hash's
top-level keys. In addition to Atom's core components, each package may define
its own namespace.

### Glossary of Config Keys

- core
  - disabledPackages: An array of package names to disable
  - hideGitIgnoredFiles: Whether files in the .gitignore should be hidden
  - ignoredNames: File names to ignore across all of atom (not fully implemented)
  - themes: An array of theme names to load, in cascading order
  - autosave: Save a resource when its view loses focus
- editor
  - autoIndent: Enable/disable basic auto-indent (defaults to true)
  - autoIndentOnPaste: Enable/disable auto-indented pasted text (defaults to false)
  - nonWordCharacters: A string of non-word characters to define word boundaries
  - fontSize
  - fontFamily
  - invisibles: Specify characters that Atom renders for invisibles in this hash
      - tab: Hard tab characters
      - cr: Carriage return (For Microsoft-style line endings)
      - eol: `\n` characters
      - space: Leading and trailing space characters
  - preferredLineLength: Packages such as autoflow use this (defaults to 80)
  - showInvisibles: Whether to render placeholders for invisible characters (defaults to false)
- fuzzyFinder
  - ignoredNames: Files to ignore *only* in the fuzzy-finder
- whitespace
  - ensureSingleTrailingNewline: Whether to reduce multiple newlines to one at the end of files
- wrapGuide
  - columns: Array of hashes with a `pattern` and `column` key to match the
             the path of the current editor to a column position.

## Customizing Key Bindings

Atom keymaps work similarly to stylesheets. Just as stylesheets use selectors
to apply styles to elements, Atom keymaps use selectors to associate keystrokes
with events in specific contexts. Here's a small example, excerpted from Atom's
built-in keymaps:

```coffeescript
'.editor':
  'enter': 'editor:newline'

'.select-list .editor.mini':
  'enter': 'core:confirm'
```

This keymap defines the meaning of `enter` in two different contexts. In a
normal editor, pressing `enter` emits the `editor:newline` event, which causes
the editor to insert a newline. But if the same keystroke occurs inside of a
select list's mini-editor, it instead emits the `core:confirm` event based on
the binding in the more-specific selector.

By default, any keymap files in your `~/.atom/keymaps` directory will be loaded
in alphabetical order when Atom is started. They will always be loaded last,
giving you the chance to override bindings that are defined by Atom's core
keymaps or third-party packages.

## Changing The Theme

Atom comes bundles with two themes `atom-dark-*` and `atom-light-*`.

Because Atom themes are based on CSS, it's possible to have multiple themes
active at the same time. For example, you'll usually select a theme for the UI
and another theme for syntax highlighting.  You can select themes by specifying
them in the `core.themes` array in your `config.cson`:

```coffeescript
core:
  themes: ["atom-light-ui", "atom-light-syntax"]
  # or, if the sun is going down:
  # themes: ["atom-dark-ui", "atom-dark-syntax"]
```

You install new themes by placing them in the `~/.atom/themes` directory. A
theme can be a CSS file, a directory containing multiple CSS files, or a
TextMate theme (either `.tmTheme` or `.plist`).


## Installing Packages (Partially Implemented)

To install a package, clone it into the `~/.atom/packages` directory. Atom will
also load grammars and snippets from TextMate bundles. If you want to disable a
package without removing it from the packages directory, insert its name into
`config.core.disabledPackages`:

config.cson:
```coffeescript
core:
  disabledPackages: [
    "fuzzy-finder",
    "tree-view"
  ]
```

## Quick Personal Hacks

### user.coffee

When Atom finishes loading, it will evaluate `user.coffee` in your `~/.atom`
directory, giving you a chance to run arbitrary personal CoffeeScript code to
make customizations. You have full access to Atom's API from code in this file.
Please refer to the Atom Internals Guide for more information. If your
customizations become extensive, consider creating a package.

### user.css

If you want to apply quick-and-dirty personal styling changes without creating
an entire theme that you intend to distribute, you can add styles to
`user.css` in your `~/.atom` directory.

For example to change the color of the highlighted line number for the line that
contains the cursor, you could add the following style to `user.css`:

```css
.editor .line-number.cursor-line {
  color: pink;
}
```
