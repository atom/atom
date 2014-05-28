# Welcome to the Atom API Documentation  

![Atom](https://cloud.githubusercontent.com/assets/72919/2874231/3af1db48-d3dd-11e3-98dc-6066f8bc766f.png)

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
  * [Workspace][Workspace]

### How do I create a package?

You probably want to read the [creating a package][creating-a-package]
doc first and come back here when you are done.

### Where are the node docs?

Atom ships with node 0.11.10 and the comprehensive node API docs are available
[here][node-docs].

[Atom]: ../classes/Atom.html
[BufferedProcess]: https://atom.io/docs/api/v0.98.0/api/classes/BufferedProcess.html
[BufferedNodeProcess]: https://atom.io/docs/api/v0.98.0/api/classes/BufferedNodeProcess.html
[Editor]: https://atom.io/docs/api/v0.98.0/api/classes/Editor.html
[EditorView]: https://atom.io/docs/api/v0.98.0/api/classes/EditorView.html
[Git]: https://atom.io/docs/api/v0.98.0/api/classes/Git.html
[Point]: https://atom.io/docs/api/v0.98.0/api/classes/Point.html
[Range]: https://atom.io/docs/api/v0.98.0/api/classes/Range.html
[ScrollView]: https://atom.io/docs/api/v0.98.0/api/classes/ScrollView.html
[SelectListView]: https://atom.io/docs/api/v0.98.0/api/classes/SelectListView.html
[View]: https://atom.io/docs/api/v0.98.0/api/classes/View.html
[WorkspaceView]: https://atom.io/docs/api/v0.98.0/api/classes/WorkspaceView.html
[Workspace]: https://atom.io/docs/api/v0.98.0/api/classes/Workspace.html
[creating-a-package]: https://atom.io/docs/latest/creating-a-package
[node-docs]: http://nodejs.org/docs/v0.11.10/api
