# Crazy Idea Free-For-All Grab Bag

_In no particular order_

* Add informational popups and make subtle changes to UI verbiage to improve the experience of novice git users. We want to provide _subtle_ guidance and education that can nudge users to the common, recommended next steps, with some knowledge of what they're doing.

* Improved remote and branch management. Our current `BranchMenuView` is limited and unscalable.
  * Initiate branch merges and rebases in-editor.
  * Delete branches.
  * Specifically, delete local branches that have already been merged into the repository's main branch.
  * Prune remote tracking branches.
  * Manage remotes: add new ones, delete existing ones, rename or set URLs for existing ones.

* Initialization, providing username and email.
  * "You're committing with email address X" as a prompt for those who use different email addresses for different projects.

* Rework the WorkerManager, either with [WebWorkers](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Using_web_workers) or the [spawn-server](https://github.com/nathansobo/spawn-server). Our current solution with a hidden render process is heavyweight.

* Create a PaneItem for arbitrary, multi-file diffs. Closely related: implement a commit viewer, which is basically that with a header for the commit message and metadata.

* Stashing.

* Git Virtual FS. It isn't clear if we'd even need to do anything to support this, but we should at least test with it.

* An interactive, navigable log view. Visualize your full commit history graph, including refs. Filter and search commits by author, message, or diff content. Merge by visually linking the merge bases. Rebase or cherry-pick by dragging and dropping commit nodes around. Revert or reset refs from a context menu.

* Blame information, in-editor, on demand.
  * Navigate from blame to the commit and pull request that introduced it. Include cross-references for quick navigation.

* Editable diffs.

* Enhanced reflog. Pane item that displays and searches everything that `git reflog` shows you, interleaved with additional events that git is unaware of but Atom is (like discards). For each displayed, action, provide an explanation, and a collection of possible actions to "undo" its effect, along with a description of the implications of each. For example, for a commit event, offer a revert or a rebase, and advise one or the other depending on whether or not the commit has been pushed to a remote or not.

* "Where is my code?" Given a pull request, show the tags or GitHub releases that include it. Given a commit, find the pull request that introduced it.

* Provide context behind merge conflicts. For a specific conflict, identify the exact commits reachable from each parent that introduced a conflicting hunk.

* Automatic CHANGELOG generation.

* Release creation.

* Show diffs from "far away" - code that has been pushed to elsewhere in your repository's fork network, but that you haven't explicitly fetched yet.

* Provide advance warning when local changes will have merge conflicts with changes on a remote.

* "Here's what's changed." View pull requests and other recent activity on pull to see what's different.

* Issue drafts. Write quick notes to yourself as the thoughts occur to you, then open them all at once as issue drafts on github.com when you're ready to flesh them out and share them.
