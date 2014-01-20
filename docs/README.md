# Welcome to the Atom API Documentation

![Atom](http://i.imgur.com/OrTvUAD.png)

## FAQ

### Where do I start?

Check out [EditorView][EditorView] and [Editor][Editor] classes for a good
overview of the main editor API.

### How do I access these classes?

Check out the [Atom][Atom] class docs to see what globals are available and
what they provide.

You can also require many of these classes in your packages via:

```coffee
{EditorView} = require 'atom'
```

### How do I create a package?

You probably want to read the [creating a package][creating-a-package]
doc first and come back here when you are done.

[Atom]: ../classes/Atom.html
[Editor]: ../classes/Editor.html
[EditorView]: ../classes/EditorView.html
[creating-a-package]: https://www.atom.io/docs/latest/creating-a-package
