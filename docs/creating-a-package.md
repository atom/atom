{{{
"title": "Creating a Package"
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

## package.json

Similar to [npm packages][npm], Atom packages
can contain a _package.json_ file in their top-level directory. This file contains metadata
about the package, such as the path to its "main" module, library dependencies,
and manifests specifying the order in which its resources should be loaded.

In addition to the regular [npm package.json keys](https://npmjs.org/doc/json.html)
available, Atom package.json files have their own additions.

- `main` (**Required**): the path to the CoffeeScript file that's the entry point
to your package
- `stylesheets` (**Optional**): an Array of Strings identifying the order of the
stylesheets your package needs to load. If not specified, stylesheets in the _stylesheets_
directory are added alphabetically.
- `keymaps`(**Optional**): an Array of Strings identifying the order of the
key mappings your package needs to load. If not specified, mappings in the _keymaps_
directory are added alphabetically.
- `menus`(**Optional**): an Array of Strings identifying the order of
the menu mappings your package needs to load. If not specified, mappings
in the _keymap_ directory are added alphabetically.
- `snippets` (**Optional**): an Array of Strings identifying the order of the
snippets your package needs to load. If not specified, snippets in the _snippets_
directory are added alphabetically.
- `activationEvents` (**Optional**): an Array of Strings identifying events that
trigger your package's activation. You can delay the loading of your package until
one of these events is trigged.

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

See [Atom's built-in packages](https://github.com/atom/atom/)
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

## Menus

Menus are placed in the _menus_ subdirectory. It's useful to specify a
context menu items if if commands are linked to a specific part of the
interface, say for example adding a file in the tree-view.

By default, all menus are loaded in alphabetical order. An optional
`menus` array in your _package.json_ can specify which menus to load
and in what order.

Context menus are created by determining which element was selected and
then adding all of the menu items whose selectors match that element (in
the order which they were loaded). The process is then repeated for the
elements until reaching the top of the dom tree.

NOTE: Currently you can only specify items to be added to the context
menu, the menu which appears when you right click. There are plans to
add support for adding to global menu.

```
'context-menu':
  '.tree-view':
    'Add file': 'tree-view:add-file'
  '#root-view':
    'Inspect Element': 'core:inspect'
```

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
while `captures` is an object representing what to do with each matching group.

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

This indicates that Markdown header lines (`#`, `##`, `###`) should be applied with
the `markup.heading.gfm` token.

More information about the significance of these tokens can be found in
[section 12.4 of the TextMate Manual](http://manual.macromates.com/en/language_grammars.html).

Your grammar should also include a `filetypes` array, which is a list of file extensions
your grammar supports:

```coffeescript
'fileTypes': [
  'markdown'
  'md'
  'mkd'
  'mkdown'
  'ron'
]
```

## Bundle External Resources

It's common to ship external resources like images and fonts in the package, to
make it easy to reference the resources in HTML or CSS, you can use the `atom`
protocol URLs to load resources in the package.

The URLs should be in the format of
`atom://package-name/relative-path-to-package-of-resource`, for example, the
`atom://image-view/images/transparent-background.gif` would be equivablent to
`~/.atom/packages/image-view/images/transparent-background.gif`.

You can also use the `atom` protocol URLs in themes.

## Writing Tests

Your package **should** have tests, and if they're placed in the _spec_ directory,
they can be run by Atom.

Under the hood, [Jasmine](https://github.com/pivotal/jasmine) is being used to
execute the tests, so you can assume that any DSL available there is available
to your package as well.

# Full Example

Let's take a look at creating our first package.

Atom has a command you can enter that'll create a package for you:
`package-generator:generate`. Otherwise, you can hit `cmd-p`, and start typing
"Package Generator." Once you activate this package, it'll ask you for a name for
your new package. Let's call ours _changer_.

Now, _changer_ is going to have a default set of folders and files created for us.
Hit `cmd-r` to reload Atom, then hit `cmd-p` and start typing "Changer." You'll
see a new `Changer:Toggle` command which, if selected, pops up a new message. So
far, so good!

In order to demonstrate the capabilities of Atom and its API, our Changer plugin
is going to do two things:

1. It'll show only modified files in the file tree
2. It'll append a new pane to the editor with some information about the modified
files

Let's get started!

## Changing Keybindings and Commands

Since Changer is primarily concerned with the file tree, let's write a keybinding
that works only when the tree is focused. Instead of using the default `toggle`,
our keybinding executes a new command called `magic`.

_keymaps/changer.cson_ can easily become this:

```coffeescript
'.tree-view-scroller':
  'ctrl-V': 'changer:magic'
```

Notice that the keybinding is called `ctrl-V`--that's actually `ctrl-shift-v`.
You can use capital letters to denote using `shift` for your binding.

`.tree-view-scroller` represents the parent container for the tree view. Keybindings
only work within the context of where they're entered. For example, hitting `ctrl-V`
anywhere other than tree won't do anything. You can map to `body` if you want
to scope to anywhere in Atom, or just `.editor` for the editor portion.

To bind keybindings to a command, we'll use the `rootView.command` method. This
takes a command name and executes a function in the code. For example:

```coffeescript
rootView.command "changer:magic", => @magic()
```

It's common practice to namespace your commands with your package name, and separate
it with a colon (`:`). Rename the existing `toggle` method to `magic` to get the
binding to work.

Reload the editor, click on the tree, hit your keybinding, and...nothing happens! What the heck?!

Open up the _package.json_ file, and notice the key that says `activationEvents`.
Basically, this tells Atom to not load a package until it hears a certain event.
Let's change the event to `changer:magic` and reload the editor.

Hitting the key binding on the tree now works!

## Working with styles

The next step is to hide elements in the tree that aren't modified. To do that,
we'll first try and get a list of files that have not changed.

All packages are able to use jQuery in their code. In fact, we have [a list of
some of the bundled libraries Atom provides by default](#included-libraries).

Let's bring in jQuery:

```coffeescript
$ = require 'jquery'
```

Now, we can query the tree to get us a list of every file that _wasn't_ modified:

```coffeescript
magic: ->
  $('ol.entries li').each (i, el) ->
    if !$(el).hasClass("modified")
      console.log el
```

You can access the dev console by hitting `alt-cmd-i`. When we execute the
`changer:magic` command, the browser console lists the items that are not being
modified. Let's add a class to each of these elements called `hide-me`:

```coffeescript
magic: ->
  $('ol.entries li').each (i, el) ->
    if !$(el).hasClass("modified")
      $(el).addClass("hide-me")
```

With our newly added class, we can manipulate the visibility of the elements
with a simple stylesheet. Open up _changer.css_ in the _stylesheets_ directory,
and add a single entry:

```css
ol.entries .hide-me {
  display: none;
}
```

Refresh atom, and run the `changer` command. You'll see all the non-changed files
disappear from the tree. There are a number of ways you can get the list back;
let's just naively iterate over the same elements and remove the class:

```coffeescript
magic: ->
  $('ol.entries li').each (i, el) ->
    if !$(el).hasClass("modified")
      if !$(el).hasClass("hide-me")
        $(el).addClass("hide-me")
      else
        $(el).removeClass("hide-me")
```

## Creating a New Pane

The next goal of this package is to append a pane to the Atom editor that lists
some information about the modified files.

To do that, we're going to first create a new class method called `content`. Every
package that extends from the `View` class can provide an optional class method
called `content`. The `content` method constructs the DOM that your package uses
as its UI. The principals of `content` are built entirely on [SpacePen](https://github.com/nathansobo/space-pen),
which we'll touch upon only briefly here.

Our display will simply be an unordered list of the file names, and their
modified times. Let's start by carving out a `div` to hold the filenames:

```coffeescript
@content: ->
  @div class: 'modified-files-container', =>
    @ul class: 'modified-files-list', outlet: 'modifiedFilesList', =>
      @li 'Test'
      @li 'Test2'
```

You can add any HTML5 attribute you like. `outlet` names the variable
your package can uses to manipulate the element directly. The fat pipe (`=>`) indicates
that the next set are nested children.

We'll add one more line to `magic` to make this pane appear:

```coffeescript
rootView.vertical.append(this)
```

If you hit the key command, you'll see a box appear right underneath the editor.
Success!

Before we populate this, let's apply some logic to toggle the pane off and on, just
like we did with the tree view:

```coffeescript
# toggles the pane
if @hasParent()
  rootView.vertical.children().last().remove()
else
  rootView.vertical.append(this)
```

There are about a hundred different ways to toggle a pane on and off, and this
might not be the most efficient one. If you know your package needs to be toggled
on and off more freely, it might be better to draw the UI during the initialization,
then immediately call `hide()` on the element to remove it from the view. You can
then swap between `show()` and `hide()`, and instead of forcing Atom to add and remove
the element as we're doing here, it'll just set a CSS property to control your package's
visibility.

You might have noticed that our two `li` elements aren't showing up. Let's set
a color on them so that they pop. Open up `changer.css` and add this CSS:

```css
ul.modified-files-list {
  color: white;
}
```

Refresh Atom, hit the key combo, and see your brilliantly white test list.

## Calling Node.js Code

Since Atom is built on top of Node.js, you can call any of its libraries, including
other modules that your package requires.

We'll iterate through our resulting tree, and construct the path to our modified
file based on its depth in the tree:

```coffeescript
path = require 'path'

# ...

modifiedFiles = []
# for each single entry...
$('ol.entries li.file.modified span.name').each (i, el) ->
  filePath = []
  # ...grab its name...
  filePath.unshift($(el).text())

  # ... then find its parent directories, and grab their names
  parents = $(el).parents('.directory.modified')
  parents.each (i, el) ->
    filePath.unshift($(el).find('div.header span.name').eq(0).text())

  modifiedFilePath = path.join(project.rootDirectory.path, filePath.join(path.sep))
  modifiedFiles.push modifiedFilePath
```

`modifiedFiles` is an array containing a list of our modified files. We're also using
the node.js [`path` library](http://nodejs.org/docs/latest/api/path.html) to get
the proper directory separator for our system.

Let's remove the two `@li` elements we added in `@content`, so that we can populate
our `modifiedFilesList` with real information. We'll do that by iterating over
`modifiedFiles`, accessing a file's last modified time, and appending it to
`modifiedFilesList`:

```coffeescript
# toggles the pane
if @hasParent()
  rootView.vertical.children().last().remove()
else
  for file in modifiedFiles
    stat = fs.lstatSync(file)
    mtime = stat.mtime
    @modifiedFilesList.append("<li>#{file} - Modified at #{mtime}")
  rootView.vertical.append(this)
```

When you toggle the modified files list, your pane is now populated with the filenames
and modified times of files in your project. You might notice that subsequent calls
to this command reduplicate information. We could provide an elegant way of rechecking
files already in the list, but for this demonstration, we'll just clear the `modifiedFilesList`
each time it's closed:

```coffeescript
# toggles the pane
if @hasParent()
  @modifiedFilesList.empty()
  rootView.vertical.children().last().remove()
else
  for file in modifiedFiles
    stat = fs.lstatSync(file)
    mtime = stat.mtime
    @modifiedFilesList.append("<li>#{file} - Modified at #{mtime}")
  rootView.vertical.append(this)
```

# Included Libraries

In addition to core node.js modules, all packages can `require` the following popular
libraries into their packages:

* [SpacePen](https://github.com/nathansobo/space-pen) (as `require 'space-pen'`)
* [jQuery](http://jquery.com/) (as `require 'jquery'`)
* [Underscore](http://underscorejs.org/) (as `require 'underscore'`)

Additional libraries can be found by browsing Atom's _node_modules_ folder.


[npm]: http://en.wikipedia.org/wiki/Npm_(software)
