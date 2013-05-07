# Creating Packages

Let's take a look at creating our first package.

Atom has a command you can enter that'll create a package for you:
`package-generator:generate`. Otherwise, you can hit `meta-p`, and start typing
"Package Generator." Once you activate this package, it'll ask you for a name for
your new package. Let's call ours _changer_.

Now, _changer_ is going to have a default set of folders and files created for us.
Hit `meta-R` to reload Atom, then hit `meta-p` and start typing "Changer." You'll
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

```cson
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
some of the bundled libraries Atom provides by default](./included_libraries.md).

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

You can access the dev console by hitting `alt-meta-i`. When we execute the
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
    @ul class: 'modified-files', outlet: 'modifiedFiles', =>
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
the element as we're doing here, it'll just set a CSS property to control yoru package's
visibility.
