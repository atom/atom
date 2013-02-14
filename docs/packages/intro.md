# Packages

## Package Layout

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

**NOTE:** NPM behavior is partially implemented until we get a working Node.js
API built into Atom. The goal is to make Atom packages be a superset of NPM
packages

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

### A Simple Package Layout:

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

### Stylesheets


### Keymaps

Keymaps are placed in the `keymaps` subdirectory. By default, all keymaps will be
loaded in alphabetical order unless there is a `keymaps` array in `package.json`
specifying which keymaps to load and in what order. It's a good idea to provide
default keymaps for your extension. They can be customized by users later. See
the **main keymaps documentation** (todo) for more information.

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

## Included Packages

Atom comes with several built-in packages that add features to the default
editor.

The current built-in packages are:

  * Autocomplete
  * Command Logger
  * Command Palette
  * Fuzzy finder
  * [Markdown Preview](#markdown-preview)
  * Outline View
  * Snippets
  * Status Bar
  * Strip Trailing Whitespace
  * Tabs
  * Tree View
  * [Wrap Guide](#wrap-guide)
