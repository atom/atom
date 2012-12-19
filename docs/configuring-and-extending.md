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

You can also use `setDefaults`, which will assign keys on the object at the given
only if they are currently undefined.

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
view2.unobserveConfig("editor.lineHeight") # unobserve a specific property
```

You can add the ability to observe config values to non-view classes by
extending their prototype with the `ConfigObserver` mixin:

```coffeescript
ConfigObserver = require 'config-observer'
_.extend MyClass.prototype, ConfigObserver
```

## Scoped Config Settings

Users and extension authors can provide language-specific behavior by employing
*scoped configuration keys*. By associating key values with a specific scope,
you can make Atom behave differently in different contexts. For example, if you
want Atom to auto-indent pasted text in some languages but not others, you can
give the `autoIndentPastedText` key a different value under a scope selector:

```coffeescript
# in config.cson
editor:
  autoIndentPastedText: true
scopes:
  ".source.coffee":
    editor:
      autoIndentPastedText: false
```

Scope selectors are placed under the `scope` key at the top-level of the
configuration file. The values you specify for keys under a selector will
override global values in that specific scope. Any basic CSS 3 selector is
permitted, but you should leave out element names to make your keys accessible
outside the view layer.

### Reading Scoped Config Settings

Use the `config.inScope` method to the read keys with the most specific selector
match:

```coffeescript
scope = [".source.coffee", ".meta.class.instance.constructor"]
config.inScope(scope).get "editor.lineComment"
```

Pass `.inScope` an array of scope descriptors, which describes a specific
element. This is frequently useful when you get the nested scopes for a position
in the buffer based on its syntax. You can also pass an actual DOM element
to use its nesting within the DOM as fodder for the scope selectors (†).

```coffeescript
config.inScope(fuzzyFinder.miniEditor).get("editor.fontSize")
```

`observeConfig` can take a scope as its first argument:

```
@observeConfig scope, "editor.autoIndentPastedText", -> # ...
```

†:  Matching DOM elements fits cleanly into this scheme, but I can't think of a
    use for it currently. Let's keep it in the back of our minds though.

# Themes

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
  "stylesheets": ["core", "editor", "tree-view"]
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


# Extensions

## Installing Extensions

To install an extension, clone it into the `~/.atom/extensions` directory.
If you want to disable an extension without removing it from the extensions
directory, insert its name into `config.core.disabledExtensions`:

config.cson:
```coffeescript
core:
  disabledExtensions: [
    "fuzzy-finder",
    "tree-view"
  ]
```

## Writing Extensions

An extension can bundle a variety of different resource types to change Atom's
behavior. The basic extension layout is as follows (not every extension will
have all of these directories):

```text
my-extension/
  lib/
  config/
  stylesheets/
  keymaps/
  snippets/
  grammars/
  package.json
  index.coffee
```

### Source Code

Extensions can contain arbitrary CoffeeScript code. Place an `index.coffee` file
in the extension directory, or specify a `main` key in the extension's optional
`package.json` file. Place the bulk of your code in the extension's `lib`
directory, and require it from `index.coffee`.

```text
my-extension/
  lib/
    my-extension.coffee
    rocket.coffee
  package.json # optional
  index.coffee
```
### Config Settings:

### Stylesheets

### Keymaps

Keymaps (with the `.keymap` extension) can be placed at the root of the
extension or in the `keymaps` subdirectory. By default, all keymaps will be
loaded in alphabetical order unless there is a `keymaps` array in `package.json`
specifying which keymaps to load and in what order. It's a good idea to provide
default keymaps for your extension. They can be customized by users later. See
the [main keymaps documentation]() for more information.

### Snippets

An extension can supply snippets in a `snippets` directory as `.cson` or `.json`
files:

```coffeescript
".source.coffee .specs":
  "Expect":
    prefix: "ex"
    body: "expect($1).to$2"
  "Describe":
    prefix: "de"
    body: """
      describe "${1:description}", ->
        ${2:body}
    """
```

A snippets file contains scope selectors at its top level. Each scope selector
contains a hash of snippets keyed by their name. Each snippet specifies a `prefix`
and a `body` key.

All files in the directory will be automatically loaded, unless the
`package.json` supplies a `snippets` key as a manifest. As with all scoped items,
snippets loaded later take precedence over earlier snippets when two snippets
match a scope with the same specificity.

### Grammars

## TextMate Compatibility
