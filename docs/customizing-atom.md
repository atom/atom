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

## Customizing Key Bindings

Atom keymaps work similarly to stylesheets. Just as stylesheets use selectors
to apply styles to elements, Atom keymaps use selectors to associate keystrokes
with events in specific contexts. Here's a small example, excerpted from Atom's
built-in keymaps:

```coffee-script
'.editor':
  'enter': 'editor:newline'

".select-list .editor.mini":
  'enter': 'core:confirm'
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

## Advanced Configuration

Atom loads configuration settings from the `config.cson` file in your _~/.atom_
directory, which contains CoffeeScript-style JSON:

```coffeescript
core:
  hideGitIgnoredFiles: true
editor:
  fontSize: 18
```

The configuration itself is grouped by the package name or one of the two core
namespaces: `core` and `editor`.

### Configuration Key Reference

- `core`
  - `autosave`: Save a buffer when its view loses focus
  - `disabledPackages`: An array of package names to disable
  - `excludeVcsIgnoredPaths`: Don't search within files specified by _.gitignore_
  - `hideGitIgnoredFiles`: Whether files in the _.gitignore_ should be hidden
  - `ignoredNames`: File names to ignore across all of Atom (not fully implemented)
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
- `wrapGuide`
  - `columns`: Array of hashes with a `pattern` and `column` key to match the
             the path of the current editor to a column position.

### Quick Personal Hacks

### user.coffee

When Atom finishes loading, it will evaluate _user.coffee_ in your _~/.atom_
directory, giving you a chance to run arbitrary personal CoffeeScript code to
make customizations. You have full access to Atom's API from code in this file.
If customizations become extensive, consider [creating a
package][create-a-package].

### user.less

If you want to apply quick-and-dirty personal styling changes without creating
an entire theme that you intend to distribute, you can add styles to
_user.less_ in your _~/.atom_ directory.

For example, to change the color of the highlighted line number for the line
that contains the cursor, you could add the following style to _user.less_:

```less
@highlight-color: pink;

.editor .line-number.cursor-line {
  color: @highlight-color;
}
```

[create-a-package]: creating-packages.md
[create-theme]: creating-a-theme.md
