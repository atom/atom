# Debugging

Even though Atom is still in beta, minimizing problems is always a priority. Atom provides some tools to help you understand unexpected behavior, debug problems and solve them yourself in some cases.

This guide describes some of those tools and a few approaches to help you debug and provide more helpful information when [submitting issues].

## Update to the latest version

You might be running into an issue which was already fixed in a more recent version of Atom than the one you're using.

If you're **building Atom from source**, pull down the latest version of master and [re-build][building atom].

If you're **using released version**, check which version of Atom you're using:

```shell
$ atom --version
0.99.0
```

Head on over to the [list of releases][atom releases] and see if there's a more recent release. You can update to the most recent release by downloading Atom from the releases page, or with the in-app auto-updater. The in-app auto-updater checks for and downloads a new version after you restart Atom, or if you use the Atom > Check for Update menu option.

## Check Atom and package settings

In some cases, unexpected behavior might be caused by misconfigured or unconfigured settings in Atom or in one of the packages.

Open Atom's Settings View with <code>cmd-`</code> or the Atom > Preferences menu option.

![Settings View]

Check **Atom's settings** in the Settings pane, there's a description of each configuration option [here][customizing guide]. For example, if you want Atom to use hard tabs (real tabs) and not soft tabs (spaces), disable the "Soft Tabs" option.

Since Atom ships with a set of packages and you can install additional packages yourself, check **the list of packages and their settings**. For example, if you'd like to get rid of the vertical line in the middle of the editor, disable the [Wrap Guide package]. And if you don't like it when Atom strips trailing whitespace or ensures that there's a single trailing newline in the file, you can configure that in the [Whitespace packages'][whitespace package] settings.

![Package Settings]

# Check the keybindings

If a command is not executing when you hit a keystroke or the wrong command is executing, there might be an issue with the keybindings for that keystroke. Atom ships with the [Keybinding resolver][keybinding resolver package], a neat package which helps you understand which keybindings are executed.

Show the keybinding resolver with <code>cmd-.</code> or with "Key Binding Resolver: Show" from the Command palette. With the keybinding resolver shown, hit a keystroke:

![Keybinding Resolver]

The keybinding resolver shows you a list of keybindings that exist for the keystroke, where each item in the list has the following:
* the command for the keybinding,
* the CSS selector used to define the context in which the keybinding is valid, and
* the file in which the keybinding is defined.

Of all the keybinding that are listed (grey color), at most one keybinding is matched and executed (green color). If **the command you wanted to trigger isn't listed**, then a keybinding for that command hasn't been defined. More keybindings are provided by [packages] and you can [define your own keybindings][customizing keybindings].

If multiple keybindings are matched, Atom determines which keybinding will be executed based on the [specificity of the selectors and the order in which they were loaded][specificity and order]. If **the command you wanted to trigger is listed in the Keybinding resolver, but wasn't the one that was executed**, this is normally explained by one of two causes:
* the keystroke was not used in the context defined by the keybinding's selector. For example, you can't trigger the "Tree View: Add File" command if the Tree View is not focused, or
* there is another keybinding running over it. This often happens when you install a package which defines keybinding that conflict with existing keybindings. If the package's keybindings have selectors with higher specificity or were loaded later, they'll have priority over existing ones.

Since user-defined keybindings are loaded last, you can use your `keymap.cson` file to tweak the keybindings and sort out problems like these. For example, you can remove keybindings with [the `unset!` directive][unset directive].

If you notice a package running over core Atom keybindings, it might be a good idea to report the issue on the package's GitHub repository.

[submitting issues]: https://github.com/atom/atom/blob/master/CONTRIBUTING.md#submitting-issues
[building atom]: https://github.com/atom/atom#building
[atom releases]: https://github.com/atom/atom/releases
[customizing guide]: https://atom.io/docs/latest/customizing-atom#configuration-key-reference
[settings view]: https://f.cloud.github.com/assets/671378/2241795/ba4827d8-9ce4-11e3-93a8-6666ee100917.png
[package settings]: https://cloud.githubusercontent.com/assets/38924/3173588/7e5f6b0c-ebe8-11e3-9ec3-e8d140967e79.png
[wrap guide package]: https://atom.io/packages/wrap-guide
[whitespace package]: https://atom.io/packages/whitespace
[keybinding resolver package]: https://atom.io/packages/keybinding-resolver
[keybinding resolver]: https://f.cloud.github.com/assets/671378/2241702/5dd5a102-9cde-11e3-9e3f-1d999930492f.png
[customizing keybindings]: https://atom.io/docs/latest/customizing-atom#customizing-key-bindings
[packages]: https://atom.io/packages
[specificity and order]: https://atom.io/docs/latest/advanced/keymaps#specificity-and-cascade-order
[unset directive]:  https://atom.io/docs/latest/advanced/keymaps#removing-bindings
