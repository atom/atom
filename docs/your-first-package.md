# Create Your First Package

This tutorial will guide you though creating a simple command that replaces the
selected text with [ascii art](http://en.wikipedia.org/wiki/ASCII_art). When you
run our new command with the word "cool" selected, it will be replaced with:

```
                     ___
                    /\_ \
  ___    ___     ___\//\ \
 /'___\ / __`\  / __`\\ \ \
/\ \__//\ \L\ \/\ \L\ \\_\ \_
\ \____\ \____/\ \____//\____\
 \/____/\/___/  \/___/ \/____/
```

The final package can be viewed at
[https://github.com/atom/ascii-art](https://github.com/atom/ascii-art).

To begin, press `cmd-shift-P` to bring up the [Command
Palette](https://github.com/atom/command-palette). Type "generate package" and
select the "Package Generator: Generate Package" command. Now we need to name
the package. Try to avoid naming your package with the *atom-* prefix, for
example we are going to call this package _ascii-art_.

Atom will open a new window with the contents of our new _ascii-art_ package
displayed in the Tree View. Because this window is opened **after** the package
is created, the ASCII Art package will be loaded and available in our new
window. To verify this, toggle the Command Palette (`cmd-shift-P`) and type
"ASCII Art". You'll see a new `ASCII Art: Toggle` command. When triggered, this
command displays a default message.

Now let's edit the package files to make our ASCII Art package do something
interesting. Since this package doesn't need any UI, we can remove all
view-related code. Start by opening up _lib/ascii-art.coffee_. Remove all view
code, so the `module.exports` section looks like this:

```coffeescript
module.exports =
  activate: ->
```

## Create a Command

Now let's add a command. We recommend that you namespace your commands with the
package name followed by a `:`, so we'll call our command `ascii-art:convert`.
Register the command in _lib/ascii-art.coffee_:

```coffeescript
module.exports =
  activate: ->
    atom.commands.add 'atom-workspace', "ascii-art:convert", => @convert()

  convert: ->
    # This assumes the active pane item is an editor
    editor = atom.workspace.getActivePaneItem()
    editor.insertText('Hello, World!')
```

The `atom.commands.add` method takes a selector, command name, and a callback.
The callback executes when the command is triggered on an element matching the
selector. In this case, when the command is triggered the callback will call the
`convert` method and insert 'Hello, World!'.

## Reload the Package

Before we can trigger `ascii-art:convert`, we need to load the latest code for
our package by reloading the window. Run the command `window:reload` from the
command palette or by pressing `ctrl-alt-cmd-l`.

## Trigger the Command

Now open the command panel and search for the `ascii-art:convert` command. But
it's not there! To fix this, open _package.json_ and find the property called
`activationEvents`. Activation Events speed up load time by allowing Atom to
delay a package's activation until it's needed. So remove the existing command
and add `ascii-art:convert` to the `activationEvents` array:

```json
"activationEvents": ["ascii-art:convert"],
```

First, reload the window by running the command `window:reload`. Now when you
run the `ascii-art:convert` command it will output 'Hello, World!'

## Add a Key Binding

Now let's add a key binding to trigger the `ascii-art:convert` command. Open
_keymaps/ascii-art.cson_ and add a key binding linking `ctrl-alt-a` to the
`ascii-art:convert` command. You can delete the pre-existing key binding since
you don't need it anymore. When finished, the file will look like this:

```coffeescript
'atom-text-editor':
  'cmd-alt-a': 'ascii-art:convert'
```

Notice `atom-text-editor` on the first line. Just like CSS, keymap selectors
*scope* key bindings so they only apply to specific elements. In this case, our
binding is only active for elements matching the `atom-text-editor` selector. If
the Tree View has focus, pressing `cmd-alt-a` won't trigger the
`ascii-art:convert` command. But if the editor has focus, the
`ascii-art:convert` method *will* be triggered. More information on key bindings
can be found in the [keymaps](advanced/keymaps.html) documentation.

Now reload the window and verify that the key binding works! You can also verify
that it **doesn't** work when the Tree View is focused.

## Add the ASCII Art

Now we need to convert the selected text to ASCII art. To do this we will use
the [figlet](https://npmjs.org/package/figlet) [node](http://nodejs.org/) module
from [npm](https://npmjs.org/). Open _package.json_ and add the latest version of
figlet to the dependencies:

```json
"dependencies": {
   "figlet": "1.0.8"
}
```

After saving the file, run the command 'update-package-dependencies:update' from
the Command Palette. This will install the package's node module dependencies,
only figlet in this case. You will need to run
'update-package-dependencies:update' whenever you update the dependencies field
in your _package.json_ file.

Now require the figlet node module in _lib/ascii-art.coffee_ and instead of
inserting 'Hello, World!' convert the selected text to ASCII art.

```coffeescript
convert: ->
  # This assumes the active pane item is an editor
  editor = atom.workspace.getActivePaneItem()
  selection = editor.getLastSelection()

  figlet = require 'figlet'
  figlet selection.getText(), {font: "Larry 3D 2"}, (error, asciiArt) ->
    if error
      console.error(error)
    else
      selection.insertText("\n#{asciiArt}\n")
```

Select some text in an editor window and hit `cmd-alt-a`. :tada: You're now an
ASCII art professional!

## Further reading

* [Getting your project on GitHub guide](http://guides.github.com/overviews/desktop)

* [Writing specs](writing-specs.md) for your package

* [Creating a package guide](creating-a-package.html) for more information
  on the mechanics of packages

* [Publishing a package guide](publishing-a-package.html) for more information
  on publishing your package to [atom.io](https://atom.io)
