# Git integration

## Why does this exist

The primary purposes of the git integration are:

1. **Reduce context switching.** We can improve productivity by reducing the number of times you need to switch to a terminal (or Desktop or other external tool) to perform routine tasks.
2. **Streamline common workflows.** We want users to be able to perform the motions of commonly used workflows with minimum friction (hunting through menus or the command palette).
3. Improve **discoverability of git features.**
4. Provide _confidence and safety_ by **always being able to back out of a situation.**
5. Go _beyond what you can do on the command line_ with **graphical porcelain.**

## Boundaries

We want to focus on the basics - fundamental, primitive git operations that can be composed to form many workflows. To contrast, we do _not_ want to target completeness.

We will extend beyond this for features that are _uniquely useful in the context of an editor_:

* Modifying diffs before staging or committing
* Shaping commit history to tell a story
* Visually exploring someone else's commit history
* Enhanced debugging and troubleshooting backed by tools like `git bisect` and `git blame`.
* Improve merge conflict resolution by taking advantage of tree-sitter ASTs

Or for those that provide richer visualizations of git's state, like a log view.

As much as possible, we adhere to git terminology and concepts, rather than inventing our own. This allows users who learn git with our package to transfer their knowledge to other git tooling, and users who know git from other contexts to navigate our package more easily.

We also exert ourselves to stay in sync with the real state of git on the filesystem, including the index, refs, stashes, and so forth. We want it to remain easy to go to and from the terminal at will.
