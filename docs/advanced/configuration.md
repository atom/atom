## Configuration API

### Reading Config Settings

If you are writing a package that you want to make configurable, you'll need to
read config settings via the `atom.config` global. You can read the current
value of a namespaced config key with `atom.config.get`:

```coffeescript
# read a value with `config.get`
@showInvisibles() if atom.config.get "editor.showInvisibles"
```

Or you can use the `::observeConfig` to track changes from any view object.

```coffeescript
class MyView extends View
  initialize: ->
    @observeConfig 'editor.fontSize', () =>
      @adjustFontSize()
```

The `::observeConfig` method will call the given callback immediately with the
current value for the specified key path, and it will also call it in the future
whenever the value of that key path changes.

Subscriptions made with `observeConfig` are automatically canceled when the
view is removed. You can cancel config subscriptions manually via the
`unobserveConfig` method.

```coffeescript
view1.unobserveConfig() # unobserve all properties
```

You can add the ability to observe config values to non-view classes by
extending their prototype with the `ConfigObserver` mixin:

```coffeescript
{ConfigObserver} = require 'atom'

class MyClass
  ConfigObserver.includeInto(this)
  
  constructor: ->
    @observeConfig 'editor.showInvisibles', -> # ...

  destroy: ->
    @unobserveConfig()
```

### Writing Config Settings

The `atom.config` database is populated on startup from <tt>[AtomConfDir](../user-dirs.md)/config.cson</tt>,
but you can programmatically write to it with `atom.config.set`:

```coffeescript
# basic key update
atom.config.set("core.showInvisibles", true)
```

You should never mutate the value of a config key, because that would circumvent
the notification of observers. You can however use methods like `pushAtKeyPath`,
`unshiftAtKeyPath`, and `removeAtKeyPath` to manipulate mutable config values.

```coffeescript
atom.config.pushAtKeyPath("core.disabledPackages", "wrap-guide")
atom.config.removeAtKeyPath("core.disabledPackages", "terminal")
```

You can also use `setDefaults`, which will assign default values for keys that
are always overridden by values assigned with `set`. Defaults are not written
out to the the `config.json` file to prevent it from becoming cluttered.

```coffeescript
atom.config.setDefaults("editor", fontSize: 18, showInvisibles: true)
```
