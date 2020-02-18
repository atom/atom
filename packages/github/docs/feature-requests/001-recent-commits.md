# Recent commit view

## Status

Proposed

## Summary

Display the most recent few commits in a chronologically-ordered list beneath the mini commit editor. Show commit author and committer usernames and avatars, the commit message, and relative timestamp of each.

## Motivation

* Provide useful context about recent work and where you left off.
* Allow user to easily revert and reset to recent commits.
* Make it easy to undo most recent commit action, supersede amend check box.
* Reinforce the visual "flow" of changes through being unstaged, staged, and now committed.
* Provide a discoverable launch point for an eventual log feature to explore the full history.
* Achieve greater consistency with GitHub desktop:

![desktop](https://user-images.githubusercontent.com/7910250/36570484-1754fb3c-17e7-11e8-8da3-b658d404fd2c.png)

## Explanation

### Blank slate

If the active repository has no commits yet, display a short panel with a background message: "Make your first commit".

### Recent commits

Otherwise, display a **recent commits** section containing a sequence of horizontal bars for ten **relevant** commits with the most recently created commit on top. The commits that are considered **relevant** include:

* Commits reachable by the remote tracking branch that is the current upstream of `HEAD`. If more than three of these commits are not reachable by `HEAD`, they will be hidden behind an expandable accordion divider.
* Commits reachable by `HEAD` that are not reachable by any local ref in the git repository.
* The single commit at the tip of the branch that was branched from.

The most recent three commits are visible by default and the user can scroll to see up to the most recent ten commits. The user can also drag a handle to resize the recent commits section and show more of the available ten.

### Commit metadata

Each **recent commit** within the recent commits section summarizes that commit's metadata, to include:

* GitHub avatar for both the committer and (if applicable) author. If either do not exist, show a placeholder.
* The commit message (first line of the commit body) elided if it would be too wide.
* A relative timestamp indicating how long ago the commit was created.
* A background highlight for commits that haven't been pushed yet to the remote tracking branch.

![metadata](https://user-images.githubusercontent.com/378023/39227929-4326d5ac-4896-11e8-9bbd-114d64335fad.png)

### Undo

On the most recent commit, display an "undo" button. Clicking "undo" performs a `git reset` and re-populates the commit message editor with the existing message.

### Context menu

Right-clicking a recent commit reveals a context menu offering interactions with the chosen commit. The context menu contains:

* For the most recent commit only, an "Amend" option. "Amend" is enabled if changes have been staged or the commit message mini-editor contains text. Choosing this applies the staged changes and modified commit message to the most recent commit, in a direct analogue to using `git commit --amend` from the command line.
* A "Revert" option. Choosing this performs a `git revert` on the chosen commit.
* A "Hard reset" option. Choosing this performs a `git reset --hard` which moves `HEAD` and the working copy to the chosen commit. When chosen, display a modal explaining that this action will discard commits and unstaged working directory context. Extra security: If there are unstaged working directory contents, artificially perform a dangling commit, disabling GPG if configured, before enacting the reset. This will record the dangling commit in the reflog for `HEAD` but not the branch itself.
* A "Mixed reset" option. Choosing this performs a `git reset` on the chosen commit.
* A "Soft reset" option. Choosing this performs a `git reset --soft` which moves `HEAD` to the chosen commit and populates the staged changes list with all of the cumulative changes from all commits between the chosen one and the previous `HEAD`.

### Balloon

On click, select the commit and reveal a balloon containing:

* Additional user information consistently with the GitHub integration's user mention item.
* The full commit message and body.
* The absolute timestamp of the commit.
* Navigation button ("open" to a git show-ish pane item)
* Action buttons ("amend" on the most recent commit, "revert", and "reset" with "hard", "mixed", and "soft" suboptions)

![ballon](https://user-images.githubusercontent.com/378023/39232628-deb144b4-48a8-11e8-916b-f15e6d032cba.png)

### Bottom Dock

If the Git dock item is dragged to the bottom dock, the recent commit section will remain a vertical list but appear just to the right of the mini commit editor.

![bottom-dock](https://user-images.githubusercontent.com/17565/36570687-14738ca2-17e8-11e8-91f7-5cf1472d871b.JPG)

## Drawbacks

Consumes vertical real estate in Git panel.

The "undo" button is not a native git concept. This can be mitigated by adding a tooltip to the "undo" button that defines its action: a `git reset` and commit message edit.

The "soft reset" and "hard reset" context menu options are useful for expert git users, but likely to be confusing. It would be beneficial to provide additional information about the actions that both will take.

The modal dialog on "hard reset" is disruptive considering that the lost changes are recoverable from `git reflog`. We may wish to remove it once we visit a reflog view within the package. Optionally add "Don't show" checkbox to disable modal.

## Rationale and alternatives

- Display tracking branch in separator that indicates which commits have been pushed. This could make the purpose of the divider more clear. Drawback is that this takes up space.
- Refs: Annotate visible commits that correspond to refs in the git repository (branches and tags). If the commit list has been truncated down to ten commits from the full set of relevant commits, display a message below the last commit indicating that additional commits are present but hidden.
  - Drawback: They would take up quite some space and are also unpredictable and might need multiple lines. We'll reconsider adding them in a log/history view.
- A greyed-out state if the commit is reachable from the remote tracking branch but _not_ from HEAD (meaning, if it has been fetched but not pulled).
  - Drawback: If there are more than 2-3 un-pulled commits, it would burry the local commits too much. We'll reconsider adding them in a log/history view.

## Unresolved questions

- Allow users to view the changes introduced by recent commits. For example, interacting with one of the recent commits could launch a pane item that showed the full commit body and diff, with additional controls for reverting, discarding, and commit-anchored interactions.
- Providing a bridge to navigate to an expanded log view that allows more flexible and powerful history exploration.
- Show an info icon and provide introductory information when no commits exist yet.
- Add a "view diff from this commit" option to the recent commit context menu.
- Integration with and navigation to "git log" or "git show" pane items when they exist.
- Can we surface the commit that we make on your behalf before performing a `git reset --hard` with unstaged changes? Add an "Undo reset" option to the context menu on the recent commit history until the next commit is made? Show a notification with the commit SHA after the reset is complete?

## Implementation phases

1. Convert `GitTabController` and `GitTabView` to React. [#1319](https://github.com/atom/github/pull/1319)
2. List read-only commit information. [#1322](https://github.com/atom/github/pull/1322)
3. Replace the amend checkbox with the "undo" control.
4. Context menu with actions.
5. Balloon with action buttons and additional information.
6. Show which commits have not been pushed.
