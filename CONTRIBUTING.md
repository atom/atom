# :rotating_light: Contributing to Atom :rotating_light:

## Issues
  * Include screenshots and animated GIFs whenever possible, they are immensely
    helpful
  * Include the behavior you expected to happen and other places you've seen
    that behavior such as Emacs, vi, Xcode, etc.
  * Check the Console app for stack traces to include if reporting a crash
  * Check the Dev tools (`alt-cmd-i`) for errors and stack traces to include

## Code
  * Follow the [JavaScript](https://github.com/styleguide/javascript),
    [CSS](https://github.com/styleguide/css),
    and [Objective-C](https://github.com/github/objective-c-conventions)
    styleguides
  * Include thoughtfully worded [Jasmine](http://pivotal.github.com/jasmine/)
    specs
  * Style new elements in both the light and dark default themes when
    appropriate
  * New packages go in `src/packages/`
  * Add 3rd-party packages by submoduling in `vendor/packages/`
  * Commit messages are in the present tense
  * Files end with a newline
  * Class variables and methods should be in the following order:
    * Class variables (variables starting with a `@`)
    * Class methods (methods starting with a `@`)
    * Instance variables
    * Instance methods
