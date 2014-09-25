## Configuration API

### Reading Config Settings

If you are writing a package that you want to make configurable, you'll need to
read config settings via the `atom.config` global. You can read the current
value of a namespaced config key with `atom.config.get`:

```coffeescript
# read a value with `config.get`
@showInvisibles() if atom.config.get "editor.showInvisibles"
```

Or you can use the `::subscribe` with `atom.config.observe` to track changes
from any view object.

```coffeescript
class MyView extends View
  initialize: ->
    @subscribe atom.config.observe 'editor.fontSize', (newValue, {previous}) =>
      @adjustFontSize()
```

The `atom.config.observe` method will call the given callback immediately with
the current value for the specified key path, and it will also call it in the
future whenever the value of that key path changes.

Subscriptions made with `::subscribe` are automatically canceled when the
view is removed. You can cancel config subscriptions manually via the
`off` method on the subscription object that `atom.config.observe` returns.

```coffeescript
fontSizeSubscription = atom.config.observe 'editor.fontSize', (newValue, {previous}) =>
  @adjustFontSize()

# ... later on

fontSizeSubscription.off() # Stop observing
```

### Writing Config Settings

The `atom.config` database is populated on startup from `~/.atom/config.cson`,
but you can programmatically write to it with `atom.config.set`:

```coffeescript
# basic key update
atom.config.set("core.showInvisibles", true)
```

You can also use `setDefaults`, which will assign default values for keys that
are always overridden by values assigned with `set`. Defaults are not written
out to the the `config.json` file to prevent it from becoming cluttered.

```coffeescript
atom.config.setDefaults("editor", fontSize: 18, showInvisibles: true)
```
