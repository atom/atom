# :rotating_light: Contributing to Atom :rotating_light:


## Issues
  * Include screenshots and animated GIFs whenever possible, they are immensely
    helpful.
  * Include the behavior you expected to happen and other places you've seen
    that behavior such as Emacs, vi, Xcode, etc.
  * Check the Console app for stack traces to include if reporting a crash.
  * Check the Dev tools (`alt-cmd-i`) for errors and stack traces to include.

## Pull Requests
  * Include screenshots and animated GIFs whenever possible.
  * Follow the [JavaScript](https://github.com/styleguide/javascript) and
    [CSS](https://github.com/styleguide/css) styleguides
  * Include thoughtfully worded [Jasmine](http://pivotal.github.com/jasmine/)
    specs
  * Avoid placing files in `vendor`. 3rd-party packages should be added as a
    `package.json` dependency.
  * Commit messages are in the present tense
  * Files end with a newline.
  * Requires should be in the following order:
    * Node Modules
    * Built in Atom and Atom Shell modules
    * Local Modules (using relative links)
  * Class variables and methods should be in the following order:
    * Class methods (methods starting with a `@`)
    * Instance methods
  * Beware of platform differences
    * Use `require('atom').fs.getHomeDirectory()` to get the home directory.
    * Use `path.join()` to concatenate filenames.
    * Temporary directory is not `/tmp` on Windows, use `os.tmpdir()` when
      possible
