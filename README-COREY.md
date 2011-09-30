## Dogma

- Objective-C classes start with **RF** and JS classes start with **Atom** for disambiguation. *NOTE:* I'm not a huge fan of the **RF** prefix
- AtomApp **only** contains keybindings and a list of AtomWindows. Since it is in a seperate JSCocoa context, all communication must be done via AtomEvent.
- Each AtomWindow has an instance of every extensions.

## Atomicity Startup

When Atomicity starts, RFApp (the NSApplication instance and delegate) immediately loads require.coffee and `atom-app.coffee` using JSCocoa.

atom-app.coffee exports the following two functions:

- `startup: ->`

Called right away in a global JSCocoa context for the app. Different than a browser environment - there is no `window` global, no `document`, etc. Just Atomicity's standard library: require, underscore, etc.

In here we setup the app's menu structure using the AtomMenu class, bind app-wide keyboard events, and load your `~/.atomicity/index.coffee` module.

After all that's done we check `localStorage` for saved AtomWindow URLs and recreate them if they exist. If they don't exist we create a fresh RFWindow. At this point we're done starting up.

- `shutdown: ->`

Called before shutting down. The app doesn't finish quitting until this function returns.

Here is where we store AtomWindow URLS info in localStorage and close all windows. and do any other global cleanup, which is probably nothing.

## RFWindow Creation

AtomApp instantiates an RFWindow with an optional URL. RFWindow contains a WebView and sets itself as the delegate, creates a JSCocoa context and loads `index.html`. `atom-window.coffee` is required by `index.html`. An instance of AtomWindow is created with the URL and window bounds.

## AtomWindow
Every AtomWindow represents a URL. If we don't pass in a URL when creating an AtomWindow, it'll set its URL to something random in /tmp.

`atom-window.coffee` exports the following two functions:

- `startup: ->`

Loads our core UI files, extensions using the ExtensionManager module, and keybindings.

Finally fires a `window:load` event, passing itself as the sole argument. Loading core UI files and extensions first is important because it gives those modules a chance to register for app events.

- `shutdown: ->`

Makes sure files are saved and window placement is remembered.

## Events

Atomicity has a jQuery/Backbone-style event system using the `on`, `off` and `trigger` functions of the `AtomEvent` module. Events should be in the format of: `namespace:event`, for example `window:load` for onLoad or `plugin:install` for when a plugin is installed.

The only way AtomApp and AtomWindows can communicate is via Events.

```coffee
AtomEvent.on 'window:load', (window) ->
  myCode()
```

Trigger the event:

```coffee
AtomEvent.trigger 'window:load', @
```

Individual events can be uninstalled using `off`:

```coffee
AtomEvent.off 'window:load', optional-event-or-function-or-something
```

As well as entire namespaces:

```coffee
AtomEvent.off 'window:'

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

Called the very first time your extension is loaded, before AtomWindow's `startup`.

- `uninstall: ->`

Called when your extension is being uninstalled. This is where you should delete any saved data.

- `startup: ->`

Called when the extension is first loaded during the AtomWindow's startup or an in-process loading of the extension.

Here you'd hand Keybinder a keymap for your extension, add items to AtomMenu, add items to AtomContextMenu, and attach a callback to `window:load` that creates & renders AtomViews if necessary.

- `shutdown: ->`

Called when the AtomWindow closes or your extension is disabled. Make sure to clean up after yourself here by using `AtomEvent.off` and whatever else.

## ExtensionManager

The ExtensionManager module loads, installs, uninstalls, and keeps track of extensions. All extensions are local to an AtomWindow.

It fires the following events on AtomEvent, passing the Extension module to each:

- `extension:install`
- `extension:uninstall`
- `extension:startup`
- `extension:shutdown`

## Keybinder

**IDEA**: bindings are just events?

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

