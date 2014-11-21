# Customizing Atom

To change a setting, configure a theme, or install a package just open the
Settings view in the current window by pressing `cmd-,`.

## Changing The Theme

Atom comes with both light and dark UI themes as well as several syntax themes.
You are also encouraged to [create or fork][create-theme] your own theme.

To change the active theme just open the Settings view (`cmd-,`) and select the
`Themes` section from the left hand side. You will see a drop-down menu to
change the active _Syntax_ and _UI_ themes.

You can also install more themes from here by browsing the featured themes or
searching for a specific theme.

## Installing Packages

You can install non-bundled packages by going to the `Packages` section on left
hand side of the Settings view (`cmd-,`). You will see several featured packages
and you can also search for packages from here. The packages listed here have
been published to [atom.io](http://atom.io/packages) which is the official
registry for Atom packages.

You can also install packages from the command line using `apm`.

Check that you have `apm` installed by running the following command in your
terminal:

```sh
apm help install
```

You should see a message print out with details about the `apm install` command.

If you do not, launch Atom and run the _Atom > Install Shell Commands_ menu
to install the `apm` and `atom` commands.

You can also install packages by using the `apm install` command:

* `apm install <package_name>` to install the latest version.

* `apm install <package_name>@<package_version>` to install a specific version.

For example `apm install emmet@0.1.5` installs the `0.1.5` release of the
[Emmet](https://github.com/atom/emmet) package into `~/.atom/packages`.

You can also use `apm` to find new packages to install:

* `apm search coffee` to search for CoffeeScript packages.

* `apm view emmet` to see more information about a specific package.

## Customizing Key Bindings

Atom keymaps work similarly to stylesheets. Just as stylesheets use selectors
to apply styles to elements, Atom keymaps use selectors to associate keystrokes
with events in specific contexts. Here's a small example, excerpted from Atom's
built-in keymaps:

```coffee
'atom-text-editor':
  'enter': 'editor:newline'

'atom-text-editor[mini] input':
  'enter': 'core:confirm'
```

This keymap defines the meaning of `enter` in two different contexts. In a
normal editor, pressing `enter` emits the `editor:newline` event, which causes
the editor to insert a newline. But if the same keystroke occurs inside of a
select list's mini-editor, it instead emits the `core:confirm` event based on
the binding in the more-specific selector.

By default, `~/.atom/keymap.cson` is loaded when Atom is started. It will always
be loaded last, giving you the chance to override bindings that are defined by
Atom's core keymaps or third-party packages.

You can open this file in an editor from the _Atom > Open Your Keymap_ menu.

You'll want to know all the commands available to you. Open the Settings panel
(`cmd-,`) and select the _Keybindings_ tab. It will show you all the keybindings
currently in use.

## Advanced Configuration

Atom loads configuration settings from the `config.cson` file in your _~/.atom_
directory, which contains [CoffeeScript-style JSON][CSON] (CSON):

```coffee
'core':
  'excludeVcsIgnoredPaths': true
'editor':
  'fontSize': 18
```

The configuration itself is grouped by the package name or one of the two core
namespaces: `core` and `editor`.

You can open this file in an editor from the _Atom > Open Your Config_ menu.

### Configuration Key Reference

- `core`
  - `disabledPackages`: An array of package names to disable
  - `excludeVcsIgnoredPaths`: Don't search within files specified by _.gitignore_
  - `ignoredNames`: File names to ignore across all of Atom
  - `projectHome`: The directory where projects are assumed to be located
  - `themes`: An array of theme names to load, in cascading order
- `editor`
  - `autoIndent`: Enable/disable basic auto-indent (defaults to `true`)
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
directory, giving you a chance to run arbitrary personal [CoffeeScript][] code to
make customizations. You have full access to Atom's API from code in this file.
If customizations become extensive, consider [creating a package][creating-a-package].

You can open this file in an editor from the _Atom > Open Your Init Script_
menu.

For example, if you have the Audio Beep configuration setting enabled, you
could add the following code to your _~/.atom/init.coffee_ file to have Atom
greet you with an audio beep every time it loads:

```coffee
atom.beep()
```

This file can also be named _init.js_ and contain JavaScript code.

### styles.less

If you want to apply quick-and-dirty personal styling changes without creating
an entire theme that you intend to publish, you can add styles to the
_styles.less_ file in your _~/.atom_ directory.

You can open this file in an editor from the _Atom > Open Your Stylesheet_ menu.

For example, to change the color of the cursor, you could add the following
rule to your _~/.atom/styles.less_ file:

```less
atom-text-editor.is-focused .cursor {
  border-color: pink;
}
```

Unfamiliar with LESS? Read more about it [here][LESS].

This file can also be named _styles.css_ and contain CSS.

[creating-a-package]: creating-a-package.md
[create-theme]: creating-a-theme.md
[LESS]: http://www.lesscss.org
[CSON]: https://github.com/atom/season
[CoffeeScript]: http://coffeescript.org/
