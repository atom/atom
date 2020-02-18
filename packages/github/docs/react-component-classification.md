# React Component Classification

This is a high-level summary of the organization and implementation of our React components.

## Items

**Items** are intended to be used as top-level components within subtrees that are rendered into some [Portal](https://reactjs.org/docs/portals.html) and passed to the Atom API, like pane items, dock items, or tooltips. They are mostly responsible for implementing the [Atom "item" contract](https://github.com/atom/atom/blob/a3631f0dafac146185289ac5e37eaff17b8b0209/src/workspace.js#L29-L174).

These live within [`lib/items/`](/lib/items), are tested within [`test/items/`](/test/items), and are named with an `Item` suffix. Examples: `PullRequestDetailItem`, `ChangedFileItem`.

## Containers

**Containers** are responsible for statefully fetching asynchronous data and rendering their children appropriately. They handle the logic for how subtrees handle loading operations (displaying a loading spinner, passing null objects to their children) and how errors are reported. Containers should mostly be thin wrappers around things like [`<ObserveModel>`](/lib/views/observe-model.js), [`<QueryRenderer>`](https://facebook.github.io/relay/docs/en/query-renderer.html), or [context](https://reactjs.org/docs/context.html) providers

 These live within [`lib/containers`](/lib/containers), are tested within [`test/containers`](/test/containers), and are named with a `Container` suffix. Examples: `PrInfoContainer`, `GitTabContainer`.

## Controllers

**Controllers** are responsible for implementing action methods and maintaining logical application state for some subtree of components. A Controller's `render()` method should only consist of passing props to a single child, usually a View.

These live within [`lib/controllers`](/lib/controllers), are tested within [`test/controllers`](/test/controllers), and are named with a `Controller` suffix. Examples: `GitTabController`, `RecentCommitsController`, `ConflictController`.

## Views

**Views** are responsible for accepting props and rendering a DOM tree. View components should contain very few non-render methods and little state.

These live within [`lib/views`](/lib/views), are tested within [`test/views`](/test/views), and are named with a `View` suffix. Examples: `GitTabView`, `GithubLoginView`.
