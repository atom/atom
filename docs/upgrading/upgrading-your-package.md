# Upgrading your package to 1.0 APIs

Atom is rapidly approaching 1.0. Much of the effort leading up to the 1.0 has been cleaning up APIs in an attempt to future proof, and make a more pleasant experience developing packages.

This document will guide you through the large bits of upgrading your package to work with 1.0 APIs.

## TL;DR

We've set deprecation messages and errors in strategic places to help make sure you dont miss anything. You should be able to get 95% of the way to an updated package just by fixing errors and deprecations. There are a couple of things you need to do to enable all these errors and deprecations.

### Use atom-space-pen-views

Add the `atom-space-pen-views` module to your package's `package.json` file's dependencies:

```js
{
  "dependencies": {
    "atom-space-pen-views": "^0.21"
  }
}
```

Then run `apm install` in your package directory.

### Require views from atom-space-pen-views

Anywhere you are requiring one of the following from `atom` you need to require them from `atom-space-pen-views` instead.

```js
// require these from 'atom-space-pen-views' rather than 'atom'
$
$$
$$$
View
TextEditorView
ScrollView
SelectListView
```

So this:

```coffee
# Old way
{$, TextEditorView, View, GitRepository} = require 'atom'
```

Would be replaced with this:

```coffee
# New way
{GitRepository} = require 'atom'
{$, TextEditorView, View} = require 'atom-space-pen-views'
```

### Run specs and test your package

You wrote specs, right!? Here's where they shine. Run them with `cmd-shift-P`, and search for `run package specs`. It will show all the deprecation messages and errors.

### Examples

We have upgraded all the core packages. Please see [this issue](https://github.com/atom/atom/issues/4011) for a link to all the upgrade PRs.

## Deprecations

All of the methods in core that have changes will emit deprecation messages when called. These messages are shown in two places: your **package specs**, and in **Deprecation Cop**.

### Specs

Just run your specs, and all the deprecations will be displayed in yellow.

TODO: image of deprecations in specs

TODO: Comand line spec deprecation image?

### Deprecation Cop

Run an atom window in dev mode (`atom -d`) with your package loaded, and open Deprecation Cop (search for `deprecation` in the command palette).

TODO: image of deprecations in DepCop

## View Changes

Previous to 1.0, views in packages were baked into Atom core. These views were based on jQuery and `space-pen`. They looked something like this:

```coffee
# The old way: getting views from atom
{$, TextEditorView, View} = require 'atom'

module.exports =
class SomeView extends View
  @content: ->
    @div class: 'find-and-replace', =>
      @div class: 'block', =>
        @subview 'myEditor', new TextEditorView(mini: true)
  #...
```

Requiring `atom` _used to_ provide the following view helpers:

```
$
$$
$$$
View
TextEditorView
ScrollView
SelectListView
```

### The New

Atom no longer provides these view helpers baked in. Atom core is now 'view agnostic'. The preexisting view system is available from two npm packages: `space-pen`, and `atom-space-pen-views`

`space-pen` now provides

```
$
$$
$$$
View
```

`atom-space-pen-views` now provides all of `space-pen`, plus Atom specific views:

```js
// Passed through from space-pen
$
$$
$$$
View

// Atom specific views
TextEditorView
ScrollView
SelectListView
```

### Adding the module dependencies

To use the new views, you need to specify the `atom-space-pen-views` module in your package's `package.json` file's dependencies:

```js
{
  "dependencies": {
    "atom-space-pen-views": "^0.21"
  }
}
```

`space-pen` bundles jQuery. If you do not need `space-pen` or any of the views, you can require jQuery directly.

```js
{
  "dependencies": {
    "jquery": "^2"
  }
}
```

### Converting your views

Sometimes it is as simple as converting the requires at the top of each view page. I assume you read the 'TL;DR' section and have updated all of your requires.

### Upgrading classes extending any space-pen View

The `afterAttach` and `beforeRemove` hooks have been replaced with
`attached` and `detached` and their semantics have been altered. `attached` will only be called when all parents of the View are attached to the DOM.

```coffee
# Old way
{View} = require 'atom'
class MyView extends View
  afterAttach: (onDom) ->
    #...

  beforeRemove: ->
    #...
```

```coffee
# New way
{View} = require 'atom-space-pen-views'
class MyView extends View
  attached: ->
    # Always called with the equivalent of @afterAttach(true)!
    #...

  removed: ->
    #...
```

### Upgrading to the new TextEditorView

You should not need to change anything to use the new `TextEditorView`! See the [docs][TextEditorView] for more info.

### Upgrading to classes extending ScrollView

The `ScrollView` has very minor changes.

You can no longer use `@off` to remove default behavior for `core:move-up`, `core:move-down`, etc.

```coffee
# Old way to turn off default behavior
class ResultsView extends ScrollView
  initialize: (@model) ->
    super
    # turn off default scrolling behavior from ScrollView
    @off 'core:move-up'
    @off 'core:move-down'
    @off 'core:move-left'
    @off 'core:move-right'
```

```coffee
# New way to turn off default behavior
class ResultsView extends ScrollView
  initialize: (@model) ->
    disposable = super()
    # turn off default scrolling behavior from ScrollView
    disposable.dispose()
```

* Check out [an example](https://github.com/atom/find-and-replace/pull/311/files#diff-9) from find-and-replace.
* See the [docs][ScrollView] for all the options.

### Upgrading to classes extending SelectListView

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

* And check out the [conversion of CommandPaletteView][selectlistview-example] as a real-world example.
* See the [SelectListView docs][SelectListView] for all options.

## Updating Specs

`WorkspaceView` and `EditorView` have been deprecated. These two objects are used heavily throughout specs, mostly to dispatch events and commands. This section will explain how to remove them while still retaining the ability to dispatch events and commands.

### Removing WorkspaceView references

`WorkspaceView` has been deprecated. Everything you could do on the view, you can now do on the `Workspace` model.

Requiring `WorkspaceView` from `atom` and accessing any methods on it will throw a deprecation warning. Many specs lean heavily on `WorkspaceView` to trigger commands and fetch `EditorView` objects.

Your specs might contain something like this:

```coffee
# Old!
{WorkspaceView} = require 'atom'
describe 'FindView', ->
  beforeEach ->
    atom.workspaceView = new WorkspaceView()
```

Instead, we will use the `atom.views.getView()` method. This will return a plain `HTMLElement`, not a `WorkspaceView` or jQuery object.

```coffee
# New!
describe 'FindView', ->
  workspaceElement = null
  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)
```

### Attaching the workspace to the DOM

The workspace needs to be attached to the DOM in some cases. For example, view hooks only work (`attached()` on `View`, `attachedCallback()` on custom elements) when there is a descendant attached to the DOM.

You might see this in your specs:

```coffee
# Old!
atom.workspaceView.attachToDom()
```

Change it to:

```coffee
# New!
jasmine.attachToDOM(workspaceElement)
```

### Removing EditorView references

Like `WorkspaceView`, `EditorView` has been deprecated. Everything you needed to do on the view you are now able to do on the `Editor` model.

In many cases, you will not even need to get the editor's view anymore. Any of those instances should be updated to use the `Editor` instance. You should really only need the editor's view when you plan on triggering a command on the view in a spec.

Your specs might contain something like this:

```coffee
# Old!
describe 'Something', ->
  [editorView] = []
  beforeEach ->
    editorView = atom.workspaceView.getActiveView()
```

We're going to use `atom.views.getView()` again to get the editor element. As in the case of the `workspaceElement`, `getView` will return a plain `HTMLElement` rather than an `EditorView` or jQuery object.

```coffee
# New!
describe 'Something', ->
  [editor, editorElement] = []
  beforeEach ->
    editor = atom.workspace.getActiveTextEditor()
    editorElement = atom.views.getView(editor)
```

### Dispatching commands

Since the `editorView` objects are no longer `jQuery` objects, they no longer support `trigger()`. Additionally, Atom has a new command dispatcher, `atom.commands`, that we use rather than commandeering jQuery's `trigger` method.

From this:

```coffee
# Old!
workspaceView.trigger 'a-package:toggle'
editorView.trigger 'find-and-replace:show'
```

To this:

```coffee
# New!
atom.commands.dispatch workspaceElement, 'a-package:toggle'
atom.commands.dispatch editorElement, 'find-and-replace:show'
```


[texteditorview]:https://github.com/atom/atom-space-pen-views#texteditorview
[scrollview]:https://github.com/atom/atom-space-pen-views#scrollview
[selectlistview]:https://github.com/atom/atom-space-pen-views#selectlistview
[selectlistview-example]:https://github.com/atom/command-palette/pull/19/files
