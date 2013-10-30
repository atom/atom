# Creating Your First Package

Let's take a look at creating your first package.

To get started, hit `cmd-p`, and start typing "Package Generator" to generate
a package. Once you select the "Generate Package" command, it'll ask you for a
name for your new package. Let's call ours _changer_.

Atom will pop open a new window, showing the _changer_ with a default set of
folders and files created for us. Hit `cmd-p` and start typing "Changer." You'll
see a new `Changer:Toggle` command which, if selected, pops up a greeting. So far,
so good!

In order to demonstrate the capabilities of Atom and its API, our Changer plugin
is going to do two things:

1. It'll show only modified files in the file tree
2. It'll append a new pane to the editor with some information about the modified
files

Let's get started!

## Changing Keybindings and Commands

Since Changer is primarily concerned with the file tree, let's write a
key binding that works only when the tree is focused. Instead of using the
default `toggle`, our keybinding executes a new command called `magic`.

_keymaps/changer.cson_ should change to look like this:

```coffeescript
'.tree-view':
  'ctrl-V': 'changer:magic'
```

Notice that the keybinding is called `ctrl-V` &mdash; that's actually `ctrl-shift-v`.
You can use capital letters to denote using `shift` for your binding.

`.tree-view` represents the parent container for the tree view.
Keybindings only work within the context of where they're entered. In this case,
hitting `ctrl-V` anywhere other than tree won't do anything. Obviously, you can
bind to any part of the editor using element, id, or class names. For example,
you can map to `body` if you want to scope to anywhere in Atom, or just `.editor`
for the editor portion.

To bind keybindings to a command, we'll need to do a bit of association in our
CoffeeScript code using the `rootView.command` method. This method takes a command
name and executes a callback function. Open up _lib/changer-view.coffee_, and
change `rootView.command "changer:toggle" to look like this:

```coffeescript
rootView.command "changer:magic", => @magic()
```

It's common practice to namespace your commands with your package name, separated
with a colon (`:`).

Every time you reload the Atom editor, changes to your package code will be reevaluated,
just as if you were writing a script for the browser. Reload the editor, click on
the tree, hit your keybinding, and...nothing happens! What the heck?!

Open up the _package.json_ file, and find the property called `activationEvents`.
Basically, this key tells Atom to not load a package until it hears a certain event.
Change the event to `changer:magic` and reload the editor:

```json
"activationEvents": ["changer:toggle"]
```

Hitting the key binding on the tree now works!

## Working with Styles

The next step is to hide elements in the tree that aren't modified. To do that,
we'll first try and get a list of files that have not changed.

All packages are able to use jQuery in their code. In fact, there's [a list of
the bundled libraries Atom provides by default][bundled-libs].

We bring in jQuery by requiring the `atom` package and binding it to the `$` variable:

```coffeescript
{$} = require 'atom'
```

Now, we can define the `magic` method to query the tree to get us a list of every
file that _wasn't_ modified:

```coffeescript
magic: ->
  $('ol.entries li').each (i, el) ->
    if !$(el).hasClass("status-modified")
      console.log el
```

You can access the dev console by hitting `alt-cmd-i`. Here, you'll see all the
statements from `console` calls. When we execute the `changer:magic` command, the
browser console lists items that are not being modified (_i.e._, those without the
`status-modified` class). Let's add a class to each of these elements called `hide-me`:

```coffeescript
magic: ->
  $('ol.entries li').each (i, el) ->
    if !$(el).hasClass("status-modified")
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

Refresh Atom, and run the `changer` command. You'll see all the non-changed
files disappear from the tree. Success!

![Changer File View][changer-file-view]

There are a number of ways you can get the list back; let's just naively iterate
over the same elements and remove the class:

```coffeescript
magic: ->
  $('ol.entries li').each (i, el) ->
    if !$(el).hasClass("status-modified")
      if !$(el).hasClass("hide-me")
        $(el).addClass("hide-me")
      else
        $(el).removeClass("hide-me")
```

## Creating a New Panel

The next goal of this package is to append a panel to the Atom editor that lists
some information about the modified files.

To do that, we're going to first open up [the style guide][style-guide]. The Style
Guide lists every type of UI element that can be created by an Atom package. Aside
from helping you avoid writing fresh code from scratch, it ensures that packages
have the same look and feel no matter how they're built.

Every package that extends from the `View` class can provide an optional class
method called `content`. The `content` method constructs the DOM that your
package uses as its UI. The principals of `content` are built entirely on
[SpacePen][space-pen], which we'll touch upon only briefly here.

Our display will simply be an unordered list of the file names, and their
modified times. A basic Panel element will work well for us. Let's start by
carving out a `div` to hold the filenames:

```coffeescript
@content: ->
  @div class: "panel", =>
    @div class: "panel-heading", "Modified Files"
    @div class: "panel-body padded", outlet: 'modifiedFilesContainer', =>
      @ul class: 'modified-files-list', outlet: 'modifiedFilesList', =>
        @li 'Modified File Test'
        @li 'Modified File Test'
```

You can add any HTML attribute you like. `outlet` names the variable your
package can use to manipulate the element directly. The fat pipe (`=>`)
indicates that the next DOM set are nested children.

Once again, you can style `li` elements using your stylesheets. Let's test that
out by adding these lines to the _changer.css_ file:

```css
ul.modified-files-list {
  color: white;
}
```

We'll add one more line to the end of the `magic` method to make this pane appear:

```coffeescript
rootView.vertical.append(this)
```

If you refresh Atom and hit the key command, you'll see a box appear right underneath
the editor:

![Changer Panel][changer-panel-append]

As you might have guessed, `rootView.vertical.append` tells Atom to append `this`
item (_i.e._, whatever is defined by`@content`) _vertically_ to the editor. If
we had called `rootView.horizontal.append`, the pane would be attached to the
right-hand side of the editor.

Before we populate this panel for real, let's apply some logic to toggle the pane
off and on, just like we did with the tree view. Replace the `rootView.vertical.append`
call with this code:

```coffeescript
# toggles the pane
if @hasParent()
  rootView.vertical.children().last().remove()
else
  rootView.vertical.append(this)
```

There are about a hundred different ways to toggle a pane on and off, and this
might not be the most efficient one. If you know your package needs to be
toggled on and off more freely, it might be better to draw the interface during the
initialization, then immediately call `hide()` on the element to remove it from
the view. You can then swap between `show()` and `hide()`, and instead of
forcing Atom to add and remove the element as we're doing here, it'll just set a
CSS property to control your package's visibility.

Refresh Atom, hit the key combo, and watch your test list appear and disappear.

## Calling Node.js Code

Since Atom is built on top of [Node.js][node], you can call any of its libraries,
including other modules that your package requires.

We'll iterate through our resulting tree, and construct the path to our modified
file based on its depth in the tree. We'll use Node to handle path joining for
directories.

Add the following Node module to the top of your file:

```coffeescript
path = require 'path'
```

Then, add these lines to your `magic` method, _before_ your pane drawing code:

```coffeescript
modifiedFiles = []
# for each single entry...
$('ol.entries li.file.status-modified span.name').each (i, el) ->
  filePath = []
  # ...grab its name...
  filePath.unshift($(el).text())

  # ... then find its parent directories, and grab their names
  parents = $(el).parents('.directory.status-modified')
  parents.each (i, el) ->
    filePath.unshift($(el).find('div.header span.name').eq(0).text())

  modifiedFilePath = path.join(project.rootDirectory.path, filePath.join(path.sep))
  modifiedFiles.push modifiedFilePath
```

`modifiedFiles` is an array containing a list of our modified files. We're also
using the node.js [`path` library][path] to get the proper directory separator
for our system.

Remove the two `@li` elements we added in `@content`, so that we can
populate our `modifiedFilesList` with real information. We'll do that by
iterating over `modifiedFiles`, accessing a file's last modified time, and
appending it to `modifiedFilesList`:

```coffeescript
# toggles the pane
if @hasParent()
  rootView.vertical.children().last().remove()
else
  for file in modifiedFiles
    stat = fs.lstatSync(file)
    mtime = stat.mtime
    @modifiedFilesList.append("<li>#{file} - Modified at #{mtime}")
  rootView.vertical.append(this)
```

When you toggle the modified files list, your pane is now populated with the
filenames and modified times of files in your project:

![Changer Panel][changer-panel-timestamps]

You might notice that subsequent calls to this command reduplicate information.
We could provide an elegant way of rechecking files already in the list, but for
this demonstration, we'll just clear the `modifiedFilesList` each time it's closed:

```coffeescript
# toggles the pane
if @hasParent()
  @modifiedFilesList.empty() # added this to clear the list on close
  rootView.vertical.children().last().remove()
else
  for file in modifiedFiles
    stat = fs.lstatSync(file)
    mtime = stat.mtime
    @modifiedFilesList.append("<li>#{file} - Modified at #{mtime}")
  rootView.vertical.append(this)
```

## Coloring UI Elements

For packages that create new UI elements, adhering to the style guide is just one
part to keeping visual consistency. Packages dealing with color, fonts, padding,
margins, and other visual cues should rely on [Theme Variables][theme-vars], instead
of developing individual styles. Theme variables are variables defined by Atom
for use in packages and themes. They're only available in [`LESS`](http://lesscss.org/)
stylesheets.

For our package, let's remove the style defined by `ul.modified-files-list` in
_changer.css_. Create a new file under the _stylesheets_ directory called _text-colors.less_.
Here, we'll import the _ui-variables.less_ file, and define some Atom-specific
styles:

```less
@import "ui-variables";

ul.modified-files-list {
  color: @text-color;
  background-color: @background-color-info;
}
```

Using theme variables ensures that packages look great alongside any theme.

[bundled-libs]: ../creating-a-package.html#included-libraries
[styleguide]: https://github.com/atom/styleguide
[space-pen]: https://github.com/atom/space-pen
[node]: http://nodejs.org/
[path]: http://nodejs.org/docs/latest/api/path.html
[theme-vars]: ../theme-variables.html
[changer-file-view]: https://f.cloud.github.com/assets/69169/1441187/d7a7cb46-41a7-11e3-8128-d93f70a5d5c1.png
[changer-panel-append]: https://f.cloud.github.com/assets/69169/1441189/db0c74da-41a7-11e3-8286-b82dd9190c34.png
[changer-panel-timestamps]: https://f.cloud.github.com/assets/69169/1441190/dcc8eeb6-41a7-11e3-830f-1f1b33072fcd.png
