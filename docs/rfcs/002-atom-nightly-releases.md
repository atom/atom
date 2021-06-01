# Atom Nightly Releases

## Status

Implemented in PR [#17538](https://github.com/atom/atom/pull/17538)

## Summary

This RFC proposes that Atom add a third official release channel which delivers new builds of Atom nightly from the `master` branch.  Nightly releases will allow new improvements to reach users long before a new Stable or Beta release is shipped.  This effort will also give us the opportunity to experiment with new release automation strategies that could eventually be used to speed up the Stable and Beta release cadence.

## Motivation

Atom currently uses a monthly release cycle with staged Stable and Beta releases so that major issues get caught early in Beta before reaching the Stable release.  Because Atom releases updates monthly, this means that a new feature merged into `master` right after a new Atom release could take one month to reach the next Beta and then another month to reach Stable.

This release process works well for delivering stable improvements to users on a regular basis but it results in friction for users who want to try out the latest Atom improvements and provide feedback.  If we deliver a nightly release channel, it will be possible to deliver new features and bug fixes on a regular basis and get valuable feedback to guide our work.

Today, a bleeding-edge user must manually pull Atom's `master` branch and compile their own build.  There is a source of `dev` builds from `master` across our CI services but those aren't made available to users as an official distribution.

## Explanation

A user who wants to use the latest improvements to Atom each day can go to atom.io, download the Atom Nightly release, and install it on their machine.  This release can be installed alongside Atom Stable and Atom Beta.

Each night when there are new commits to Atom's `master` branch, a scheduled CI build creates a new Atom Nightly release with packages for Windows, macOS, and Linux.  These packages are automatically uploaded to a new GitHub release on the `atom/atom-nightly-releases` repository using a monotonically-increasing nightly version based off of the version in `master` (e.g. `v1.29.0-nightly1`).

Every 4 hours, an Atom Nightly release installed on Windows or macOS checks for a new update by consulting Electron's [update.electronjs.org](update-electron) service.  If a new update is available, it is downloaded in the background and the user is notified to restart Atom once it's complete.  This update flow is the same as what users experience in Atom Stable or Beta releases but updates occur more frequently.

Linux users must manually download nightly releases for now as there isn't an easy way to automatically install new updates across the various Linux distributions.  We may consider providing updatable [AppImage](http://appimage.org/) packages in the future; this will be proposed in a separate RFC.

## Drawbacks

There isn't a major downside to this effort since it would run in parallel to the existing Atom release process without affecting it.

## Rationale and alternatives

This is a useful approach because it allows us to achieve a much more rapid feedback loop with highly engaged users to ensure that Atom is improving regularly.  It's the best approach because it allows us to get rapid feedback without sacrificing the stability of the Stable and Beta releases.

Another option is to speed up Atom's release cadence to ship Stable and Beta every two weeks (or more regularly).  This approach could shorten our feedback loop but at the expense of greater instability since new improvements would not have as much time to be polished before release.

The impact of not taking this approach is that we continue to have to wait 1-2 months to get feedback from users about new features or bugs in Stable and Beta releases.

## Unresolved questions

- **What should we call this release channel?**

  Some ideas:

  - Atom Nightly
  - Atom Reactor
  - Atom Dev - Currently the name of dev builds but it might make sense to leave that for "normal" builds from `master`

  According to a [Twitter poll](https://twitter.com/daviwil/status/1006545552987701248) with about 1,600 responses, 50% of the voters chose "Atom Nightly".  The final name will be determined before launch.

- **Will Electron's new autoUpdate service work for all Atom releases?**

  One outcome of this effort is to use the new [update.electronjs.org](update-electron) service for Atom's update checks so that we can deprecate on our own custom update service.  Building the Nightly channel on this service will allow us to evaluate it to see if it meets the needs of the Stable and Beta channels.

[update-electron]: https://github.com/electron/update.electronjs.org
