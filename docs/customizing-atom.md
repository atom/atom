{{{
"title": "Customizing Atom"
}}}

# Configuration Settings

## Your .atom Directory

When you install Atom, an _.atom_ directory is created in your home directory.
If you press `cmd-,`, that directory is opened in a new window. For the
time being, this serves as the primary interface for adjusting configuration
settings, adding and changing key bindings, tweaking styles, etc.

Atom loads configuration settings from the `config.cson` file in your _~/.atom_
directory, which contains CoffeeScript-style JSON:

```coffeescript
core:
  hideGitIgnoredFiles: true
editor:
  fontSize: 18
```

Configuration is broken into namespaces, which are defined by the config hash's
top-level keys. In addition to Atom's core components, each package may define
its own namespace.

## Glossary of Config Keys

- `core`
  - `disablePackages`: An array of package names to disable
  - `hideGitIgnoredFiles`: Whether files in the _.gitignore_ should be hidden
  - `ignoredNames`: File names to ignore across all of Atom (not fully implemented)
  - `themes`: An array of theme names to load, in cascading order
  - `autosave`: Save a buffer when its view loses focus
- `editor`
  - `autoIndent`: Enable/disable basic auto-indent (defaults to `true`)
  - `autoIndentOnPaste`: Enable/disable auto-indented pasted text (defaults to `false`)
  - `nonWordCharacters`: A string of non-word characters to define word boundaries
  - `fontSize`: The editor font size
  - `fontFamily`: The editor font family
  - `invisibles`: Specify characters that Atom renders for invisibles in this hash
      - `tab`: Hard tab characters
      - `cr`: Carriage return (for Microsoft-style line endings)
      - `eol`: `\n` characters
      - `space`: Leading and trailing space characters
  - `preferredLineLength`: Identifies the length of a line (defaults to `80`)
  - `showInvisibles`: Whether to render placeholders for invisible characters (defaults to `false`)
- `fuzzyFinder`
  - `ignoredNames`: Files to ignore *only* in the fuzzy-finder
- `whitespace`
  - `ensureSingleTrailingNewline`: Whether to reduce multiple newlines to one at the end of files
- `wrapGuide`
  - `columns`: Array of hashes with a `pattern` and `column` key to match the
             the path of the current editor to a column position.

## Customizing Key Bindings

Atom keymaps work similarly to stylesheets. Just as stylesheets use selectors
to apply styles to elements, Atom keymaps use selectors to associate keystrokes
with events in specific contexts. Here's a small example, excerpted from Atom's
built-in keymaps:

```coffee-script
'.editor':
  'enter': 'editor:newline'

".select-list .editor.mini":
  'enter': 'core:confirm',
```

This keymap defines the meaning of `enter` in two different contexts. In a
normal editor, pressing `enter` emits the `editor:newline` event, which causes
the editor to insert a newline. But if the same keystroke occurs inside of a
select list's mini-editor, it instead emits the `core:confirm` event based on
the binding in the more-specific selector.

By default, any keymap files in your `~/.atom/keymaps` directory are loaded
in alphabetical order when Atom is started. They will always be loaded last,
giving you the chance to override bindings that are defined by Atom's core
keymaps or third-party packages.

## Changing The Theme

Atom comes bundled with two themes `atom-dark-*` and `atom-light-*`.

Because Atom themes are based on CSS, it's possible to have multiple themes
active at the same time.

VERIFY: Is this still true?

For example, you'll usually select a theme for the UI
and another theme for syntax highlighting.  You can select themes by specifying
them in the `core.themes` array in your `config.cson`:

```coffee-script
core:
  themes: ["atom-light-ui", "atom-light-syntax"]
  # or, if the sun is going down:
  # themes: ["atom-dark-ui", "atom-dark-syntax"]
```

You install new themes by placing them in the _~/.atom/themes_ directory. A
theme can be a CSS file or a directory containing multiple CSS files.

VERIFY: Where did we wind up with themes?

## Installing Packages

FIXME: Rewrite for the new dialog.

## Quick Personal Hacks

### user.coffee

When Atom finishes loading, it will evaluate _user.coffee_ in your _~/.atom_
directory, giving you a chance to run arbitrary personal CoffeeScript code to
make customizations. You have full access to Atom's API from code in this file.
Please refer to the [Atom Internals Guide](./internals/intro,md) for more information. If your
customizations become extensive, consider [creating a package](./packages/creating_packages.md).

### user.less

If you want to apply quick-and-dirty personal styling changes without creating
an entire theme that you intend to distribute, you can add styles to
_user.less_ in your _~/.atom_ directory.

For example, to change the color of the highlighted line number for the line that
contains the cursor, you could add the following style to _user.less_:

```less
@highlight-color: pink;

.editor .line-number.cursor-line {
  color: @highlight-color;
}
```
