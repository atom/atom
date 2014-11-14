# Upgrading your package to 1.0 APIs

Atom is rapidly approaching 1.0. Much of the effort leading up to the 1.0 has been cleaning up APIs in an attempt to future proof, and make a more pleasant experience developing packages.

This document will guide you through the large bits of upgrading your package to work with 1.0 APIs.

## Deprecations

All of the methods that have changes emit deprecation messages when called. These messages are shown in two places: your package specs, and in Deprecation Cop.

### Specs

Just run your specs, and all the deprecations will be displayed in yellow.

TODO: image of deprecations in specs

### Deprecation Cop

Run an atom window in dev mode (`atom -d`) with your package loaded, and open Deprecation Cop (search for `deprecation` in the command palette).

TODO: image of deprecations in DepCop

## Views

Previous to 1.0, views in packages were baked into Atom core. These views were based on jQuery and `space-pen`. They looked something like this:

```coffee
{$, TextEditorView, View} = require 'atom'

module.exports =
class SomeView extends View
  @content: ->
    @div class: 'find-and-replace', =>
      @div class: 'block', =>
        @subview 'myEditor', new TextEditorView(mini: true)
  #...
```

Requiring `atom` used to provide the following view helpers:

```
$
$$
$$$
View
TextEditorView
ScrollView
SelectListView
Workspace
WorkspaceView
```

### The New

Atom no longer provides these view helpers baked in. They are now available from two npm packages: `space-pen`, and `atom-space-pen-views`

`space-pen` now provides

```
$
$$
$$$
View
```

`atom-space-pen-views` now provides

```
TextEditorView
ScrollView
SelectListView
```

`Workspace` and `WorkspaceView` are _no longer provided_ in any capacity. They should be unnecessary

### Adding the module dependencies

To use the new views, you need to specify a couple modules in your package dependencies in your `package.json` file:

```js
{
  "dependencies": {
    "space-pen": "^3"
    "atom-space-pen-views": "^0"
  }
}
```

`space-pen` bundles jQuery. If you do not need `space-pen`, you can require jQuery directly.

```js
{
  "dependencies": {
    "jquery": "^2"
  }
}
```

### Converting your views

Sometimes it is as simple as converting the requires at the top of each view page. In the case of our above example, you can just convert them to the following:

```coffee
{$, View} = require 'space-pen'
{TextEditorView} = require 'atom-space-pen-views'
```

If you are using the lifecycle hooks, you will need to update code as well.

### Upgrading to space-pen's TextEditorView

You should not need to change anything to use the new `TextEditorView`! See the [docs][TextEditorView] for more info.

### Upgrading to space-pen's ScrollView

See the [docs][ScrollView] for all the options.

### Upgrading to space-pen's SelectListView

Your SelectListView might look something like this:

```coffee
class CommandPaletteView extends SelectListView
  initialize: ->
    super
    @addClass('command-palette overlay from-top')
    atom.workspaceView.command 'command-palette:toggle', => @toggle()

  confirmed: ({name, jQuery}) ->
    @cancel()
    # do something with the result

  toggle: ->
    if @hasParent()
      @cancel()
    else
      @attach()

  attach: ->
    @storeFocusedElement()

    items = # build items
    @setItems(items)

    atom.workspaceView.append(this)
    @focusFilterEditor()

  confirmed: ({name, jQuery}) ->
    @cancel()
```

This attaches and detaches itself from the dom when toggled, canceling magically detaches it from the DOM, and it uses the classes `overlay` and `from-top`.

Using the new APIs it should look like this:

```coffee
class CommandPaletteView extends SelectListView
  initialize: ->
    super
    # no more need for the `overlay` and `from-top` classes
    @addClass('command-palette')
    atom.workspaceView.command 'command-palette:toggle', => @toggle()

  # You need to implement the `cancelled` method and hide.
  cancelled: ->
    @hide()

  confirmed: ({name, jQuery}) ->
    @cancel()
    # do something with the result

  toggle: ->
    # Toggling now checks panel visibility,
    # and hides / shows rather than attaching to / detaching from the DOM.
    if @panel?.isVisible()
      @cancel()
    else
      @show()

  show: ->
    # Now you will add your select list as a modal panel to the workspace
    @panel ?= atom.workspace.addModalPanel(item: this)
    @panel.show()

    @storeFocusedElement()

    items = # build items
    @setItems(items)

    @focusFilterEditor()

  hide: ->
    @panel?.hide()
```

See the [SelectListView docs][SelectListView] for all the options.

## Specs

TODO: come up with patterns for converting away from using `workspaceView` and `editorView`s everywhere.


[texteditorview]:https://github.com/atom/atom-space-pen-views#texteditorview
[scrollview]:https://github.com/atom/atom-space-pen-views#scrollview
[selectlistview]:https://github.com/atom/atom-space-pen-views#selectlistview
