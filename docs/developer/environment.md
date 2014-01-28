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

## CoffeeScript

Atom's core and standard packages are written in
[CoffeeScript](http://coffeescript.org), which provides an convenient
alternative syntax for JavaScript. Under the hood, CoffeeScript is compiled to
JavaScript before it is run, but Atom supports requiring `.coffee` files
directly, so you don't actually need to worry about this step.

If you already know JavaScript, CoffeeScript really shouldn't be difficult to
pick up, but you should also feel free to write packages in standard JavaScript,
as none of Atom's APIs require that you use CoffeeScript.

## Node.js

To be useful as a text editor, Atom needs to have access to system facilities
such as writing files and spawning subprocesses. Since standard browser-based
JavaScript lacks these abilities, we've extended Atom's environment with
Node.js, which adds all the privileged features you'd expect from a
full-featured programming language.

A full discussion working with Node.js is outside the scope of this guide, but
we will provide a brief overview. For full documentation of the various APIs
provided by Node, refer to the [Node API docs](http://nodejs.org/docs/v0.11.10/api/).
Everything that works in a standard Node application should also work in Atom.

### Node's Module System

Atom uses Node's module system to organize code, which we'll review briefly
here. For an in-depth description of Node's module system (which Atom fully
supports) see the
[documentation for Node's module system](http://nodejs.org/api/modules.html).

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

## Global Variables

Atom exposes core services through singleton objects attached to the `atom`
global. Refer to the in-depth guides for the various globals to learn more.

* `atom`
  * `.workspace`
      Manipulate and query the state of the user interface for the current
      window. Open editors, manipulate panes.
  * `.workspaceView`
      Similar to workspace, but provides access to the root of all *views* in
      the current window.
  * `.project`
      Access the directory associated with the current window. Load editors,
      perform project-wide searches, register custom openers for special file
      types.
  * `.config`
      Read, write, and observe user configuration settings.
  * `.keymap`
      Add and query the currently active keybindings.
  * `.deserializers`
      Deserialize instances from their state objects and register deserializers.
  * `.packages`
      Activate, deactivate, and query user packages.
  * `.themes`
      Activate, deactivate, and query user themes.
  * `.contextMenu`
      Register context menus.
  * `.menu`
      Register application menus.
  * `.pasteboard`
      Read from and write to the system pasteboard.
  * `.syntax`
      Assign and query syntactically-scoped properties.
