# Near-term plans

Want to know what the Atom team is working on and what has our focus over the next few months? You've come to the right place. 🎯


This roadmap is a [living document](https://en.wikipedia.org/wiki/Living_document): it represents our current plans, but we expect these plans to change from time to time.  Follow [this link](https://github.com/atom/atom/blob/4fbad81a7cd2f2e3925d7e920086bc1ebf2fe210/docs/focus/README.md) to see the previous major version of this roadmap.

You can find our bi-weekly iteration plans by searching for issues with the [`iteration-plan`](https://github.com/atom/atom/issues?q=is%3Aissue+is%3Aopen+sort%3Aupdated-desc+label%3Aiteration-plan) label.

---

### Core package development is streamlined
Everything in Atom is a package. While this adds to its hackability, it is not always the best path forward. Consolidating packages as well as thinking about other ways to decrease friction for contributors will help pay down some of our tech debt in this area. More information regarding planning was provided in [this RFC](https://github.com/atom/atom/blob/master/docs/rfcs/003-consolidate-core-packages.md)

- [ ] Merge at least 22 packages in to atom/atom


### Improve Communication and Process

- [ ] Refine process for triaging issues and PRs across Atom org repositories
- [ ] Publish a document that outlines merge requirements for community PRs
- [ ] Reactive tickets are incorporated in to 80% of all sprints
- [ ] Automate some aspects of Atom issue and PR triage with Probot, especially around ensuring PRs follow our contribution guidelines

### Establish and Measure

- [ ] Implement Atom metrics dashboard that can be used to drive future decisions
- [ ] Determine what may be helpful to measure in the future building upon work [already in progress](http://blog.atom.io/2018/06/20/atom-metrics.html)
