# Near-term plans

Want to know what the Atom team is working on and what has our focus over the next few months? You've come to the right place. 🎯

The sections below represent our **near-term roadmap**:

* [Atom Core](#atom-core)
* [Tree-sitter](#tree-sitter)

This roadmap is a [living document](https://en.wikipedia.org/wiki/Living_document): it represents our current plans, but we expect these plans to change from time to time.  Follow [this link](https://github.com/atom/atom/blob/4fbad81a7cd2f2e3925d7e920086bc1ebf2fe210/docs/focus/README.md) to see the previous major version of this roadmap.

You can find our bi-weekly iteration plans by searching for issues with the [`iteration-plan`](https://github.com/atom/atom/issues?q=is%3Aissue+is%3Aopen+sort%3Aupdated-desc+label%3Aiteration-plan) label.

---

## Atom Core

### Enable improvements to built-in packages to be delivered more frequently

- [ ] Investigate options for enabling more frequent updates to built-in packages either by shipping Atom more frequently or enabling out-of-band package updates
- [ ] Write and publish an RFC describing the proposed alternatives
- [ ] Implement the approved solution such that updates can start being delivered more frequently in the next few months

### Clarify issue and PR processes to streamline triage and contribution

- [ ] Refine process for triaging issues and PRs across Atom org repositories
- [ ] Publish a document that outlines merge requirements for PRs
- [ ] Triage existing/old issues and PRs across our repos weekly to clear out the backlog and get our open issues back to a manageable state
- [ ] Automate some aspects of Atom issue and PR triage with Probot, especially around ensuring PRs follow our contribution guidelines

### Streamline the Atom Core release process

- [ ] Implement "Publish" action to publish releases using Atom Release Publisher
- [ ] Complete automation of Linux package publishing
- [ ] Automate generation of draft release notes for new releases
- [ ] Investigate scheduled automation of Atom releases
- [ ] Update Atom release process documentation to reflect new release steps
- [ ] Move to VSTS CI to centralize all OS platform builds on a single service
- [ ] Prototype the use of Electron's new update service to see if it works for our needs

### [Stretch] Enable pre-transpilation of built-in packages to remove compiler dependencies from Atom

- [ ] Investigate approaches for pre-transpilation of Babel and TypeScript code in built-in packages
- [ ] Write an RFC that covers both on-demand transpilation and pre-transpilation for Atom builds

## Tree-sitter

### Finish work on Tree-sitter syntax highlighting, enable it by default

- [ ] Implement parsing on a background thread to ensure responsiveness
- [ ] Add a system for highlighting built-in functions and other things not distinguished in the AST.
- [ ] Add a system for parsing things like escape sequences in regexes, which are not identified in the AST.
- [ ] Document the new grammar format in the flight manual.
- [ ] Add a way of disabling Tree-sitter highlighting on a per-language basis.
- [ ] Enable Tree-sitter highlighting by default for one or more languages.
