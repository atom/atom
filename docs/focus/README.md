# Near-term plans

Want to know what the Atom team is working on and what has our focus over the next few months? You've come to the right place. 🎯

In this directory, you'll find **weekly progress and planning updates** from the core Atom team at GitHub (e.g., [`2018-02-12.md`](2018-02-12.md)), and the sections below represent our **near-term roadmap**:

* [Atom IDE](#atom-ide)
* [GitHub package](#github-package)
* [Teletype](#teletype)
* [Tree-sitter](#tree-sitter)
* [Xray](#xray)

This roadmap is a [living document](https://en.wikipedia.org/wiki/Living_document): it represents our current plans, but we expect these plans to change from time to time.

---

# Atom IDE

## Roadmap

TODO

## Looking farther ahead

TODO

---

# GitHub package

Main repository: [atom/github](http://github.com/atom/github) (Atom package)

## Roadmap

Watch our progress on the [short-term roadmap project](https://github.com/atom/github/projects/8).

##### Recent commit history

_Near-term goal:_ An informational view that displays the most recent 1-3 commits beneath the mini commit message editor. Design and discussion in: [#554](https://github.com/atom/github/issues/554), [#86](https://github.com/atom/github/issues/86).

_Longer-term goals:_ Introduce interactivity to the commits shown in the recent history list. Right-click on the top click to amend it, or on prior commits to reset. Overhaul the "amend button" functionality and implementation.

##### Commit co-authoring

_Near-term goal:_ Allow users to specify co-authors when committing. Draw inspiration from [Desktop's implementation](https://github.com/desktop/desktop/pull/3879) for UI. Tracking issue: [#1309](https://github.com/atom/github/issues/1309).

_Longer-term goals:_ Expose an API so that packages like teletype can add portal participants to commits automatically. Tangentially related to [#1089](https://github.com/atom/github/issues/1089).

##### Pull request workflow - Create Pull Request

_Near-term goal:_ Add buttons in the GitHub panel to allow users to push any unpushed changes and open new pull requests. The "Open new pull request" button will link to the github.com compare view in browser. Open pull request: [#1138](https://github.com/atom/github/pull/1138).

_Longer-term goals:_ Offer a complete in-editor experience. Compose pull request titles and descriptions in the GitHub dock item. However, we wish to avoid needing replicating the full .com experience, so to specify labels, projects, or milestones, we will preserve the "navigate browser to compare view" functionality, and focus on text composition.

This will require building out UI in the GitHub panel and adding GraphQL API support to create pull requests.

UI/UX considerations include:

* Offer a pop-out editor to craft PR descriptions in a full pane, similar to the commit editor pop out.
* Allow the user to specify the merge target.
* Show a preview of the list of commits that would be introduced by PR.

##### Build stability

_Near-term goal:_ Fix that damn Travis hang documented in [#1119](https://github.com/atom/github/issues/1119). Resume the diagnosis work in [#1289](https://github.com/atom/github/pull/1289) and find a way to bring our build success rate back under control.

##### GPG and credential handler overhaul

_Near-term goals:_ Passphrase prompting from git credential helpers and GPG has been a significant pain point since public release; unsurprisingly, because those are the areas where we need to leverage binaries and configuration from the users' system if present.

* Implement a "remember me" checkbox backed by keytar. This is probably our top feature request. [#861](https://github.com/atom/github/issues/861)

_Longer-term goals:_ Finish the credential handler refactor begun in [#846](https://github.com/atom/github/pull/846) to handle GPG 1.x through 2.3 and include diagnostic logging and testing.

* Improve our handling of 2FA credentials. Ideally we could detect when a user has 2FA enabled and prompt for a one-time code. [#844](https://github.com/atom/github/issues/844)

## Looking farther ahead

In no particular order:

- Git Virtual File System support.
- Improved branch management. [#556](https://github.com/atom/github/issues/556)
- Introduce an overview dock item that summarizes and navigates to other functionality. [#1018](https://github.com/atom/github/issues/1018)
- Code review. [#269](https://github.com/atom/github/issues/269), [#268](https://github.com/atom/github/issues/268)
- `git log` pane.
- Merge or close pull requests.
- Browse and check out pull requests.

---

# Teletype

Main repository: [atom/teletype](http://github.com/atom/teletype) (Atom package)

## Roadmap

##### 1. ✅ Deliver a multi-file collaboration experience that meets 80% of the needs with 20% of the effort

- [x] Ship RFC-001 (https://github.com/atom/teletype/issues/268)

##### 2. Streamline collaboration set-up

Near-term goal: Encourage more collaboration by reducing barriers to entry.

Longer-term goal: Provide the world's fastest transition from "I want to collaborate" to "I am collaborating." 🚀

- [ ] Publish RFC (including a request for review from GitHub's Community and Safety team)
- [ ] Host can share a URL for the portal, and guests can follow the URL to instantly join the portal (https://github.com/atom/teletype/issues/109)
- [ ] Quickly collaborate with coworkers and friends (https://github.com/atom/teletype/issues/213, https://github.com/atom/teletype/issues/284)
    - You can view a list of past collaborators (i.e., a ["buddy list"](https://github.com/atom/teletype/issues/22) of sorts).
    - You can choose any online person in the buddy list and invite them to join your portal. They get a notification (or similar) informing them of the invitation, and they can choose to join the portal or not.
    - To prevent abuse/harassment, each time you join a portal via a URL or portal ID, Teletype adds the collaborators to your buddy list. You can directly invite anyone in your buddy list to join your portal, and anyone in your buddy list can invite you to a portal. You can remove anyone from your buddy list, at which point they can no longer _directly_ invite you to a portal.

##### 3. Nice bang-for-the-buck refinements

- [ ] Add a colored border around avatars that matches the cursor when that participant's tether is not retracted (https://github.com/atom/teletype/issues/338)

##### 4. Prioritized bugs

- [ ] Uncaught TypeError: Cannot match against 'undefined' or 'null' (https://github.com/atom/teletype/issues/233)

## Looking farther ahead

In no particular order:

- 🐛 Resolve or reduce impact of package initialization errors (https://github.com/atom/teletype/issues/266)
- 🐛 Surface uncaught errors in promises (https://github.com/atom/teletype/issues/298#issuecomment-355369327)
- ✨ Ensure remote buffers are updated when host renames files (https://github.com/atom/teletype/issues/147)
- 💖 In the buddy list, you can see which people are currently online (i.e., presence)
- 💖 Screen-sharing -- (We should prioritize screen-sharing above audio. We can keep using Slack/Skype/Zoom/Whatever for audio and use Atom for screen-sharing, whereas the opposite is not true; disabling audio on a Slack call would feel unintuitive.)
- 💖 Audio

---

# Tree-sitter

## Roadmap

TODO

## Looking farther ahead

TODO

---

# Xray

## Roadmap

TODO

## Looking farther ahead

TODO
