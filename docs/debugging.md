# Debugging

Atom provides several tools to help you understand unexpected behavior and debug problems. This guide describes some of those tools and a few approaches to help you debug and provide more helpful information when [submitting issues]:

* [Update to the latest version](#update-to-the-latest-version)
* [Check for linked packages](#check-for-linked-packages)
* [Check Atom and package settings](#check-atom-and-package-settings)
* [Check the keybindings](#check-the-keybindings)
* [Check if the problem shows up in safe mode](#check-if-the-problem-shows-up-in-safe-mode)
* [Check your config files](#check-your-config-files)
* [Check for errors in the developer tools](#check-for-errors-in-the-developer-tools)

## Update to the latest version

You might be running into an issue which was already fixed in a more recent version of Atom than the one you're using.

If you're building Atom from source, pull down the latest version of master and [re-build][building atom].

If you're using released version, check which version of Atom you're using:

```shell
$ atom --version
0.99.0
```

Head on over to the [list of releases][atom releases] and see if there's a more recent release. You can update to the most recent release by downloading Atom from the releases page, or with the in-app auto-updater. The in-app auto-updater checks for and downloads a new version after you restart Atom, or if you use the Atom > Check for Update menu option.

## Check for linked packages

If you develop or contribute to Atom packages, there may be left-over packages linked to your `~/.atom/packages` or `~/.atom/dev/packages` directories. You can use:

```shell
$ apm links
```

to list all linked development packages. You can remove the links using the `apm unlink` command. See `apm unlink --help` for details.

## Check Atom and package settings

In some cases, unexpected behavior might be caused by misconfigured or unconfigured settings in Atom or in one of the packages.

Open Atom's Settings View with `cmd-,` or the Atom > Preferences menu option.

![Settings View]

Check Atom's settings in the Settings pane, there's a description of each configuration option [here][customizing guide]. For example, if you want Atom to use hard tabs (real tabs) and not soft tabs (spaces), disable the "Soft Tabs" option.

Since Atom ships with a set of packages and you can install additional packages yourself, check the list of packages and their settings. For example, if you'd like to get rid of the vertical line in the middle of the editor, disable the [Wrap Guide package]. And if you don't like it when Atom strips trailing whitespace or ensures that there's a single trailing newline in the file, you can configure that in the [Whitespace packages'][whitespace package] settings.

![Package Settings]

## Check the keybindings

If a command is not executing when you hit a keystroke or the wrong command is executing, there might be an issue with the keybindings for that keystroke. Atom ships with the [Keybinding resolver][keybinding resolver package], a neat package which helps you understand which keybindings are executed.

Show the keybinding resolver with <code>cmd-.</code> or with "Key Binding Resolver: Show" from the Command palette. With the keybinding resolver shown, hit a keystroke:

![Keybinding Resolver]

The keybinding resolver shows you a list of keybindings that exist for the keystroke, where each item in the list has the following:
* the command for the keybinding,
* the CSS selector used to define the context in which the keybinding is valid, and
* the file in which the keybinding is defined.

Of all the keybinding that are listed (grey color), at most one keybinding is matched and executed (green color). If the command you wanted to trigger isn't listed, then a keybinding for that command hasn't been defined. More keybindings are provided by [packages] and you can [define your own keybindings][customizing keybindings].

If multiple keybindings are matched, Atom determines which keybinding will be executed based on the [specificity of the selectors and the order in which they were loaded][specificity and order]. If the command you wanted to trigger is listed in the Keybinding resolver, but wasn't the one that was executed, this is normally explained by one of two causes:
* the keystroke was not used in the context defined by the keybinding's selector. For example, you can't trigger the "Tree View: Add File" command if the Tree View is not focused, or
* there is another keybinding that took precedence. This often happens when you install a package which defines keybinding that conflict with existing keybindings. If the package's keybindings have selectors with higher specificity or were loaded later, they'll have priority over existing ones.

Atom loads core Atom keybindings and package keybindings first, and user-defined keybindings after last. Since user-defined keybindings are loaded last, you can use your `keymap.cson` file to tweak the keybindings and sort out problems like these. For example, you can remove keybindings with [the `unset!` directive][unset directive].

If you notice that a package's keybindings are taking precedence over core Atom keybindings, it might be a good idea to report the issue on the package's GitHub repository.

## Check if the problem shows up in safe mode

A large part of Atom's functionality comes from packages you can install. In some cases, these packages might be causing unexpected behavior, problems, or performance issues.

To determine if a package you installed is causing problems, start Atom from the terminal in safe mode:

```
$ atom --safe
```

This starts Atom, but does not load packages from `~/.atom/packages` or `~/.atom/dev/packages`. If you can no longer reproduce the problem in safe mode, it's likely it was caused by one of the packages.

To figure out which package is causing trouble, start Atom normally again and open Settings (`cmd-,`). Since Settings allow you to disable each installed package, you can disable packages one by one until you can no longer reproduce the issue. Restart (`cmd-q`) or reload (`cmd-ctrl-alt-l`) Atom after you disable each package to make sure it's completely gone.

When you find the problematic package, you can disable or uninstall the package, and consider creating an issue on the package's GitHub repository.

## Check your config files

You might have defined some custom functionality or styles in Atom's [Init script or Stylesheet]. In some situations, these personal hacks might be causing problems so try clearing those files and restarting Atom.

## Check for errors in the developer tools

When an error is thrown in Atom, the developer tools are automatically shown with the error logged in the Console tab. However, if the dev tools are open before the error is triggered, a full stack trace for the error will be logged:

![devtools error]

If you can reproduce the error, use this approach to get the full stack trace. The stack trace might point to a problem in your [Init script][init script or stylesheet] or a specific package you installed, which you can then disable and report an issue on its GitHub repository.

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
[init script or stylesheet]: https://atom.io/docs/latest/customizing-atom#quick-personal-hacks
[devtools error]: https://cloud.githubusercontent.com/assets/38924/3177710/11b4e510-ec13-11e3-96db-a2e8a7891773.png
