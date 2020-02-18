# GitHub integration

## Why does this exist

The primary purposes of the GitHub integration are:

1. **Reduce context switching and friction** from _unnecessary_ trips to the browser and back. Shifting to the browser should occur at natural inflection points within a developer's workflow.
2. **Bring asynchronous collaboration closer to your code.**
3. **Notifications of events** such as new comments or build status. We want to surface information in a timely and convenient manner.
4. **Graceful introduction to sharing and working on GitHub.** Include _gentle_ nudges toward best practices and commonly-used conventions, without being overly prescriptive.
5. **Provide features that aren't possible anywhere else** because of the context and presence that the package has.

## Boundaries

This package should _not_ attempt to replicate the design of github.com within your editor. It turns out that github.com already exists! Also, a much larger number of people are working on it than are working on this package, so trying to stay up to date with it is... unrealistic.

Instead, we want to prioritize features that are _enhanced by the state and context that are uniquely available within Atom_. The package can take advantage of its knowledge of the repository, branch, file, and so on that you're looking at :sparkles: right now :sparkles: to save you time.

We will also consider functionality that allows you to _defer and stage actions to complete in more detail later with the full browser experience_. By allowing you to batch actions that should naturally occur on the website into longer sessions, we can help provide longer sessions focused on your code within the editor.
