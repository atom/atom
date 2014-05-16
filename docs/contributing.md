# Contributing to Atom Packages

The following is a set of guidelines for contributing to Atom packages, which
are hosted in the [Atom Organization](https://github.com/atom) on GitHub. If
you're unsure which package is causing your problem or if you're having an issue
with Atom core, please use the feedback form in the application or email
[atom@github.com](mailto:atom@github.com).

## Submitting Issues

* Include screenshots and animated GIFs whenever possible; they are immensely
  helpful.
* Include the behavior you expected and other places you've seen that behavior
  such as Emacs, vi, Xcode, etc.
* Check the dev tools (`alt-cmd-i`) for errors and stack traces to include.
* Check Console.app for stack traces to include if reporting a crash.
* Perform a cursory search to see if a similar issue has already been submitted.

## Hacking on Packages

### Cloning

The first step is creating your own clone. You can of course do this manually
with git, or you can use the `apm develop` command to create a clone based on
the package's `repository` field in the `package.json`.

For example, if you want to make changes to the `tree-view` package, run the
following command:

```
> apm develop tree-view
Cloning https://github.com/atom/tree-view ✓
Installing modules ✓
~/.atom/dev/packages/tree-view -> ~/github/tree-view
```

This clones the `tree-view` repository to `~/github`. If you prefer a different
path, specify it via the `ATOM_REPOS_HOME` environment variable.

### Running in Development Mode

Editing a package in Atom is a bit of a circular experience: you're using Atom
to modify itself. What happens if you temporarily break something? You don't
want the version of Atom you're using to edit to become useless in the process.
For this reason, you'll only want to load packages in **development mode** while
you are working on them. You'll perform your editing in **stable mode**, only
switching to development mode to test your changes.

To open a development mode window, use the "Application: Open Dev" command,
which is normally bound to `cmd-shift-o`. You can also run dev mode from the
command line with `atom --dev`.

To load your package in development mode, create a symlink to it in
`[AtomConfDir](user-dirs.md)/dev/packages`. This occurs automatically when you clone the package
with `apm develop`. You can also run `apm link --dev` and `apm unlink --dev`
from the package directory to create and remove dev-mode symlinks.

### Installing Dependencies

Finally, you need to install the cloned package's dependencies by running
`apm install` within the package directory. This step is also performed
automatically the first time you run `apm develop`, but you'll want to keep
dependencies up to date by running `apm update` after pulling upstream changes.

## Submitting Pull Requests

### Code Guidelines

* Include screenshots and animated GIFs in your pull request whenever possible.
* Follow the [CoffeeScript](#coffeescript-styleguide),
  [JavaScript](https://github.com/styleguide/javascript),
  and [CSS](https://github.com/styleguide/css) styleguides.
* Include thoughtfully-worded, well-structured
  [Jasmine](http://pivotal.github.com/jasmine) specs.
* Document new code based on the
  [Documentation Styleguide](#documentation-styleguide)
* End files with a newline.
* Place requires in the following order:
  * Built in Node Modules (such as `path`)
  * Built in Atom and Atom Shell Modules (such as `atom`, `shell`)
  * Local Modules (using relative paths)
* Place class properties in the following order:
  * Class methods and properties (methods starting with a `@`)
  * Instance methods and properties
* Avoid platform-dependent code:
  * Use `require('atom').fs.getHomeDirectory()` to get the home directory.
  * Use `path.join()` to concatenate filenames.
  * Use `os.tmpdir()` rather than `/tmp` when you need to reference the
    temporary directory.

### Commit Message Guidelines
  * Use the present tense ("Add feature" not "Added feature")
  * Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
  * Limit the first line to 72 characters or less
  * Reference issues and pull requests liberally
  * Consider starting the commit message with an applicable emoji:
    * :lipstick: when improving the format/structure of the code
    * :racehorse: when improving performance
    * :non-potable_water: when plugging memory leaks
    * :memo: when writing docs
    * :bulb: Check out the [Emoji Cheat Sheet](http://www.emoji-cheat-sheet.com)
      for more ideas.

## CoffeeScript Styleguide

* Use parentheses if it improves code clarity.
* Prefer alphabetic keywords to symbolic keywords:
  * `a is b` instead of `a == b`
* Avoid spaces inside the curly-braces of hash literals:
  * `{a: 1, b: 2}` instead of `{ a: 1, b: 2 }`
* Set parameter defaults without spaces around the equal sign:
  * `clear = (count=1) ->` instead of `clear = (count = 1) ->`
* Include a single line of whitespace between methods.

## Documentation Styleguide

* Use [TomDoc](http://tomdoc.org).
* Use [Markdown](https://daringfireball.net/projects/markdown).
* Reference methods and classes in markdown with the custom `{}` notation:
  * Reference classes with `{ClassName}`
  * Reference instance methods with `{ClassName::methodName}`
  * Reference class methods with `{ClassName.methodName}`

### Example

```coffee
# Public: Disable the package with the given name.
#
# This method emits multiple events:
#
# * `package-will-be-disabled` - before the package is disabled.
# * `package-disabled`         - after the package is disabled.
#
# name     - The {String} name of the package to disable.
# options  - The {Object} with disable options (default: {}):
#   :trackTime - `true` to track the amount of time disabling took.
#   :ignoreErrors - `true` to catch and ignore errors thrown.
# callback - The {Function} to call after the package has been disabled.
#
# Returns `undefined`.
disablePackage: (name, options, callback) ->
```
