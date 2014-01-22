## Serialization in Atom

When a window is refreshed or restored from a previous session, the view and its
associated objects are *deserialized* from a JSON representation that was stored
during the window's previous shutdown. For your own views and objects to be
compatible with refreshing, you'll need to make them play nicely with the
serializing and deserializing.

### Package Serialization Hook

Your package's main module can optionally include a `serialize` method, which
will be called before your package is deactivated. You should return JSON, which
will be handed back to you as an argument to `activate` next time it is called.
In the following example, the package keeps an instance of `MyObject` in the
same state across refreshes.

```coffee-script
module.exports =
  activate: (state) ->
    @myObject =
      if state
        deserialize(state)
      else
        new MyObject("Hello")

  serialize: ->
    @myObject.serialize()
```

### Serialization Methods

```coffee-script
class MyObject
  registerDeserializer(this)
  @deserialize: ({data}) -> new MyObject(data)
  constructor: (@data) ->
  serialize: -> { deserializer: 'MyObject', data: @data }
```

#### .serialize()
Objects that you want to serialize should implement `.serialize()`. This method
should return a serializable object, and it must contain a key named
`deserializer` whose value is the name of a registered deserializer that can
convert the rest of the data to an object. It's usually just the name of the
class itself.

#### @deserialize(data)
The other side of the coin is the `deserialize` method, which is usually a
class-level method on the same class that implements `serialize`. This method's
job is to convert a state object returned from a previous call `serialize` back
into a genuine object.

#### registerDeserializer(klass)
You need to call the global `registerDeserializer` method with your class in
order to make it available to the deserialization system. Now you can call the
global `deserialize` method with state returned from `serialize`, and your
class's `deserialize` method will be selected automatically.

### Versioning

```coffee-script
class MyObject
  @version: 2
  @deserialize: (state) -> ...
  serialize: -> { version: MyObject.version, ... }
```

Your serializable class can optionally have a class-level `@version` property
and include a `version` key in its serialized state. When deserializing, Atom
will only attempt to call deserialize if the two versions match, and otherwise
return undefined. We plan on implementing a migration system in the future, but
this at least protects you from improperly deserializing old state. If you find
yourself in dire need of the migration system, let us know.

### Deferred Package Deserializers

If your package defers loading on startup with an `activationEvents` property in
its `package.cson`, your deserializers won't be loaded until your package is
activated. If you want to deserialize an object from your package on startup,
this could be a problem.

The solution is to also supply a `deferredDeserializers` array in your
`package.cson` with the names of all your deserializers. When Atom attempts to
deserialize some state whose `deserializer` matches one of these names, it will
load your package first so it can register any necessary deserializers before
proceeding.

For example, the markdown preview package doesn't fully load until a preview is
triggered. But if you refresh a window with a preview pane, it loads the
markdown package early so Atom can deserialize the view correctly.

```coffee-script
# markdown-preview/package.cson
'activationEvents': 'markdown-preview:toggle': '.editor'
'deferredDeserializers': ['MarkdownPreviewView']
...
```
