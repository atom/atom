# Configuring Atom

Atom provides a globally-available configuration database that both the core
system and extensions look to for user- and language-specific settings. A simple
use of the database is to set things like your font-size and whether you want
Atom to hide files ignored by Git. You can assign these settings by editing
`config.cson` in your `.atom` directory:

```coffeescript
core:
  hideGitIgnoredFiles: true
editor:
  fontSize: 18
```

NOTE: Currently, we only support the `.json` extension. CSON support is an
aspiration.

## Writing Config Settings

As shown above, the config database is automatically populated from `config.cson`
when Atom is started, but you can programmatically write to it in the following
way:

```coffeescript
# basic key update
config.set("editor.autosave", true)

config.get("fuzzyFinder.ignoredPaths").push "vendor"
config.update() # be sure to call `config.update` after the change
```

You can also use `setDefaults`, which will assign default values for keys that
are always overridden by values assigned with `set`. Defaults are not written out
to the the `config.json` file to prevent it from becoming cluttered.

```coffeescript
config.setDefaults("editor", fontSize: 18, showInvisibles: true)
```

See the *configuration key reference* (todo) for information on specific keys you
can use to change Atom's behavior.

## Reading Config Settings

You can read a value from `config` with `config.get`:

```coffeescript
# read a value with `config.get`
@autosave() if config.get "editor.autosave"
```

Or you can use `observeConfig` to track changes from a view object.

```coffeescript
class MyView extends View
  initialize: ->
    @observeConfig 'editor.lineHeight', (lineHeight) =>
      @adjustLineHeight(lineHeight)
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

# Themes (Not Yet Implemented)

## Selecting A Theme

Because Atom themes are based on CSS, it's possible to have multiple themes
active at the same time. For example, you might select a theme for the UI, and
another theme for syntax highlighting. You select your theme(s) in the core
preferences pane, by selecting themes from the available list and dragging them
in your preferred order. You can also edit the selected themes manually with the
`config.core.themes` array.

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
  midnight.less
  midnight.terminal.less
  midnight.tree-view.less
```

In the example above, when the `midnight` theme is loaded, its `terminal` and
`tree-view` extensions will be loaded with it. If you author a theme extension,
consider sending its author a pull request to have it included in the theme's
core.

## TextMate Compatibility

If you place a TextMate theme (either `.tmTheme` or `.plist`) in the `themes`
directory, it will automatically be translated from TextMate's format to CSS
so it works with Atom. There are a few slight differences between TextMate's
semantics and those of stylesheets, but they should be negligible in practice.

### Grammars

## TextMate Compatibility
