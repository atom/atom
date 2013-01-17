# Atom Compile Extension

This extension should act as a base to "extend" other compilation extensions.
The idea is inspired by the Emacs compile-mode and similar utilities.
Running tests or CI is distinctly similar to the build process in software.

Example usage:

```
Compile = require('compile')

module.exports =
class RubyTest extends Compile
  compileCommand: ->
    'bin/rspec'
```