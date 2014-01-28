# The Atom Environment

## Chromium

Atom is based on Chromium, the open-source foundation of the Chrome web browser.
Though it looks like a native application, you can think of every window in Atom
as essentially a web page. There's no server of course. There's no concept of a
URI for the current page, no back button, and all rendering is performed
locally. But most of the concepts you'd apply to the client side of a
traditional web application also apply when customizing Atom. For example, you
should definitely make use of the developer tools, which can be toggled via
`alt-meta-i` just as they can in Chrome.

## Security

Never forget that even though Atom is built on web technology, Atom is not a
web browser. **Scripts running within Atom have privileged access to the entire
system,** and should be treated accordingly. Never run untrusted scripts or load
arbitrary web pages in a trusted context. If you need to run untrusted code, do
so in an untrusted iframe or JavaScript context. (TODO: Add ways to run
untrusted code)

## Node.js

To be useful as a text editor, Atom needs to have access to system facilities
such as writing files and spawning subprocesses. Since standard browser-based
JavaScript lacks these abilities, we've extended Atom's environment with
Node.js, which adds all the privileged features you'd expect from a
full-featured programming language.

### The Module System

Atom uses Node's module system to organize code, which we'll review briefly
here. For an in-depth description of Node's module system (which Atom fully
supports) see the [Node documentation](http://nodejs.org/api/modules.html).

#### Requiring Modules

To make use of code in another model, you import it into the current module
using the global `require` function. One way to require code is with a relative
path:

```coffee
module1 = require './module-1'
module2 = require '../sibling-dir/module-2'
```

Modules can also be required by name, allowing you to access built-in modules or
any of the current module's dependencies.

```coffee
fs = require 'fs'
{Range} = require 'atom'
```

#### Exporting From Modules

To provide functions and objects to other modules, use the `exports` variable
which is defined in every file:

```coffee
exports.foo = -> console.log("hello!")
exports.bar = -> console.log("world!")
```

You can also assign to `module.exports` if you want to export a single object,
function, or constructor from your module. You'll see this idiom in many of
Atom's standard packages:

```coffee
module.exports =
class SpaceShip
  takeOff: -> console.log("pshooo!")
```
