## Configuration API

### Reading Config Settings

If you are writing a package that you want to make configurable, you'll need to
read config settings via the `atom.config` global. You can read the current
value of a namespaced config key with `atom.config.get`:

```coffeescript
# read a value with `config.get`
@showInvisibles() if atom.config.get "editor.showInvisibles"
```

Or you can subscribe via `atom.config.observe` to track changes from any view
object.

```coffeescript
{View} = require 'space-pen'

class MyView extends View
  attached: ->
    @fontSizeObserveSubscription =
      atom.config.observe 'editor.fontSize', (newValue, {previous}) =>
        @adjustFontSize()

  detached: ->
    @fontSizeObserveSubscription.dispose()
```

The `atom.config.observe` method will call the given callback immediately with
the current value for the specified key path, and it will also call it in the
future whenever the value of that key path changes. If you only want to invoke
the callback when the next time the value changes, use `atom.config.onDidChange`
instead.

Subscription methods return *disposable* subscription objects. Note in the
example above how we save the subscription to the `@fontSizeObserveSubscription`
instance variable and dispose of it when the view is detached. To group multiple
subscriptions together, you can add them all to a
[`CompositeDisposable`][composite-disposable] that you dispose when the view is
detached.

### Writing Config Settings

The `atom.config` database is populated on startup from `~/.atom/config.cson`,
but you can programmatically write to it with `atom.config.set`:

```coffeescript
# basic key update
atom.config.set("core.showInvisibles", true)
```

If you're exposing package configuration via specific key paths, you'll want to
associate them with a schema in your package's main module. Read more about
schemas in the [config API docs][config-api].

[composite-disposable]: https://atom.io/docs/api/latest/CompositeDisposable
[config-api]: https://atom.io/docs/api/latest/Config
