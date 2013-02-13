# Configuring Atom

Atom loads configuration settings from the `config.cson` file in your `~/.atom`
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

## Configuration Glossary

- core
  - disablePackages: An array of package names to disable
  - hideGitIgnoredFiles: Whether files in the .gitignore should be hidden
  - ignoredNames: File names to ignore across all of atom
  - themes: An array of theme names to load, in cascading order
- editor
  - autoIndent: Enable/disable basic auto-indent (defaults to true)
  - autoIndentOnPaste: Enable/disable auto-indented pasted text (defaults to false)
  - autosave: Save a file when an editor loses focus
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
- stripTrailingWhitespace
  - singleTrailingNewline: Whether to reduce multiple newlines to one at the end of files
- wrapGuide
  - columns: Soon to be replaced by editor.preferredLineLength

## Reading Config Settings

If you are writing a package that you want to make configurable, you'll need to
read config settings. You can read a value from `config` with `config.get`:

```coffeescript
# read a value with `config.get`
@autosave() if config.get "editor.autosave"
```

Or you can use `observeConfig` to track changes from a view object.

```coffeescript
class MyView extends View
  initialize: ->
    @observeConfig 'editor.fontSize', () =>
      @adjustFontSize()
```

The `observeConfig` method will call the given callback immediately with the
current value for the specified key path, and it will also call it in the future
whenever the value of that key path changes.

Subscriptions made with `observeConfig` are automatically cancelled when the
view is removed. You can cancel config subscriptions manually via the
`unobserveConfig` method.

```coffeescript
view1.unobserveConfig() # unobserve all properties
```

You can add the ability to observe config values to non-view classes by
extending their prototype with the `ConfigObserver` mixin:

```coffeescript
ConfigObserver = require 'config-observer'
_.extend MyClass.prototype, ConfigObserver
```

## Writing Config Settings

As shown above, the config database is automatically populated from `config.cson`
when Atom is started, but you can programmatically write to it in the following
way:

```coffeescript
# basic key update
config.set("editor.autosave", true)

# if you mutate a config key, you'll need to call `config.update` to inform
# observers of the change
config.get("fuzzyFinder.ignoredPaths").push "vendor"
config.update()
```

You can also use `setDefaults`, which will assign default values for keys that
are always overridden by values assigned with `set`. Defaults are not written out
to the the `config.json` file to prevent it from becoming cluttered.

```coffeescript
config.setDefaults("editor", fontSize: 18, showInvisibles: true)
```

# Themes

## Selecting A Theme

Atom comes bundles with two themes "Atom - Dark" and "Atom - Light". You can
select a theme in your core preferences pane.

Because Atom themes are based on CSS, it's possible to have multiple themes
active at the same time. For example, you might select a theme for the UI, and
another theme for syntax highlighting. You select your theme(s) in the core
preferences pane, by selecting themes from the available list and dragging them
in your preferred order. You can also edit the selected themes manually with the
`config.core.themes` array. For example.

```js
{
  "core": {
    "themes": ["Atom - Light", "Mac Classic"]
  },
  "editor": {
    "fontSize": 15
  }
}
```

## Installing A Theme

You install themes by placing them in the `~/.atom/themes` directory. The most
basic theme is just a `.css` or `.less` file. More complex occupy their own
folder, which can contain multiple stylesheets along with an optional
`package.json` file with a manifest to control their load-order:

```text
~/.atom/themes/
  midnight.less
  rockstar.css
  rainbow/
    package.json
    core.less
    editor.less
    tree-view.less
```

package.json:
```json
{
  "stylesheets": ["core.css", "editor.less", "tree-view.css"]
}
```

The package.json specifies which stylesheets to load and in what order with the
`stylesheets` key. If no manifest is specified, all stylesheets are loaded in
alphabetical order when the user selects the theme.

## Authoring A Theme

If you understand CSS, you can write an Atom theme easily. Your theme can style
Atom's user interface, specify the appearance of syntax-highlighted code, or
both. For making a syntax highlighting theme, refer to [section 12.4 of the
TextMate Manual](http://manual.macromates.com/en/language_grammars.html) for a
list of the common scopes used by TextMate grammars. You'll just need to
scope names to CSS classes. To theme Atom's user interface, refer to
[Classnames for Extension and Theme Authors]() for information about the CSS
classes used in Atom's core and the most common classes employed by
extensions.

## Theme Extensions

A theme will often cover the stock features of Atom, but may need to be extended
to cover extensions that weren't covered by its original author. Theme extensions
make this easy to organize. To make a theme extension, just add a theme that
matches the name of the original with an additional filename extension:

```text
~/.atom/themes/
  midnight/midnight.less
  midnight/packages/terminal.less
  midnight/packages/tree-view.less
```

In the example above, when the `midnight` theme is loaded, its `terminal` and
`tree-view` extensions will be loaded with it. If you author a theme extension,
consider sending its author a pull request to have it included in the theme's
core. Package theme extensions, do not need to be in `package.json` because they
will be loaded when needed by the package.

## TextMate Compatibility

If you place a TextMate theme (either `.tmTheme` or `.plist`) in the `themes`
directory, it will automatically be translated from TextMate's format to CSS
so it works with Atom. There are a few slight differences between TextMate's
semantics and those of stylesheets, but they should be negligible in practice.

### Grammars

## TextMate Compatibility
