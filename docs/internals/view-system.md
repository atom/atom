## Atom's View System

### SpacePen Basics

Atom's view system is built around the [SpacePen](http://github.com/nathansobo/space-pen)
view framework. SpacePen view objects inherit from the jQuery prototype, and
wrap DOM nodes

View objects are actually jQuery wrappers around DOM fragments, supporting all
the typical jQuery traversal and manipulation methods. In addition, view objects
have methods that are view-specific. For example, you could call both general
and view-specific on the global `rootView` instance:

```coffeescript
rootView.find('.editor.active') # standard jQuery method
rootView.getActiveEditor()      # view-specific method
```

If you retrieve a jQuery wrapper for an element associated with a view, use the
`.view()` method to retrieve the element's view object:

```coffeescript
# this is a plain jQuery object; you can't call view-specific methods
editorElement = rootView.find('.editor.active')

# get the view object by calling `.view()` to call view-specific methods
editorView = editorElement.view()
editorView.setCursorBufferPosition([1, 2])
```

Refer to the [SpacePen](http://github.com/nathansobo/space-pen) documentation
for more details.

### RootView

The root of Atom's view hierarchy is a global called `rootView`, which is a
singleton instance of the `RootView` view class. The root view fills the entire
window, and contains every other view. If you open Atom's inspector with
`alt-cmd-i`, you can see the internal structure of `RootView`:

![RootView in the inspector](http://f.cl.ly/items/2n0s3m0I2d223p3s3W01/root-view-inspector.png)

#### Panes

The `RootView` contains a `#horizontal` and a `#vertical` axis surrounding
`#panes`. Elements in the horizontal axis will tile across the window
horizontally, appearing to have a vertical orientation. Items in the vertical
axis will tile across the window vertically, appearing to have a horizontal
orientation. You would typically attach tool panels to the root view's primary
axes. Tool panels are elements which take up some screen real estate that isn't
devoted to direct editing. In the example above, the `TreeView` is present in
the `#horizontal` axis to the left of the `#panes`, and the `CommandPanel` is
present in the `#vertical` axis below the `#panes`.

You can attach a tool panel to an axis using the `horizontal` or `vertical`
outlets as follows:

```coffeescript
# place a view to the left of the panes (or use .append() to place it to the right)
rootView.horizontal.prepend(new MyView)

# place a view below the panes (or use .prepend() to place it above)
rootView.vertical.append(new MyOtherView)
```
