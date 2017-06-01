# API Guidelines

__Note__: These are not all in practice yet. We are still sorting this out, and plan to move the entire API this way.

## General Guidelines

We should strive to have only one way to do something, and make it clear what that way is.

__Bad__
* Several ways to get the `Editor` model from the view.
  * `EditorView.editor`
  * `EditorView.getModel()`
  * `EditorView.getEditor()`
* Delegated methods on the views when there is a model counterpart
  * `Editor.toggleSoftTabs()`
  * `EditorView.toggleSoftTabs()`

__Good__
* One way to get the `Editor` model from the view
  * `EditorView.getModel()`
* Use the method on the model
  * `Editor.toggleSoftTabs()`
* One clear way to subscribe to events
  * `subscription = @subscribe thing, 'event', -> ...`
* One clear way to unsubscribe to events
  * `subscription.off()` only; not `thing.off 'event', -> ...`

## Essential vs Extended

There are two groups of classes / methods. We break them up to facilitate a gentle introduction into the API and help authors build a knowledge foundation more quickly.

### Essential

These are classes, methods, and concepts nearly every package author will need to know about. Need to create commands? Subscribe to atom events? Get a reference to all the editors? Highlight a line in the editor? Patterns and methods for these things will be explained in the essential API.

We want to keep the essential API minimal and focused.

### Extended

The extended API contains The Power. Need to move one cursor independent of the others? Want to do some processing on the markers? You can do it with the extended API.

## View / Model

Operations on Views should be limited to DOM manipulation only. A package author should only need access to, say, the `EditorView` when it needs to directly modify the `EditorView`'s DOM.

## Properties

No public properties. Use methods instead.

## Methods

### Naming

We strive to fit the [Objective C][naming] naming conventions for the sake of readability.

* Be descriptive, always write out the whole word. `selection` not `sel`, `cursor` not `cur`.
* Describe the arguments names in the method name eg. `decorationsForMarker(marker)`, `objectAtIndex(index)`
* Use `get` prefix only when there are no arguments `getCursors()`, `getLastCursor()`, `cursorForMarker(marker)`
* Prefix bool methods with `is` eg. `isDefault()`

Array accessor methods would be written as follows

```coffee
getObjects()
addObject(object)
removeObject(object)
removeObjectAtIndex(index)
objectAtIndex(index)
objectsForThing(thing)
objectForThing(thing)
```

## Events

There will be no `off()` method on objects. `on()` will return a subscription object which contains the `off()` method.

* Events should be emitted with one event object as an argument, rather than a bunch of arguments.
* If an event is cancelable, it will provide a `cancel` function in the event object.

### Naming

Past tense. ???

## Documentation

Comment doc strings on methods, events, etc

* how to doc sections?
* events?
* props?
* callback args?
* option hashes?

### Method organization

* All methods in classes should be grouped into sections by usage pattern.
* Methods within a section should be ordered with the most commonly used methods at the top. `Essential` methods always go above `Extended` methods.
* Sections should be ordered in the class with the most commonly used sections at the top.

A section:

```coffee
###
Section: Reading Text
###

# Essential: Returns a {String} representing the entire contents of the editor.
getText: -> @buffer.getText()
```


[naming]:https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CodingGuidelines/Articles/NamingMethods.html
