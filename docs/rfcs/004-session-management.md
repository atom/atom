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

A _Session_ is the unit of persistent window state in Atom related to a coherent development effort. It includes:

* The set of root folders;
* Pane and dock configuration;
* Open pane and dock items;
* Cursor position, fold state, and other TextEditor characteristics;
* Per-package [serialized state](https://flight-manual.atom.io/behind-atom/sections/serialization-in-atom/).

Each Atom window is associated with one Session, and each Session is associated with at most one Atom window at a time.

Each Session has a unique, user-customizable name.

Other persistent state is tracked _per-file_, based on its inode or fileID to work through filesystem softlinks or hardlinks. This includes:

* Unsaved buffer changes;
* Per-file manually changed indentation, line ending, and encoding settings.

### Add an explicit indication of the current Session to the tree-view

At the top of the tree-view, display the current Project's name. Clicking it opens the project management UI described below.

> TODO: graphic

### Add a command-line argument to explicitly choose the Session

When opening Atom from the command line with one or more locations specified:

1. If exactly one non-open Session matches those paths, that Session is loaded into the newly opened Atom window.
2. If no non-open Sessions match, a new Session is created for that Atom window.
3. If multiple Sessions match, a new Session is created for that Atom window, and a notification is displayed allowing the user to switch to any of the matching Sessions and destroy the just-created one.

In this context, "matches" means _every path in the set, normalized through realpath and case sensitivity, begins with the path of at least one project folder in the Session under consideration_, and, as a special case, _a Session containing zero project folders matches everything_.

The `--session` or `-s` flags to the `atom` command-line script explicitly designate the name of a Session which the newly opened window should open. If no Session with that name exists, a new one is created. If a window is already open on the named Session, the provided paths are added to the existing window and it is brought to the foreground.

```sh
# Open a new Atom window containing:
# * the root folder "src/project-one"
# * TextEditor on "${HOME}/writing/tps-report.txt"
$ atom --session work src/project-one ~/writing/tps-report.txt

# Open a new Atom window containing:
# * the root folder "src/game"
$ atom -s fun src/game

# Add the root folder "src/project-three" to the existing "work" window
$ atom -s work src/project-three

# (close the "work" window)

# Re-open a new Atom window with:
# * root folders "src/project-one" and "src/project-three"
# * TextEditor on "${HOME}/writing/tps-report.txt"
$ atom -s work
```

`--session` is mutually exclusive with the `--add` option, which always adds the associated paths to the matching or last-opened window's Session.

### Create a new bundled package to list and manage serialized state

Clicking the "Session" tile in the tree-view opens a workspace item for listing, creating, loading, modifying, and deleting known Sessions. This is where Sessions can be renamed and managed.

> TODO: graphic

Loading a different Session immediately serializes the window's state into the previously active project and deserializes the window state from the chosen one into this window.

A separate tab within the Session management shows known unsaved buffers. This acts as a kind of "dead letter office" to track down and recover lost changes.

> TODO: graphic

### When opening a buffer, restore its per-file state

Each time a new buffer is opened, restore its per-file state if any has been persisted, regardless of the window's active session. If the file on disk has been modified externally since the unsaved changes were created, display a banner in the TextEditor to give the user a notice.

> TODO: graphic

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
