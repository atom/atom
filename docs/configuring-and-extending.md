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


# Packages

## Installing Packages (Partially Implemented)

To install a package, clone it into the `~/.atom/packages` directory.
If you want to disable a package without removing it from the packages
directory, insert its name into `config.core.disabledPackages`:

config.cson:
```coffeescript
core:
  disabledPackages: [
    "fuzzy-finder",
    "tree-view"
  ]
```

## Anatomy of a Package

A package can contain a variety of different resource types to change Atom's
behavior. The basic package layout is as follows (not every package will
have all of these directories):

```text
my-package/
  lib/
  config/
  stylesheets/
  keymaps/
  snippets/
  grammars/
  package.json
  index.coffee
```

**NOTE: NPM behavior is partially implemented until we get a working Node.js
API built into Atom. The goal is to make Atom packages be a superset of NPM
packages**

### package.json

Similar to npm packages, Atom packages can contain a `package.json` file in their
top-level directory. This file contains metadata about the package, such as the
path to its "main" module, library dependencies, and manifests specifying the
order in which its resources should be loaded.

### Source Code

If you want to extend Atom's behavior, your package should contain a single
top-level module, which you export from `index.coffee` or another file as
indicated by the `main` key in your `package.json` file. The remainder of your
code should be placed in the `lib` directory, and required from your top-level
file.

Your package's top-level module is a singleton object that manages the lifecycle
of your extensions to Atom. Even if your package creates ten different views and
appends them to different parts of the DOM, it's all managed from your top-level
object. Your package's top-level module should implement the following methods:

- `activate(rootView, state)` **Required**: This method is called when your
package is loaded. It is always passed the window's global `rootView`, and is
sometimes passed state data if the window has been reloaded and your module
implements the `serialize` method.

- `serialize()` **Optional**: This method is called when the window is shutting
down, allowing you to return JSON to represent the state of your component. When
the window is later restored, the data you returned will be passed to your
module's `activate` method so you can restore your view to where the user left
off.

- `deactivate()` **Optional**: This method is called when the window is shutting
down. If your package is watching any files or holding external resources in any
other way, release them here. If you're just subscribing to things on window
you don't need to worry because that's getting torn down anyway.

#### A Simple Package Layout:

```text
my-package/
  package.json # optional
  index.coffee
  lib/
    my-package.coffee
```

`index.coffee`:
```coffeescript
module.exports = require "./lib/my-package"
```

`my-package/my-package.coffee`:
```coffeescript
module.exports =
  activate: (rootView, state) -> # ...
  deactivate: -> # ...
  serialize: -> # ...
```

Beyond this simple contract, your package has full access to Atom's internal
API. Anything we call internally, you can call as well. Be aware that since we
are early in development, APIs are subject to change and we have not yet
established clear boundaries between what is public and what is private. Also,
Please collaborate with us if you need an API that doesn't exist. Our goal is
to build out Atom's API organically based on the needs of package authors like
you. See [Atom's built-in packages](https://github.com/github/atom/tree/master/src/packages)
for examples of Atom's API in action.

### Config Settings

### Stylesheets

### Keymaps (Not Implemented)

Keymaps are placed in the `keymaps` subdirectory. By default, all keymaps will be
loaded in alphabetical order unless there is a `keymaps` array in `package.json`
specifying which keymaps to load and in what order. It's a good idea to provide
default keymaps for your extension. They can be customized by users later. See
the **main keymaps documentation** (todo) for more information.

### Snippets (Not Implemented)

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
