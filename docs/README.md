# Welcome to the Atom API Documentation

![Atom](http://i.imgur.com/OrTvUAD.png)

## FAQ

### Where do I start?

Check out [EditorView][EditorView] and [Editor][Editor] classes for a good
overview of the main editor API.

### How do I access these classes?

Check out the [Atom][Atom] class docs to see what globals are available and
what they provide.

You can also require many of these classes in your package via:

```coffee
{EditorView} = require 'atom'
```

The classes available from `require 'atom'` are:
  * [BufferedProcess][BufferedProcess]
  * [BufferedNodeProcess][BufferedNodeProcess]
  * [EditorView][EditorView]
  * [Git][Git]
  * [Point][Point]
  * [Range][Range]
  * [ScrollView][ScrollView]
  * [SelectListView][SelectListView]
  * [View][View]
  * [WorkspaceView][WorkspaceView]

### How do I create a package?

You probably want to read the [creating a package][creating-a-package]
doc first and come back here when you are done.

### Where are the node docs?

Atom ships with node 0.11.10 and the comprehensive node API docs are available
[here][node-docs].

[Atom]: ../classes/Atom.html
[BufferedProcess]: ../classes/BufferedProcess.html
[BufferedNodeProcess]: ../classes/BufferedNodeProcess.html
[Editor]: ../classes/Editor.html
[EditorView]: ../classes/EditorView.html
[Git]: ../classes/Git.html
[Point]: ../classes/Point.html
[Range]: ../classes/Range.html
[ScrollView]: ../classes/ScrollView.html
[SelectListView]: ../classes/SelectListView.html
[View]: ../classes/View.html
[WorkspaceView]: ../classes/WorkspaceView.html
[creating-a-package]: https://www.atom.io/docs/latest/creating-a-package
[node-docs]: http://nodejs.org/docs/v0.11.10/api
