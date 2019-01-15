# Improved Session Management

## Status

Proposed

## Summary

Atom's management of serialized project state is complicated and unintuitive. From [atom/atom#10517](https://github.com/atom/atom/issues/10517):

> There are things that are serialized and stored when Atom exits. It is completely non-obvious what items belong to this set and what items do not as well as how to restore the saved items when next launching Atom. Decisions should be made about whether some of these items belong to the specific mode that Atom is in or if they are more global state that people expect to be in place the next time Atom is launched (or even an individual file is opened post-launch) no matter what mode Atom is launched in.

Let's revisit the way we manage session state so that it becomes an Atom feature that users can understand and trust.

## Motivation

_pending_

Problems to address:

* The active project (which is deserialized on open, serialized on close) is chosen implicitly based on the set of project folders.
* The active project isn't explicitly named anywhere in the UI. Two open Atom windows with two different projects do not obviously differ; two open Atom windows on the same project are not obviously the same.
* Adding or removing a root folder silently changes the active project.
* When the same project is open in two Atom windows at once, the last-closed window clobbers any project state saved by the first-closed.
* Unsaved content in a TextBuffer is only accessible through the project that was open when it was created.

## Explanation

A _Project_ is the unit of persistent window state in Atom related to a coherent development effort. It includes:

* The set of root folders;
* Pane and dock configuration;
* Open pane and dock items;
* Cursor position, fold state, and other TextEditor characteristics;
* Per-package [serialized state](https://flight-manual.atom.io/behind-atom/sections/serialization-in-atom/).

Each Atom window is associated with one Project, and each Project is associated with at most one Atom window.

Each Project has a unique, user-customizable name.

Other persistent state is tracked _per-file_, based on its inode or fileID to work through filesystem softlinks or hardlinks. This includes:

* Unsaved buffer changes;
* Per-file manually changed indentation, line ending, and encoding settings.

### Add an explicit indication of the current Project to the tree-view

At the top of the tree-view, display the current Project's name. Clicking it opens the project management UI described below.

> TODO: graphic

### Add a command-line argument to explicitly choose the Project

The `--project` or `-p` flags to the `atom` command-line script explicitly designate the name of a Project to which the newly opened paths should belong. If no Project with that name exists, a new one is created. If a window is already open on the named Project, the provided paths are added to the existing window.

```sh
# Open a new Atom window containing:
# * the root folder "src/project-one"
# * TextEditor on "${HOME}/writing/tps-report.txt"
$ atom --project work src/project-one ~/writing/tps-report.txt

# Open a new Atom window containing:
# * the root folder "src/game"
$ atom -p fun src/game

# Add the root folder "src/project-three" to the existing "work" window
$ atom -p work src/project-three

# (close the "work" window)

# Re-open a new Atom window with:
# * root folders "src/project-one" and "src/project-three"
# * TextEditor on "${HOME}/writing/tps-report.txt"
$ atom -p work
```

It's mutually exclusive with the `--add` option (it is an error to provide both).

### Create a new bundled package to list and manage serialized state

Clicking the "project" tile in the tree-view opens a UI for listing, creating, loading, modifying, and deleting known projects. This is where projects can be renamed and managed.

> TODO: graphic

Loading a different Project immediately serializes the window's state into the previously active project and deserializes the window state from the chosen one into this window.

### Create a new bundled package to list and manage unsaved buffers

> TODO: graphic

### When opening a buffer, restore its per-file state

## Drawbacks

<!--
Why should we *not* do this?
-->

## Rationale and alternatives

<!--
- Why is this approach the best in the space of possible approaches?
- What other approaches have been considered and what is the rationale for not choosing them?
- What is the impact of not doing this?
-->

## Unresolved questions

<!--
- What unresolved questions do you expect to resolve through the RFC process before this gets merged?
- What unresolved questions do you expect to resolve through the implementation of this feature before it is released in a new version of Atom?
- What related issues do you consider out of scope for this RFC that could be addressed in the future independently of the solution that comes out of this RFC?
-->
