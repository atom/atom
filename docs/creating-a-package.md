# Creating Packages

Packages are at the core of Atom. Nearly everything outside of the main editor
is handled by a package. That includes "core" pieces like the [file tree][file-tree],
[status bar][status-bar], [syntax highlighting][cs-syntax], and more.

A package can contain a variety of different resource types to change Atom's
behavior. The basic package layout is as follows:

```text
my-package/
  grammars/
  keymaps/
  lib/
  menus/
  spec/
  snippets/
  styles/
  index.coffee
  package.json
```

Not every package will have (or need) all of these directories.

We have [a tutorial on creating your first package][first-package].

There are also guides for converting [TextMate bundles][convert-bundle] and
[TextMate themes][convert-theme] so they work in Atom.

## package.json

Similar to [npm packages][npm], Atom packages contain a _package.json_ file
in their top-level directory. This file contains metadata about the package,
such as the path to its "main" module, library dependencies, and manifests
specifying the order in which its resources should be loaded.

In addition to the regular [npm package.json keys][npm-keys] available, Atom
package.json files have their own additions.

- `main` (**Required**): the path to the CoffeeScript file that's the entry point
to your package.
- `styles` (**Optional**): an Array of Strings identifying the order of the
style sheets your package needs to load. If not specified, style sheets in the
_styles_ directory are added alphabetically.
- `keymaps`(**Optional**): an Array of Strings identifying the order of the
key mappings your package needs to load. If not specified, mappings in the
_keymaps_ directory are added alphabetically.
- `menus`(**Optional**): an Array of Strings identifying the order of
the menu mappings your package needs to load. If not specified, mappings
in the _menus_ directory are added alphabetically.
- `snippets` (**Optional**): an Array of Strings identifying the order of the
snippets your package needs to load. If not specified, snippets in the
_snippets_ directory are added alphabetically.
- `activationEvents` (**Optional**): an Array of Strings identifying events that
trigger your package's activation. You can delay the loading of your package
until one of these events is triggered.

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

- `activate(state)`: This **required** method is called when your
package is activated. It is passed the state data from the last time the window
was serialized if your module implements the `serialize()` method. Use this to
do initialization work when your package is started (like setting up DOM
elements or binding events).

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

Your directory would look like this:

```text
my-package/
  package.json
  index.coffee
  lib/
    my-package.coffee
```

`index.coffee` might be:
```coffeescript
module.exports = require "./lib/my-package"
```

`my-package/my-package.coffee` might start:
```coffeescript
module.exports =
  activate: (state) -> # ...
  deactivate: -> # ...
  serialize: -> # ...
```

Beyond this simple contract, your package has access to Atom's API. Be aware
that since we are early in development, APIs are subject to change and we have
not yet established clear boundaries between what is public and what is private.
Also, please collaborate with us if you need an API that doesn't exist. Our goal
is to build out Atom's API organically based on the needs of package authors
like you.

## Style Sheets

Style sheets for your package should be placed in the _styles_ directory.
Any style sheets in this directory will be loaded and attached to the DOM when
your package is activated. Style sheets can be written as CSS or [Less], but
Less is recommended.

Ideally, you won't need much in the way of styling. We've provided a standard
set of components which define both the colors and UI elements for any package
that fits into Atom seamlessly. You can view all of Atom's UI components by
opening the styleguide: open the command palette (`cmd-shift-P`) and search for
_styleguide_, or just type `cmd-ctrl-shift-G`.

If you _do_ need special styling, try to keep only structural styles in the
package style sheets. If you _must_ specify colors and sizing, these should be
taken from the active theme's [ui-variables.less][ui-variables]. For more
information, see the [theme variables docs][theme-variables]. If you follow this
guideline, your package will look good out of the box with any theme!

An optional `styleSheets` array in your _package.json_ can list the style sheets
by name to specify a loading order; otherwise, style sheets are loaded
alphabetically.

## Keymaps

It's recommended that you provide key bindings for commonly used actions for
your extension, especially if you're also adding a new command:

```coffeescript
'.tree-view-scroller':
  'ctrl-V': 'changer:magic'
```

Keymaps are placed in the _keymaps_ subdirectory. By default, all keymaps are
loaded in alphabetical order. An optional `keymaps` array in your _package.json_
can specify which keymaps to load and in what order.


Keybindings are executed by determining which element the keypress occurred on.
In the example above, `changer:magic` command is executed when pressing `ctrl-V`
on the `.tree-view-scroller` element.

See the [main keymaps documentation][keymaps] for more detailed information on
how keymaps work.

## Menus

Menus are placed in the _menus_ subdirectory. By default, all menus are loaded
in alphabetical order. An optional `menus` array in your _package.json_ can
specify which menus to load and in what order.

### Application Menu

It's recommended that you create an application menu item for common actions
with your package that aren't tied to a specific element:

```coffeescript
'menu': [
  {
    'label': 'Packages'
    'submenu': [
      {
        'label': 'My Package'
        'submenu': [
          {
            'label': 'Toggle'
            'command': 'my-package:toggle'
          }
        ]
      }
    ]
  }
]
```

To add your own item to the application menu, simply create a top level `menu`
key in any menu configuration file in _menus_. This can be a JSON or [CSON]
file.

The menu templates you specify are merged with all other templates provided
by other packages in the order which they were loaded.

### Context Menu

It's recommended to specify a context menu item for commands that are linked to
specific parts of the interface, like adding a file in the tree-view:

```coffeescript
'context-menu':
  '.tree-view': [
    {label: 'Add file', command: 'tree-view:add-file'}
  ]
  'atom-workspace': [
    {label: 'Inspect Element', command: 'core:inspect'}
  ]
```

To add your own item to the application menu simply create a top level
`context-menu` key in any menu configuration file in _menus_. This can be a
JSON or [CSON] file.

Context menus are created by determining which element was selected and then
adding all of the menu items whose selectors match that element (in the order
which they were loaded). The process is then repeated for the elements until
reaching the top of the DOM tree.

In the example above, the `Add file` item will only appear when the focused item
or one of its parents has the `tree-view` class applied to it.

You can also add separators and submenus to your context menus. To add a
submenu, provide a `submenu` key instead of a command. To add a separator, add
an item with a single `type: 'separator'` key/value pair.

```coffeescript
'context-menu':
  'atom-workspace': [
    {
      label: 'Text'
      submenu: [
        {label: 'Inspect Element', command: 'core:inspect'}
        {type: 'separator'}
        {label: 'Selector All', command: 'core:select-all'}
        {type: 'separator'}
        {label: 'Deleted Selected Text', command: 'core:delete'}
      ]
    }
  ]
```

## Snippets

An extension can supply language snippets in the _snippets_ directory which
allows the user to enter repetitive text quickly:

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

A snippets file contains scope selectors at its top level (`.source.coffee
.spec`). Each scope selector contains a hash of snippets keyed by their name
(`Expect`, `Describe`). Each snippet also specifies a `prefix` and a `body` key.
The `prefix` represents the first few letters to type before hitting the `tab`
key to autocomplete. The `body` defines the autofilled text. You can use
placeholders like `$1`, `$2`, to indicate regions in the body the user can
navigate to every time they hit `tab`.

All files in the directory are automatically loaded, unless the _package.json_
supplies a `snippets` key. As with all scoped items, snippets loaded later take
precedence over earlier snippets when two snippets match a scope with the same
specificity.

## Language Grammars

If you're developing a new language grammar, you'll want to place your file in
the _grammars_ directory. Each grammar is a pairing of two keys, `match` and
`captures`. `match` is a regular expression identifying the pattern to
highlight, while `captures` is an object representing what to do with each
matching group.

For example:


```coffeescript
{
  'match': '(?:^|\\s)(__[^_]+__)'
  'captures':
    '1': 'name': 'markup.bold.gfm'
}
```

This indicates that the first matching capture (`(__[^_]+__)`) should have the
`markup.bold.gfm` token applied to it.

To capture a single group, simply use the `name` key instead:

```coffeescript
{
  'match': '^#{1,6}\\s+.+$'
  'name': 'markup.heading.gfm'
}
```

This indicates that Markdown header lines (`#`, `##`, `###`) should be applied
with the `markup.heading.gfm` token.

More information about the significance of these tokens can be found in
[section 12.4 of the TextMate Manual][tm-tokens].

Your grammar should also include a `filetypes` array, which is a list of file
extensions your grammar supports:

```coffeescript
'fileTypes': [
  'markdown'
  'md'
  'mkd'
  'mkdown'
  'ron'
]
```

## Adding Configuration Settings

You can support config settings in your package that are editable in the
settings view. Specify a `config` key in your package main:

```coffeescript
module.exports =
  # Your config schema!
  config:
    someInt:
      type: 'integer'
      default: 23
      minimum: 1
  activate: (state) -> # ...
  # ...
```

To define the configuration, we use [json schema][json-schema] which allows you
to indicate the type your value should be, its default, etc.

See the [Config API Docs](https://atom.io/docs/api/latest/Config) for more
details specifying your configuration.

## Bundle External Resources

It's common to ship external resources like images and fonts in the package, to
make it easy to reference the resources in HTML or CSS, you can use the `atom`
protocol URLs to load resources in the package.

The URLs should be in the format of
`atom://package-name/relative-path-to-package-of-resource`, for example, the
`atom://image-view/images/transparent-background.gif` would be equivalent to
`~/.atom/packages/image-view/images/transparent-background.gif`.

You can also use the `atom` protocol URLs in themes.

## Writing Tests

Your package **should** have tests, and if they're placed in the _spec_
directory, they can be run by Atom.

Under the hood, [Jasmine] executes your tests, so you can assume that any DSL
available there is also available to your package.

## Running Tests

Once you've got your test suite written, you can run it by pressing
`cmd-alt-ctrl-p` or via the _Developer > Run Package Specs_ menu.

You can also use the `apm test` command to run them from the command line. It
prints the test output and results to the console and returns the proper status
code depending on whether the tests passed or failed.

## Publishing

Atom bundles a command line utility called apm which can be used to publish
Atom packages to the public registry.

Once your package is written and ready for distribution you can run the
following to publish your package:

```sh
cd my-package
apm publish minor
```

This will update your `package.json` to have a new minor `version`, commit the
change, create a new [Git tag][git-tag], and then upload the package to the
registry.

Run `apm help publish` to see all the available options and `apm help` to see
all the other available commands.

[file-tree]: https://github.com/atom/tree-view
[status-bar]: https://github.com/atom/status-bar
[cs-syntax]: https://github.com/atom/language-coffee-script
[npm]: http://en.wikipedia.org/wiki/Npm_(software)
[npm-keys]: https://npmjs.org/doc/json.html
[git-tag]: http://git-scm.com/book/en/Git-Basics-Tagging
[wrap-guide]: https://github.com/atom/wrap-guide/
[keymaps]: advanced/keymaps.md
[theme-variables]: theme-variables.md
[tm-tokens]: http://manual.macromates.com/en/language_grammars.html
[spacepen]: https://github.com/nathansobo/space-pen
[path]: http://nodejs.org/docs/latest/api/path.html
[jquery]: http://jquery.com/
[underscore]: http://underscorejs.org/
[jasmine]: http://jasmine.github.io
[cson]: https://github.com/atom/season
[Less]: http://lesscss.org
[ui-variables]: https://github.com/atom/atom-dark-ui/blob/master/styles/ui-variables.less
[first-package]: your-first-package.html
[convert-bundle]: converting-a-text-mate-bundle.html
[convert-theme]: converting-a-text-mate-theme.html
[json-schema]: http://json-schema.org/
