# Create Your First Package

The tutorial will lead you though creating a simple package that replaces
selected text with ascii art. For example, if "cool" was selected the output
would be:

```
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
the package, let's call ours _ascii-art_.

Atom will open a new window with the _ascii-art_ package contents displayed in
the Tree View. Because the window was opened **after** the Ascii Art package was
created, the Ascii Art package will be loaded. To verify this toggle the Command
Palette (`cmd-shift-P`) and type "Ascii Art" you'll see a new `Ascii Art:
Toggle` command. If triggered, this command displays a default message.

Now let's edit the package files to make our ascii art package work! Since this
package doesn't need any UI we can remove all view related code. Start by
opening up _lib/ascii-art.coffee_. Remove all view code until the file looks
like this:

```coffeescript
  module.exports =
    activate: ->
```

## Create A Command

Now let's add a command. It's recommended to start your commands with the
package name followed by a colon (`:`). We'll call this command
`ascii-art:convert`. Register the command in _lib/ascii-art.coffee_:

```coffeescript
module.exports =
  activate: ->
    atom.workspaceView.command "ascii-art:convert", => @convert()

  convert: ->
    # This assumes the active pane item is an editor
    editor = atom.workspace.activePaneItem
    selection = editor.getSelection()
    upperCaseSelectedText = selection.getText().toUpperCase()
    selection.insertText(upperCaseSelectedText)
```

The `atom.workspaceView.command` method takes a command name and a callback. The
callback executes when the command is triggered. In this case, when the command
is triggered the callback will call the `convert` method and uppercase the
selected text.

## Reload The Package

Before we can trigger `ascii-art:convert` the window needs to reevaluate the
Ascii Art package. To do this we reload the window, just like when writing a
script in browser. Trigger `window:reload` command using the command palette or
by pressing `ctrl-alt-cmd-l`.

## Trigger The command

Now open the command panel and search for the `ascii-art:convert` command. But
its not there! To fix this open _package.json_ and find the property called
`activationEvents`. Activation Events speed up load time by allowing an Atom to
delay a package's activation until it's needed. So add the `ascii-art:convert` to the
activationEvents array:

```coffeescript
"activationEvents": ["ascii-art:convert"],
```

Now reload window `ctrl-alt-cmd-l` and use the command panel to trigger the
`ascii-art:convert` command. It will uppercase any text you have selected.

## Add A Key Binding

Now let's add a key binding to trigger the `ascii-art:convert` command. Open
_keymaps/ascii-art.cson_ and add a key binding linking `ctrl-alt-a` to the
`ascii-art:convert` command. When finished, the file will look like this:

```coffeescript
'.editor':
  'cmd-alt-a': 'ascii-art:convert'
```

Notice `.editor` on the first line. This limits the key binding to work when the
focused element matches the selector `.editor`, much like CSS. For example, if
the Tree View has focus, pressing `cmd-alt-a` won't trigger the
`ascii-art:convert` command. But if the editor has focus, the
`ascii-art:convert` method will be triggered. More information on key bindings
can be found in the [keymaps][keymaps] documentation.

Now reload the window and verify that pressing the key binding works! You can
also verify that it **doesn't** work when the Tree View is focused.

## Add The Ascii Art

Now we need to convert the selected text to ascii art. To do this we will use
the [figlet node module](https://npmjs.org/package/figlet) from NPM. Open
_package.json_ add the latest version of figlet to the dependencies:

```json
  "dependencies": {
     "figlet": "1.0.8"
  }
```

NOW GO TO THE COMMAND LINE AND RUN APM UPDATE BUT REALLY THIS STEP SEEMS LIKE
IT COULD BE AN ATOM COMMAND.

Require the figlet node module in _lib/ascii-art.coffee_ and
instead of uppercasing the text, you can convert it to ascii art!

```coffeescript
convert: ->
  # This assumes the active pane item is an editor
  selection = atom.workspace.activePaneItem.getSelection()

  figlet = require 'figlet'
  figlet selection.getText(), {font: "Larry 3D 2"}, (error, asciiArt) ->
    if error
      console.error(error)
    else
      selection.insertText("\n" + asciiArt + "\n")
```

## Further reading

For more information on the mechanics of packages, check out
[Creating a Package][creating-a-package].

[keymaps]: advanced/keymaps.html
[bundled-libs]: creating-a-package.html#included-libraries
[styleguide]: https://github.com/atom/styleguide
[space-pen]: https://github.com/atom/space-pen
[node]: http://nodejs.org/
[path]: http://nodejs.org/docs/latest/api/path.html
[changer_file_view]: https://f.cloud.github.com/assets/69169/1441187/d7a7cb46-41a7-11e3-8128-d93f70a5d5c1.png
[changer_panel_append]: https://f.cloud.github.com/assets/69169/1441189/db0c74da-41a7-11e3-8286-b82dd9190c34.png
[changer_panel_timestamps]: https://f.cloud.github.com/assets/69169/1441190/dcc8eeb6-41a7-11e3-830f-1f1b33072fcd.png
[theme-vars]: theme-variables.html
[creating-a-package]: creating-a-package.html
