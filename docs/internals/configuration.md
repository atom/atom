## Configuration API

### Reading Config Settings

If you are writing a package that you want to make configurable, you'll need to
read config settings. You can read a value from `config` with `config.get`:

```coffeescript
# read a value with `config.get`
@showInvisibles() if config.get "edtior.showInvisibles"
```

Or you can use `observeConfig` to track changes from a view object.

```coffeescript
class MyView extends View
  initialize: ->
    @observeConfig 'editor.fontSize', () =>
      @adjustFontSize()
```

The `observeConfig` method will call the given callback immediately with the
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
ConfigObserver = require 'config-observer'
_.extend MyClass.prototype, ConfigObserver
```

### Writing Config Settings

As discussed above, the config database is automatically populated from
`config.cson` when Atom is started, but you can programmatically write to it in
the following way:

```coffeescript
# basic key update
config.set("core.showInvisibles", true)

config.pushAtKeyPath("core.disabledPackages", "wrap-guide")
```

You can also use `setDefaults`, which will assign default values for keys that
are always overridden by values assigned with `set`. Defaults are not written out
to the the `config.json` file to prevent it from becoming cluttered.

```coffeescript
config.setDefaults("editor", fontSize: 18, showInvisibles: true)
```
