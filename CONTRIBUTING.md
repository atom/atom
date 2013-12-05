# :tada: Contributing to Atom :tada:

These are just guidelines, not rules, use your best judgement and feel free
to propose changes to this document in a pull request.

## Issues
  * Include screenshots and animated GIFs whenever possible, they are immensely
    helpful.
  * Include the behavior you expected to happen and other places you've seen
    that behavior such as Emacs, vi, Xcode, etc.
  * Check the Console app for stack traces to include if reporting a crash.
  * Check the Dev tools (`alt-cmd-i`) for errors and stack traces to include.
  
### Package Repositories

This is the repository for the core Atom editor only. Atom comes bundled with
many packages and themes that are stored in other repos under the
[atom org](https://github.com/atom) such as [tabs](https://github.com/atom/tabs),
[find-and-replace](https://github.com/atom/find-and-replace),
[language-javascript](https://github.com/atom/language-javascript),
and [atom-light-ui](http://github.com/atom/atom-light-ui).

If you think you know which package is causing the issue you are reporting, feel
free to open up the issue in that specific repository instead. When in doubt
just open the issue here but be aware that it may get closed here and reopened
in the proper package's repository.

## Pull Requests
  * Include screenshots and animated GIFs whenever possible.
  * Follow the [JavaScript](https://github.com/styleguide/javascript) and
    [CSS](https://github.com/styleguide/css) styleguides
  * Include thoughtfully worded [Jasmine](http://pivotal.github.com/jasmine/)
    specs
  * Avoid placing files in `vendor`. 3rd-party packages should be added as a
    `package.json` dependency.
  * Files end with a newline.
  * Requires should be in the following order:
    * Built in Node Modules (such as `path`)
    * Built in Atom and Atom Shell Modules (such as `atom`, `shell`)
    * Local Modules (using relative paths)
  * Class variables and methods should be in the following order:
    * Class methods (methods starting with a `@`)
    * Instance methods
  * Beware of platform differences
    * Use `require('atom').fs.getHomeDirectory()` to get the home directory.
    * Use `path.join()` to concatenate filenames.
    * Temporary directory is not `/tmp` on Windows, use `os.tmpdir()` when
      possible

## Git Commit Messages
  * Use the present tense
  * Reference issues and pull requests liberally
  * Consider starting the commit message with an applicable emoji:
    * :lipstick: when improving the format/structure of the code
    * :racehorse: when improving performance
    * :non-potable_water: when plugging memory leaks
    * :memo: when writing docs
