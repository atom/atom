## Converting a TextMate Bundle

This guide will show you how to convert a [TextMate][TextMate] bundle to an
Atom package.

Converting a TextMate bundle will allow you to use its editor preferences,
snippets, and colorization inside Atom.

### Install apm

The `apm` command line utility that ships with Atom supports converting
a TextMate bundle to an Atom package.

Check that you have `apm` installed by running the following command in your
terminal:

```sh
apm help init
```

You should see a message print out with details about the `apm init` command.

If you do not, launch Atom and run the _Atom > Install Shell Commands_ menu
to install the `apm` and `atom` commands.

### Convert the Package

Let's convert the TextMate bundle for the [R][R] programming language. You can find other existing TextMate bundles [here][TextMateOrg].

You can convert the R bundle with the following command:

```sh
apm init --package ~/.atom/packages/language-r --convert https://github.com/textmate/r.tmbundle
```

You can now browse to `~/.atom/packages/language-r` to see the converted bundle.

:tada: Your new package is now ready to use, launch Atom and open a `.r` file in
the editor to see it in action!

### Further Reading

* Check out [Publishing a Package](publishing-a-package.html) for more information
  on publishing the package you just created to [atom.io][atomio].

[atomio]: https://atom.io
[CSS]: http://en.wikipedia.org/wiki/Cascading_Style_Sheets
[Less]: http://lesscss.org
[plist]: http://en.wikipedia.org/wiki/Property_list
[R]: http://en.wikipedia.org/wiki/R_(programming_language)
[TextMate]: http://macromates.com
[TextMateOrg]: https://github.com/textmate
