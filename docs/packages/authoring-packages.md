{{{
"title": "Authoring Packages"
}}}

# Authoring Packages

Packages are at the core of Atom. Nearly everything outside of the main editor manipulation
is handled by a package. That includes "core" pieces like the command panel, status bar,
file tree, and more.

A package can contain a variety of different resource types to change Atom's
behavior. The basic package layout is as follows (though not every package will
have all of these directories):

```text
my-package/
  lib/
  stylesheets/
  keymaps/
  snippets/
  grammars/
  spec/
  package.json
  index.coffee
```

**NOTE:** NPM behavior is partially implemented until we get a working Node.js
API built into Atom. The goal is to make Atom packages be a superset of NPM
packages.

Below, we'll break down each directory. There's also [a tutorial](./creating_a_package.md)
on creating your first package.

## package.json

Similar to [npm packages](http://en.wikipedia.org/wiki/Npm_(software\)), Atom packages
can contain a _package.json_ file in their top-level directory. This file contains metadata
about the package, such as the path to its "main" module, library dependencies,
and manifests specifying the order in which its resources should be loaded.

In addition to the regular [npm package.json keys](https://npmjs.org/doc/json.html)
available, Atom package.json files [have their own additions](./package_json.md).

## Source Code

If you want to extend Atom's behavior, your package should contain a single
top-level module, which you export from _index.coffee_ (or whichever file is
indicated by the `main` key in your _package.json_ file). The remainder of your
code should be placed in the `lib` directory, and required from your top-level
file.

Your package's top-level module is a singleton object that manages the lifecycle
of your extensions to Atom. Even if your package creates ten different views and
appends them to different parts of the DOM, it's all managed from your top-level
object.

Your package's top-level module should implement the following methods:

- `activate(rootView, state)`: This **required** method is called when your
package is loaded. It is always passed the window's global `rootView`, and is
sometimes passed state data if the window has been reloaded and your module
implements the `serialize` method. Use this to do initialization work when your
package is started (like setting up DOM elements or binding events).

- `serialize()`: This **optional** method is called when the window is shutting
down, allowing you to return JSON to represent the state of your component. When
the window is later restored, the data you returned is passed to your
module's `activate` method so you can restore your view to where the user left
off.

- `deactivate()`: This **optional** method is called when the window is shutting
down. If your package is watching any files or holding external resources in any
other way, release them here. If you're just subscribing to things on window,
you don't need to worry because that's getting torn down anyway.

### Simple Package Code

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
please collaborate with us if you need an API that doesn't exist. Our goal is
to build out Atom's API organically based on the needs of package authors like
you.

See [Atom's built-in packages](https://github.com/github/atom/tree/master/src/packages)
for examples of Atom's API in action.

## Stylesheets

Stylesheets for your package should be placed in the _stylesheets_ directory.
Any stylesheets in this directory will be loaded and attached to the DOM when
your package is activated. Stylesheets can be written as CSS or LESS.

An optional `stylesheets` array in your _package.json_ can list the stylesheets by
name to specify a loading order; otherwise, stylesheets are loaded alphabetically.

## Keymaps

Keymaps are placed in the _keymaps_ subdirectory. It's a good idea to provide
default keymaps for your extension, especially if you're also adding a new command.

By default, all keymaps are loaded in alphabetical order. An optional `keymaps`
array in your _package.json_ can specify which keymaps to load and in what order.

See the [main keymaps documentation](../internals/keymaps.md) for more information on
how keymaps work.

## Snippets

An extension can supply language snippets in the _snippets_ directory. These can
be `.cson` or `.json` files. Here's an example:

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

A snippets file contains scope selectors at its top level (`.source.coffee .spec`).
Each scope selector contains a hash of snippets keyed by their name (`Expect`, `Describe`).
Each snippet also specifies a `prefix` and a `body` key. The `prefix` represents
the first few letters to type before hitting the `tab` key to autocomplete. The
`body` defines the autofilled text. You can use placeholders like `$1`, `$2`, to indicate
regions in the body the user can navigate to every time they hit `tab`.

All files in the directory are automatically loaded, unless the
_package.json_ supplies a `snippets` key. As with all scoped
items, snippets loaded later take precedence over earlier snippets when two
snippets match a scope with the same specificity.

## Language Grammars

If you're developing a new language grammar, you'll want to place your file in
the _grammars_ directory. Each grammar is a pairing of two keys, `match` and
`captures`. `match` is a regular expression identifying the pattern to highlight,
while `captures` is a JSON representing what to do with each matching group.
For example:


```json
{
  'match': '(?:^|\\s)(__[^_]+__)'
  'captures':
    '1': 'name': 'markup.bold.gfm'
}
```

This indicates that the first matching capture (`(__[^_]+__)`) should have the
`markup.bold.gfm` token applied to it.

To capture a single group, simply use the `name` key instead:

```json
{
  'match': '^#{1,6}\\s+.+$'
  'name': 'markup.heading.gfm'
}
```

This indicates that Markdown header lines (`#`, `##`, `###`) should be applied with
the `markup.heading.gfm` token.

More information about the significance of these tokens can be found in
[section 12.4 of the TextMate Manual](http://manual.macromates.com/en/language_grammars.html).

Your grammar should also include a `filetypes` array, which is a list of file extensions
your grammar supports:

```
'fileTypes': [
  'markdown'
  'md'
  'mkd'
  'mkdown'
  'ron'
]
```

## Writing Tests

Your package **should** have tests, and if they're placed in the _spec_ directory,
they can be run by Atom.

Under the hood, [Jasmine](https://github.com/pivotal/jasmine) is being used to run
to execute the tests, so you can assume that any DSL available there is available
to your package as well.
