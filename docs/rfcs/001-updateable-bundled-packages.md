# Updateable Bundled Packages

## Status

Proposed

## Summary

> One paragraph explanation of the feature.

This feature will enable an opt-in subset of bundled Atom packages to be updated with `apm` outside of the Atom release cycle.  This will enable users to receive new functionality and bug fixes for some bundled packages as regularly as needed without waiting for them to be included in a new Atom release.  This is especially important for packages like [GitHub](https://github.com/atom/github/) and  [Teletype](https://github.com/atom/teletype/) which provide essential Atom functionality and could be improved independently of Atom.

## Motivation

> Why are we doing this? What use cases does it support? What is the expected outcome?

Atom currently uses a monthly release cycle with staged Stable and Beta releases so that major issues get caught early in Beta before reaching the Stable release.  Because Atom releases updates monthly, this means that a new feature merged into `master` right after a new Atom release could take one month to reach the next Beta and then another month to reach Stable.

Since a large part of Atom's built-in functionality is provided by bundled packages, it makes sense to allow some of those packages to be updated independently of Atom's monthly release cycle so that users can receive new features and fixes whenever they become available.

The primary use case for this improvement is enabling the GitHub package to ship improvements more frequently than Atom's release cycle since many of its improvements can be done without changes to Atom itself.  If this approach is proven to work well for the GitHub package, we might also consider using it to ship Teletype as a bundled Atom package.

## Explanation

> Explain the proposal as if it was already implemented in Atom and you were describing it to an Atom user. That generally means:
> - Introducing new named concepts.
> - Explaining the feature largely in terms of examples.
> - Explaining any changes to existing workflows.

Bundled packages are treated differently than community packages that you can install using `apm`:

- You are not prompted to update them when new versions are released on `apm`
- `apm` will warn you at the command line when you try to install or update a bundled package
- If a user intentionally installs a bundled package from `apm` the [Dalek package](https://github.com/atom/dalek/) will show a warning in the "deprecations" view asking the user to remove the offending package

Despite all this, if the user *does* install a bundled package using `apm`, it will be loaded into the editor and updated dutifully as releases occur.

### Implementation Details

Because the necessary infrastructure is already in place to enable updates to bundled packages using `apm`, the only work required is to provide a way for packages to opt in to this behavior and for `apm` to include those packages in its update checks if they haven't already been installed in the user's packages folder.

Any bundled Atom package will be able to opt in to updates by adding `"updateable": true` to its `package.json` file.  This will cause `apm` to consider it as part of the list of packages it checks for updates.  If a community (non-bundled) package sets this field to `true` or `false` it will be ignored as it's only relevant to bundled packages.

`apm` will be updated to include the list of bundled packages with `"updateable": true` set in their `package.json` so that the user will be notified of new package versions that support the engine version of their current Atom build.

### User Experience Examples

1. The user downloads Atom 1.28.0 from atom.io which includes GitHub package version 0.15.0.  After Atom 1.28.0 was released, a hotfix release was shipped for the GitHub package as 0.15.1.  When the user installs and starts Atom, they are prompted to install the update to the GitHub package.

2. The user downloads and installs Atom 1.28.0 from atom.io which includes GitHub package version 0.15.0.  Two weeks later, GitHub package 0.16.0 is released with a few new features.  The user is prompted to update to the new version and gets the new features even though Atom 1.29.0 hasn't been released yet.

3. In the future, a user has an old install of Atom 1.28.0 and waits a long time between installing Atom updates.  The GitHub package releases version 0.25.0 but the user is not prompted to install it because the GitHub package has set `engines` in `package.json` to restrict to Atom 1.32.0 and above.

### Rules for Updateable Bundled Packages

Any package that opts into this behavior must follow one rule: **its `engines` field must be regularly updated to reflect the necessary Atom version for the Atom, Electron, and Node.js APIs used in the package**.  This field defines the range of Atom versions in which the package is expected to work.  The field should always be set to the lowest possible Atom version that the package supports.

If a package wants to use API features of a newer version of Atom while still supporting older Atom versions, it must do so in a way that is aware of the user's version and adjust itself accordingly.

## Drawbacks

> Why should we *not* do this?

The primary drawback of this approach is that updateable bundled packages might exhibit problems on older Atom versions due to missing or changed APIs in Atom, Electron, or Node.js.  The solution for these packages is to keep their `engines` field updated appropriately, but there's still a chance that some updates will slip through without the necessary engine version changes.

One other possible drawback is that an updated version of a bundled package might not be compatible across two different Atom channels.  For example, if the user installs a new update to a bundled package that only supports the current Atom Beta release or higher, the user will no longer have access to that package if they open Atom Stable.

However, this drawback is no different than what the user would face today installing a community package under the same circumstances, so this could be considered a general problem in the Atom package ecosystem.

## Rationale and alternatives

> - Why is this approach the best in the space of possible approaches?
> - What other approaches have been considered and what is the rationale for not choosing them?
> - What is the impact of not doing this?

This is the best approach for updating bundled packages because it allows those packages to take control of their own release cycle so long as they manage their Atom engine version correctly.  It also does so in a way that allows us to decide which packages can be updated independently, reducing the likelihood of problems for users.

The primary alternative to this approach is to speed up the Atom release cycle so that bundled Atom package updates will reach users more frequently.  This approach will be investigated independently of this RFC as it may still be valuable even with updateable bundled packages.

## Unresolved questions

> - What unresolved questions do you expect to resolve through the RFC process before this gets merged?

Is it enough to just depend on the `engines` field of `package.json` to protect users from installing a package update that doesn't work with their version of Atom?

Is `updateable` the right name for the field in `package.json`?  Is there a clearer name?

> - What unresolved questions do you expect to resolve through the implementation of this feature before it is released in a new version of Atom?

Can package authors ship updates to stable-only and beta-only versions of their packages simultaneously?  For example, can the GitHub package keep shipping hotfixes to 0.14.x which targets Atom >=1.27.0 while also shipping updates to 0.15.x which targets >=1.28.0?

> - What related issues do you consider out of scope for this RFC that could be addressed in the future independently of the solution that comes out of this RFC?

One issue that's out of scope for this RFC is how we ship new features and fixes to the core components of Atom (not its bundled packages) more frequently.  There are two options we can investigate to accomplish this:

- **Ship Atom updates more frequently, possibly every two weeks**

- **Introduce a channel for nightly builds which surface the latest changes every day**

Both of these possibilities will be covered in future RFCs as they could be implemented independently of the feature described in this RFC.
