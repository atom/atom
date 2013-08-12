# :rotating_light: Contributing to Atom :rotating_light:

# Write Beautiful Code

As GitHub's largest open-source project, we want Atom to be beautiful inside and out. Your code will serve as an example for new members of the community, and will ultimately be a factor in how Atom and GitHub as a whole are judged. Please respect the company's reputation and the efforts of those that have come before you by always striving to do your best work when contributing to Atom.

Be pragmatic, but don't confuse pragmatism with laziness. Avoid hacks and shortcuts motivated by impatience. Stay present, and focus on the quality of the code you are writing *now*. It's not enough for your code to "work", it also needs to communicate to other humans who will need to modify and build upon it. Once you get something working, take the time to consider whether you can achieve it in a more elegant way.

## Care hard, but fear not
We want your best work: nothing more, nothing less. Don't be afraid to put yourself out there. We will always treat your contributions with respect.

## When in doubt, pair-up

## Write tests, and write them first
Without tests, building a large application in a dynamic language is like building a sky scraper out of play dough. The test suite is our first, last, and only line of defense against the entropic heat death of our codebase. You should almost always write a failing test *before* adding implementation code, to prove to yourself that the test is actually falsifiable. If you add a feature that can break without alerting us via a failing test, then you haven't added a feature, you've created a liability. If you haven't coded in this style before, seek out a community member who can help you. A healthy test suite is essential to our success, and only you can maintain the practices that keep it healthy.

## Leave the test suite better than you found it

## Tests cost resources: write them judiciously

## Solve today's problem
Avoid adding flexibility that isn't needed *today*. Nothing is ever set in stone, and we can always go back and add flexibility later. Adding it early just means we have to pay for complexity that we might not end up using.

## Don't be defensive
Do handle errors when writing to a file or calling a remote API. Don't handle errors when interacting with logic that we own. Always assume that our code works properly, even though that won't always be true. When it does break, we don't want to paper over the problem with exception handling. We just want to fix the original issue. Avoiding defensiveness keeps our code lean and on-topic.

## Don't be afraid to add classes and methods
Code rarely suffers from too many methods and classes. Code often suffers from too few. Don't be afraid to use the tools offered by the language. Write lots of short, well-named methods. Pull out classes with well-defined roles.

## Favor clarity over brevity or cleverness.
You've heard it before. We're saying it again. Three lines that someone else can read beats one line that's inscrutable every time.

## Rip shit out

## Maintain a consistent level of abstraction
Every line in a method should read at the same basic level of abstraction. If there's a section of a method that goes into a lot more detail than the rest of the method, consider extracting a new method and giving it a clear name.

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
  * Add 3rd-party packages as a `package.json` dependency
  * Commit messages are in the present tense
  * Files end with a newline
  * Class variables and methods should be in the following order:
    * Class variables (variables starting with a `@`)
    * Class methods (methods starting with a `@`)
    * Instance variables
    * Instance methods
