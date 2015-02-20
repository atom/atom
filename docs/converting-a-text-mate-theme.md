## Converting a TextMate Theme

This guide will show you how to convert a [TextMate][TextMate] theme to an Atom
theme.

### Differences

TextMate themes use [plist][plist] files while Atom themes use [CSS][CSS] or
[Less][Less] to style the UI and syntax in the editor.

The utility that converts the theme first parses the theme's plist file and
then creates comparable CSS rules and properties that will style Atom similarly.

### Install apm

The `apm` command line utility that ships with Atom supports converting
a TextMate theme to an Atom theme.

Check that you have `apm` installed by running the following command in your
terminal:

```sh
apm help init
```

You should see a message print out with details about the `apm init` command.

If you do not, launch Atom and run the _Atom > Install Shell Commands_ menu
to install the `apm` and `atom` commands.

You can now run `apm help init` to see all the options for initializing new
packages and themes.

### Convert the Theme

Download the theme you wish to convert, you can browse existing TextMate themes
[here][TextMateThemes].

Now, let's say you've downloaded the theme to `~/Downloads/MyTheme.tmTheme`,
you can convert the theme with the following command:

```sh
apm init --theme ~/.atom/packages/my-theme --convert ~/Downloads/MyTheme.tmTheme
```

You can browse to `~/.atom/packages/my-theme` to see the converted theme.

### Activate the Theme

Now that your theme is installed to `~/.atom/packages` you can enable it
by launching Atom and selecting the _Atom > Preferences..._ menu.

Select the _Themes_ link on the left side and choose _My Theme_ from the
__Syntax Theme__ dropdown menu to enable your new theme.

:tada: Your theme is now enabled, open an editor to see it in action!

### Further Reading

* Check out [Publishing a Package](publishing-a-package.html) for more information
  on publishing the theme you just created to [atom.io][atomio].

[atomio]: https://atom.io
[CSS]: https://en.wikipedia.org/wiki/Cascading_Style_Sheets
[Less]: http://lesscss.org
[plist]: https://en.wikipedia.org/wiki/Property_list
[TextMate]: http://macromates.com
[TextMateThemes]: http://wiki.macromates.com/Themes/UserSubmittedThemes
