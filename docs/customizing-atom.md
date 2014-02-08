# Customizing Atom

To change a setting, configure a theme, or install a package just open the
Settings pane in the current window by pressing `cmd+,`.

## Changing The Theme

Because Atom themes are based on CSS, it's possible (and encouraged) to have
multiple themes active at the same time. Atom comes with both light and dark
interface themes as well as several syntax themes (you can also [create your
own][create-theme]).

To change the active themes just open the Settings pane (`cmd-,`) and select the
`Themes` tab. You can install non-bundled themes by going to the `Available
Themes` section on the `Packages` tab within the Settings panel.

## Installing Packages

You can install non-bundled packages by going to the `Available Packages`
section on the `Packages` tab within the Settings panel (`cmd-,`).

You can also install packages from the command line using the
[apm](https://github.com/atom/apm) command:

`apm install <package_name>` to install the latest version.

`apm install <package_name>@<package_version>` to install a specific version.

For example `apm install emmet@0.1.5` installs the `0.1.5` release of the
[Emmet](https://github.com/atom/emmet) package into `~/.atom/packages`.

## Customizing Key Bindings

Atom keymaps work similarly to stylesheets. Just as stylesheets use selectors
to apply styles to elements, Atom keymaps use selectors to associate keystrokes
with events in specific contexts. Here's a small example, excerpted from Atom's
built-in keymaps:

```coffee-script
'.editor':
  'enter': 'editor:newline'

'body':
  'ctrl-P': 'core:move-up'
  'ctrl-p': 'core:move-down'
```

This keymap defines the meaning of `enter` in two different contexts. In a
normal editor, pressing `enter` emits the `editor:newline` event, which causes
the editor to insert a newline. But if the same keystroke occurs inside of a
select list's mini-editor, it instead emits the `core:confirm` event based on
the binding in the more-specific selector.

By default, `~/.atom/keymap.cson` is loaded when Atom is started. It will always
be loaded last, giving you the chance to override bindings that are defined by
Atom's core keymaps or third-party packages.

You'll want to know all the commands available to you. Open the Settings panel
(`cmd-,`) and select the _Keybindings_ tab. It will show you all the keybindings
currently in use.

## Advanced Configuration

Atom loads configuration settings from the `config.cson` file in your _~/.atom_
directory, which contains CoffeeScript-style JSON:

```coffeescript
core:
  excludeVcsIgnoredPaths: true
editor:
  fontSize: 18
```

The configuration itself is grouped by the package name or one of the two core
namespaces: `core` and `editor`.

### Configuration Key Reference

- `core`
  - `disabledPackages`: An array of package names to disable
  - `excludeVcsIgnoredPaths`: Don't search within files specified by _.gitignore_
  - `ignoredNames`: File names to ignore across all of Atom
  - `projectHome`: The directory where projects are assumed to be located
  - `themes`: An array of theme names to load, in cascading order
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
  - `normalizeIndentOnPaste`: Enable/disable conversion of pasted tabs to spaces
  - `preferredLineLength`: Identifies the length of a line (defaults to `80`)
  - `showInvisibles`: Whether to render placeholders for invisible characters (defaults to `false`)
  - `showIndentGuide`: Show/hide indent indicators within the editor
  - `showLineNumbers`: Show/hide line numbers within the gutter
  - `softWrap`: Enable/disable soft wrapping of text within the editor
  - `softWrapAtPreferredLineLength`: Enable/disable soft line wrapping at `preferredLineLength`
  - `tabLength`: Number of spaces within a tab (defaults to `2`)
- `fuzzyFinder`
  - `ignoredNames`: Files to ignore *only* in the fuzzy-finder
- `whitespace`
  - `ensureSingleTrailingNewline`: Whether to reduce multiple newlines to one at the end of files
  - `removeTrailingWhitespace`: Enable/disable striping of whitespace at the end of lines (defaults to `true`)
- `wrap-guide`
  - `columns`: Array of hashes with a `pattern` and `column` key to match the
             the path of the current editor to a column position.

### Quick Personal Hacks

### init.coffee

When Atom finishes loading, it will evaluate _init.coffee_ in your _~/.atom_
directory, giving you a chance to run arbitrary personal CoffeeScript code to
make customizations. You have full access to Atom's API from code in this file.
If customizations become extensive, consider [creating a
package][create-a-package].

This file can also be named _init.js_ and contain JavaScript code.

### styles.css

If you want to apply quick-and-dirty personal styling changes without creating
an entire theme that you intend to distribute, you can add styles to
_styles.css_ in your _~/.atom_ directory.

For example, to change the color of the highlighted line number for the line
that contains the cursor, you could add the following style to _styles.css_:

```css
.editor .cursor {
  border-color: pink;
}
```

You can also name the file _styles.less_ if you want to style Atom using
[LESS][LESS].

[create-a-package]: creating-packages.md
[create-theme]: creating-a-theme.md
[LESS]: http://www.lesscss.org
