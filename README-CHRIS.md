![](https://img.skitch.com/20110828-e6a2sk5mqewpfnxb3eeuef112d.png)

# Futuristic Text Editing

Atomicity is a highly extensible OS X text editor. It is written in CoffeeScript, HTML, and CSS utilizing the power of JSCocoa and the elegance of Ajax.org's Ace editor.

## Atomicity Startup

When Atomicity starts, AtomApp (the application delegate) immediately loads require.coffee and app.coffee using JSCocoa.

app.coffee exports the following two functions:

- `startup: ->`

Called right away in a global JSCocoa context for the app. Different than a browser environment - there is no `window` global, no `document`, etc. Just Atomicity's standard library: require, underscore, etc.

In here we setup the app's menu structure using the AtomMenu class, bind basic app-wide keyboard events with the Keybinder, load our core UI files, load extensions using the ExtensionManager module, and load your `~/.atomicity` module.

Loading core UI files and extensions is important because it gives those modules a chance to register for app events.

After all that's done we check `localStorage` for saved AtomWindow bounds & URLs and recreate them if they exist. If they don't exist we create a fresh AtomWindow. At this point we're done starting up.

- `shutdown: ->`

Called before shutting down. The app doesn't finish quitting until this function returns.

Here is where we save the window positions in localStorage and do any other global cleanup, which is probably nothing.

## Events

Atomicity has a jQuery/Backbone-style event system using the `on` and `off` functions of the `AtomEvent` module. Events should be in the format of: `namespace:event`, for example `window:load` for onLoad or `plugin:install` for when a plugin is installed.

```coffee
AtomEvent.on 'window:load', (window) ->
  myCode()
```

Individual events can be uninstalled using `off`:

```coffee
AtomEvent.off 'window:load'
```

As well as entire namespaces:

```coffee
AtomEvent.off 'window:'
```

## AtomWindow Creation

Every AtomWindow represents a URL. If we don't pass in a URL when creating an AtomWindow, it'll set its URL to something random in /tmp.

When we instantiate an AtomWindow it creates a WebView and sets itself as the delegate then loads `index.html`. When the WebView finishes loading the AtomWindow fires a `window:load` event, passing itself as the sole argument.

Extensions will probably listen for the `window:load` event, as will core Atomicity UI code.

## Atomicity UI Code

Atomicity has a few classes in addition to AtomWindow strictly for UI. Each UI class is a "View" while the HTML it represents is a "Template".

- View

Generic class that represents a chunk of HTML, or template. Like Backbone it has a `el` property (a string selector) and a `render` method, which inserts the template into the DOM. Also has a `remove` method.

- Pane

Special view. Has a position.

- Modal

Facebox.

## Extensions

Extensions are directories with a package.json file based on npm's: https://github.com/isaacs/npm/blob/master/doc/cli/json.md

`name`, `version`, `description`, `homepage`, and `author` are probably the only ones that matter most right now.

Extensions also have an index.coffee (or `main` in the package.json) file that exports the following functions:

- `install: ->`

Called the very first time your extension is loaded, before `startup`.

- `uninstall: ->`

Called when your extension is being uninstalled. This is where you should delete any saved data.

- `startup: ->`

Called when the extension is first loaded during the app's startup or an in-process loading of the extension.

Here you'd hand Keybinder a keymap for your extension, add items to AtomMenu, add items to AtomContextMenu, and attach a callback to `window:load` that creates & renders AtomViews if necessary.

- `shutdown: ->`

Called when the app shuts down or your extension is disabled. Different than `window:close`. Make sure to clean up after yourself here by using `AtomEvent.off` and whatever else.

## ExtensionManager

The ExtensionManager module loads, installs, uninstalls, and keeps track of extensions. All extensions are global to the whole app, and enabled/disabled on an app-wide basis.

It fires the following events on AtomEvent, passing the Extension module to each:

- `extension:install`
- `extension:uninstall`
- `extension:startup`
- `extension:shutdown`

## Keybinder

Module with a single public function:

- `bind: (scope, map) ->`

`scope` should be one of:

- `'app'`
- `'window'`
- A Pane object

While `map` should be a key/value object in this format: `shortcut: callback`.

- `shortcut` should be a string like `cmd+w` or `ctrl+shift+o`
- `callback` should be a function

For example:

```coffee
Keybinder.bind 'app',
  'cmd+o': openFile
  'cmd+s': saveFile

# Called inside a View
Keybinder.bind this,
  'cmd+shift+r': => @reload()
  'cmd+shift+o': => @openURL()
```

Needs more thought.

## AtomMenu

Used by core app classes and extensions to add menu items to the app. Needs more thought.
