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

### The Old

Previous to 1.0, views in packages were baked into Atom core. These views were based on jQuery and `space-pen`. They look something like this:

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

#### jQuery

If you do not need `space-pen`, you can require jQuery directly. In your `package.json` add this to the `dependencies` object:

```js
"jquery": "^2"
```

#### NPM dependencies

```js
{
  "dependencies": {
    "jquery": "^2" // if you want to include jquery directly
    "space-pen": "^3"
    "atom-space-pen-views": "^0"
  }
}
```

#### Converting your views

Sometimes it should be as simple as converting the requires at the top of each view page. In the case of our above example, you can just convert them to the following:

```coffee
{$, View} = require 'space-pen'
{TextEditorView} = require 'atom-space-pen-views'
```

## Specs

TODO: come up with patterns for
