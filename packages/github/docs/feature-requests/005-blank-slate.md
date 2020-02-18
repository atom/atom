<!---
For community contributors -- Please fill out Part 1 of the following template. This will help our team collaborate with you and give us an opportunity to provide valuable feedback that could inform your development process. Sections in Part 2 are not mandatory to get the conversation started, but will help our team understand your vision better and allow us to give better feedback.
--->

**_Part 1 - Required information_**

# Improved Blank Slate Behavior

## :memo: Summary

Improve the behavior of the GitHub tab when no GitHub remote is detected to better guide users to start using GitHub features.

## :checkered_flag: Motivation

Well, for one thing, we've had TODOs in [GitHubTabView](https://github.com/atom/github/blob/cf1009243a35e2a6880ae3c969f2fe2a11d3f72d/lib/views/github-tab-view.js#L81) and [GitHubTabContainer](https://github.com/atom/github/blob/cf1009243a35e2a6880ae3c969f2fe2a11d3f72d/lib/containers/github-tab-container.js#L78-L81) for these cases since they were written. But we've also received repeated and clear feedback from UXR studies, [issues](https://github.com/atom/github/issues/1962), and [the forum](https://discuss.atom.io/t/github-link/60168) that users are confused about what to do to "link a repository with GitHub" to use our GitHub features.

This is a roadblock that is almost certainly keeping users who want to use our package from doing so.

## 🤯 Explanation

Our goal is to provide prompts for useful next steps when the current repository does not have a unique remote pointing to `https://github.com`. When a user opens the GitHub tab in any of these situations, they should be presented with options to direct their next course of action.

In each situation below, our user's goal is the same: to have the repository they wish to work on (a) cloned on their computer with a correct remote configuration and (b) on dotcom.

## GitHub tab

### No local repository

We detect this state when the active repository is absent, meaning there are no project root directories.

<img width="400" alt="github tab, no local repositories" src="https://user-images.githubusercontent.com/17565/57078325-0d0b3300-6cbc-11e9-9bb0-49087d7911b5.png">

#### ...no dotcom repository

_Scenario:_ A user wants to start a new project published on GitHub.

Clicking the "Create a new GitHub repository" button opens the [Create repository dialog](#create-repository-dialog).

#### ...existing dotcom repository

_Scenario:_ A user wishes to contribute to a project that exists on GitHub, but does not yet have a clone on their local machine. Perhaps a friend or co-worker created the repository and they wish to collaborate, or they're working on a personal project on a different machine, or there is an open-source repository they wish to contribute to.

Clicking the "Clone an existing GitHub repository" button opens the [Clone repository dialog](#clone-repository-dialog).

### Local repository, uninitialized

We detect this state when the active repository is empty, meaning the current project root has no Git repository.

<img width="451" alt="local-uninitialized" src="https://user-images.githubusercontent.com/17565/61296239-bdf77900-a7a7-11e9-8fcd-36340d2a3baa.png">

#### ...no dotcom repository

_Scenario:_ A user has begun a project locally and now wishes to put it under version control and share it on GitHub.

Clicking the "Publish GitHub repository" button opens the [Publish repository dialog](#publish-repository-dialog).

### Local repository, initialized, no dotcom remotes

We detect this state when the active repository is present but has no dotcom remotes.

<img width="460" alt="github tab, local repository with no GitHub remotes" src="https://user-images.githubusercontent.com/17565/61293864-a36ed100-a7a2-11e9-99b9-e7d920e7cc1f.png">

#### ...no dotcom repository

_Scenario:_ A user has begun a project locally and now wishes to share it on GitHub.

Clicking the "Publish on GitHub" button opens the [Publish repository dialog](#publish-repository-dialog).

### Local repository, initialized, dotcom remotes

This is the state we handle now: when an active repository is present and has one or more dotcom remotes.

## Clone repository dialog

The clone repository dialog begins in search mode. As you type within the text input, once more than three characters have been entered, repositories on GitHub matching the entered text appear in the result list below. Repositories may be identified by full clone URL, `owner/name` pair, or a unique substring of `owner/name`.

<img width="650" alt="clone dialog, empty search" src="https://user-images.githubusercontent.com/17565/57096303-f5937080-6ce2-11e9-8d71-e63677dcba7c.png">

<img width="650" alt="clone dialog, search results" src="https://user-images.githubusercontent.com/17565/57096339-07751380-6ce3-11e9-92ab-4714d6c9df8a.png">

### GitHub clone mode

Clicking on an entry in the search result list or entering the full clone URL of a GitHub repository changes the dialog to "GitHub clone" mode:

<img width="640" alt="clone dialog, GitHub mode" src="https://user-images.githubusercontent.com/17565/61302430-c2299380-a7b3-11e9-9dd6-9cb2cd55cf46.png">

Clicking the "advanced" arrow expands controls to customize cloning protocol and the created local remote name.

<img width="639" alt="clone dialog, GitHub mode, advanced section expanded" src="https://user-images.githubusercontent.com/17565/61302431-c2299380-a7b3-11e9-9399-8cd2f8132d33.png">

The "protocol" toggle is initialized to match the value of the `github.preferredRemoteProtocol` config setting. If the protocol is changed, the setting is changed to match.

### Non-GitHub clone mode

Entering the full clone URL of a non-GitHub repository changes the dialog to "non-GitHub clone" mode. Clicking the "advanced" arrow expands controls to customize the created local remote name. (The cloning protocol is inferred from the source URL.)

<img width="635" alt="clone dialog, non-GitHub mode" src="https://user-images.githubusercontent.com/17565/61302433-c2299380-a7b3-11e9-98db-b2eca8f7f76e.png">

### Common behavior

The "source remote name" input is pre-populated with the value of the Atom setting `github.cloneSourceRemoteName`. If it's changed to be empty, or to contain characters that are not valid in a git remote name, an error message is shown.

The clone destination path is pre-populated with the directory specified as `core.projectHome` in the user's Atom settings joined with the repository name. If the destination directory already exists and is nonempty, or is not writable by the current user, the path is considered invalid and an error message is shown. Clicking the button to the right of the destination path text field opens a system directory selection or creation dialog that populates the clone destination path with on accept.

The "Clone" button is enabled when:

* A clone source is uniquely identified, by GitHub `name/owner` or git URL;
* The "source remote name" input is populated with a valid git remote name;
* A valid path is entered within the clone destination path input.

Clicking the "Clone" button:

* Clones the repository from the chosen clone source to the clone destination path.
* Adds the clone destination path as a project root.
* Ensures that the clone destination is the active GitHub package context.
* Closes the "Clone repository" dialog.

## Create repository dialog

<img width="638" alt="create dialog" src="https://user-images.githubusercontent.com/17565/61298178-c356c280-a7ab-11e9-9d61-3a57ac51dd65.png">

The "owner" drop-down is populated with the user's account name and the list of organizations to which the authenticated user belongs. Organizations to which the user has insufficient permissions to create repositories are disabled with an explanatory suffix.

The "repository name" field is initially empty and focused. As the user types, an error message appears if a repository with the chosen name and owner already exists.

The clone destination path is pre-populated with the directory specified as `core.projectHome` in the user's Atom settings joined with the repository name. If the destination directory already exists and is nonempty, or is unwritable by the current user, the path is considered invalid and an error message is shown. Clicking the button to the right of the destination path text field opens a system directory selection or creation dialog that populates the clone destination path with on accept.

Clicking the "advanced" arrow expands controls to customize cloning protocol and the created local remote name. The "source remote name" input is pre-populated with the value of the Atom setting `github.cloneSourceRemoteName`. If it's changed to be empty, or to contain characters that are not valid in a git remote name, an error message is shown.

Clicking the "Create" button:

* Creates a repository on GitHub with the chosen owner and name.
* Clones the newly created repository to the clone destination path with its source remote set to the source remote name.
* Adds the clone destination path as a project root.
* Ensures that the clone destination path is the active GitHub package context.
* Closes the "Create repository" dialog.

## Publish repository dialog

<img width="632" alt="publish dialog" src="https://user-images.githubusercontent.com/17565/61298633-92c35880-a7ac-11e9-93a1-56703f0b2afa.png">

The major difference between this dialog and the [Create repository dialog](#create-repository-dialog) is that the local repository's path is displayed in a read-only input field and the directory selection button is disabled.

* The "source remote" field is invalid if a remote with the given name is already present in the local repository.

Clicking the "Publish" button also behaves slightly differently from the "Create" button:

* Initializes a git repository in the local repository path if it is not already a git repository.
* Creates a repository on GitHub with the chosen owner and name.
* Adds a remote with the specified "source remote name" and sets it to the clone URL of the newly created repository, respecting the https/ssh toggle.
* If a branch called `master` is present in the local repository, its push and fetch upstreams are configured to be the source remote.
* The local repository path is added as a project root if it is not already present.
* Ensures that the clone destination path is the active GitHub package context.
* Closes the "Publish repository" dialog.

## Improved branch publish behavior

If a remote is present in the current repository with a name matching the setting `github.cloneSourceRemoteName`, both clicking "publish" in the push-pull status bar tile and clicking a "publish ..." button in the GitHub tab push HEAD to the clone source remote instead of `origin`, even if the "chosen" remote differs.

If a multiple remotes are present in the current repository, and one is present with a name matching the setting `github.upstreamRemoteName` that has a recognized GitHub URL, it will be preferred as the default remote by the `GitTabContainer` component. Otherwise, if one is present with a name matching the setting `github.cloneSourceRemoteName` and a GitHub URL, that one will be used. Finally we'll fall back to our existing `RemoveSelectorView` menu.

When multiple remotes are present in the current repository and the push-pull status bar tile is in its "publish" state, the push-pull status bar tile's context menu includes a separate "Push" entry for each available remote.

**_Part 2 - Additional information_**

## :anchor: Drawbacks

Modal dialogs are disruptive to UX flow. You can't start creating a repository, have another thought and make a quick edit, then come back to it. This design uses a lot of them.

The "Create repository" flow is missing some of the functionality that the dotcom page has, like initializing a README and a license. We can make _some_ things nicer with the local context we have to work with - like guessing a repository name from the project directory - but we'd be unlikely to keep up with what's available on dotcom.

There is no "create repository" mutation available in the GraphQL API, so we'll need to use the REST API for that.

Some users don't use GitHub, but have remotes hosted elsewhere. We want to avoid being too invasive and annoying these users with prompts that will never apply to them.

## :thinking: Rationale and alternatives

We could open dotcom for repository creation, but then we would have no way to smoothly clone or connect the created repository.

## :question: Unresolved questions

* Are there better ways to intelligently identify which remotes should be used to push branches and which should be queried for pull requests?
* Are there different, common upstream-and-fork remote setups that these dialogs will support poorly?
* Is the language used in these dialogs and controls familiar enough to git newcomers?

## :warning: Out of Scope

This effort should not include:

* GitHub enterprise support. ( :sad: ) We have separate issues ([#270](https://github.com/atom/github/issues/270), [#919](https://github.com/atom/github/issues/919)) to track that, although this does complicate its eventual implementation, because the clone and create dialogs need to be Enterprise-aware.
* Workflows related to fork creation and management.
* General remote management ([#555](https://github.com/atom/github/issues/555)).

## :construction: Implementation phases

_TODO_

## :white_check_mark: Feature description for Atom release blog post

_TODO_
