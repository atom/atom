/** @babel */

import path from 'path'

// Private: Non-leaf node in a tree used by the {NativeWatcherRegistry} to cover the allocated {Watcher} instances with
// the most efficient set of {NativeWatcher} instances possible. Each {RegistryNode} maps to a directory in the
// filesystem tree.
class RegistryNode {

  // Private: Construct a new, empty node representing a node with no watchers.
  constructor () {
    this.children = {}
  }

  // Private: Recursively discover any existing watchers corresponding to a path.
  //
  // * `pathSegments` filesystem path of a new {Watcher} already split into an Array of directory names.
  //
  // Returns: A {ParentResult} if the exact requested directory or a parent directory is being watched, a
  //   {ChildrenResult} if one or more child paths are being watched, or a {MissingResult} if no relevant watchers
  //   exist.
  lookup (pathSegments) {
    if (pathSegments.length === 0) {
      return new ChildrenResult(this.leaves())
    }

    const child = this.children[pathSegments[0]]
    if (child === undefined) {
      return new MissingResult(this)
    }

    return child.lookup(pathSegments.slice(1))
  }

  // Private: Insert a new {RegistryWatcherNode} into the tree, creating new intermediate {RegistryNode} instances as
  // needed. Any existing children of the watched directory are removed.
  //
  // * `pathSegments` filesystem path of the new {Watcher}, already split into an Array of directory names.
  // * `leaf` initialized {RegistryWatcherNode} to insert
  //
  // Returns: The root of a new tree with the {RegistryWatcherNode} inserted at the correct location. Callers should
  // replace their node references with the returned value.
  insert (pathSegments, leaf) {
    if (pathSegments.length === 0) {
      return leaf
    }

    const pathKey = pathSegments[0]
    let child = this.children[pathKey]
    if (child === undefined) {
      child = new RegistryNode()
    }
    this.children[pathKey] = child.insert(pathSegments.slice(1), leaf)
    return this
  }

  // Private: Remove a {RegistryWatcherNode} by the exact watched directory.
  //
  // * `pathSegments` absolute pre-split filesystem path of the node to remove.
  //
  // Returns: The root of a new tree with the {RegistryWatcherNode} removed. Callers should replace their node
  // references with the returned value.
  remove (pathSegments) {
    if (pathSegments.length === 0) {
      // Attempt to remove a path with child watchers. Do nothing.
      return this
    }

    const pathKey = pathSegments[0]
    const child = this.children[pathKey]
    if (child === undefined) {
      // Attempt to remove a path that isn't watched. Do nothing.
      return this
    }

    // Recurse
    const newChild = child.remove(pathSegments.slice(1))
    if (newChild === null) {
      delete this.children[pathKey]
    } else {
      this.children[pathKey] = newChild
    }

    // Remove this node if all of its children have been removed
    return Object.keys(this.children).length === 0 ? null : this
  }

  // Private: Discover all {RegistryWatcherNode} instances beneath this tree node.
  //
  // Returns: A possibly empty {Array} of {RegistryWatcherNode} instances that are the descendants of this node.
  leaves () {
    const results = []
    for (const p of Object.keys(this.children)) {
      results.push(...this.children[p].leaves())
    }
    return results
  }
}

// Private: Leaf node within a {NativeWatcherRegistry} tree. Represents a directory that is covered by a
// {NativeWatcher}.
class RegistryWatcherNode {

  // Private: Allocate a new node to track a {NativeWatcher}.
  //
  // * `nativeWatcher` An existing {NativeWatcher} instance.
  constructor (nativeWatcher) {
    this.nativeWatcher = nativeWatcher
  }

  // Private: Accessor for the {NativeWatcher}.
  getNativeWatcher () {
    return this.nativeWatcher
  }

  // Private: Identify how this watcher relates to a request to watch a directory tree.
  //
  // * `pathSegments` filesystem path of a new {Watcher} already split into an Array of directory names.
  //
  // Returns: A {ParentResult} referencing this node.
  lookup (pathSegments) {
    return new ParentResult(this, pathSegments)
  }

  // Private: Remove this leaf node if the watcher's exact path matches.
  //
  // * `pathSegments` filesystem path of the node to remove.
  //
  // Returns: {null} if the `pathSegments` are an exact match, {this} otherwise.
  remove (pathSegments) {
    return pathSegments.length === 0 ? null : this
  }

  // Private: Discover this {RegistryWatcherNode} instance.
  //
  // Returns: An {Array} containing this node.
  leaves () {
    return [this]
  }
}

// Private: A {RegisteryNode} traversal result that's returned when neither a directory, its children, nor its parents
// are present in the tree.
class MissingResult {
  // Private: Instantiate a new {MissingResult}.
  //
  // * `lastParent` the final succesfully traversed {RegistryNode}.
  constructor (lastParent) {
    this.lastParent = lastParent
  }

  // Private: Dispatch within a map of callback actions.
  //
  // * `actions` {Object} containing a `missing` key that maps to a callback to be invoked when no results were returned
  //   by {RegistryNode.lookup}. The callback will be called with the last parent node that was encountered during the
  //   traversal.
  //
  // Returns: the result of the `actions` callback.
  when (actions) {
    return actions.missing(this.lastParent)
  }
}

// Private: A {RegistryNode.lookup} traversal result that's returned when a parent or an exact match of the requested
// directory is being watched by an existing {RegistryWatcherNode}.
class ParentResult {

  // Private: Instantiate a new {ParentResult}.
  //
  // * `parent` the {RegistryWatcherNode} that was discovered.
  // * `remainingPathSegments` an {Array} of the directories that lie between the leaf node's watched directory and
  //   the requested directory. This will be empty for exact matches.
  constructor (parent, remainingPathSegments) {
    this.parent = parent
    this.remainingPathSegments = remainingPathSegments
  }

  // Private: Dispatch within a map of callback actions.
  //
  // * `actions` {Object} containing a `parent` key that maps to a callback to be invoked when a parent of a requested
  //   requested directory is returned by a {RegistryNode.lookup} call. The callback will be called with the
  //   {RegistryWatcherNode} instance and an {Array} of the {String} path segments that separate the parent node
  //   and the requested directory.
  //
  // Returns: the result of the `actions` callback.
  when (actions) {
    return actions.parent(this.parent, this.remainingPathSegments)
  }
}

// Private: A {RegistryNode.lookup} traversal result that's returned when one or more children of the requested
// directory are already being watched.
class ChildrenResult {

  // Private: Instantiate a new {ChildrenResult}.
  //
  // * `children` {Array} of the {RegistryWatcherNode} instances that were discovered.
  constructor (children) {
    this.children = children
  }

  // Private: Dispatch within a map of callback actions.
  //
  // * `actions` {Object} containing a `children` key that maps to a callback to be invoked when a parent of a requested
  //   requested directory is returned by a {RegistryNode.lookup} call. The callback will be called with the
  //   {RegistryWatcherNode} instance.
  //
  // Returns: the result of the `actions` callback.
  when (actions) {
    return actions.children(this.children)
  }
}

// Private: Track the directories being monitored by native filesystem watchers. Minimize the number of native watchers
// allocated to receive events for a desired set of directories by:
//
// 1. Subscribing to the same underlying {NativeWatcher} when watching the same directory multiple times.
// 2. Subscribing to an existing {NativeWatcher} on a parent of a desired directory.
// 3. Replacing multiple {NativeWatcher} instances on child directories with a single new {NativeWatcher} on the
//    parent.
export default class NativeWatcherRegistry {

  // Private: Instantiate an empty registry.
  //
  // * `createNative` {Function} that will be called with a normalized filesystem path to create a new native
  //   filesystem watcher.
  constructor (createNative) {
    this.tree = new RegistryNode()
    this.createNative = createNative
  }

  // Private: Attach a watcher to a directory, assigning it a {NativeWatcher}. If a suitable {NativeWatcher} already
  // exists, it will be attached to the new {Watcher} with an appropriate subpath configuration. Otherwise, the
  // `createWatcher` callback will be invoked to create a new {NativeWatcher}, which will be registered in the tree
  // and attached to the watcher.
  //
  // If any pre-existing child watchers are removed as a result of this operation, {NativeWatcher.onWillReattach} will
  // be broadcast on each with the new parent watcher as an event payload to give child watchers a chance to attach to
  // the new watcher.
  //
  // * `watcher` an unattached {Watcher}.
  async attach (watcher) {
    const normalizedDirectory = await watcher.getNormalizedPathPromise()
    const pathSegments = normalizedDirectory.split(path.sep).filter(segment => segment.length > 0)

    const attachToNew = () => {
      const native = this.createNative(normalizedDirectory)
      const leaf = new RegistryWatcherNode(native)
      this.tree = this.tree.insert(pathSegments, leaf)

      const sub = native.onWillStop(() => {
        this.tree = this.tree.remove(pathSegments) || new RegistryNode()
        sub.dispose()
      })

      watcher.attachToNative(native, '')

      return native
    }

    this.tree.lookup(pathSegments).when({
      parent: (parent, remaining) => {
        // An existing NativeWatcher is watching a parent directory of the requested path. Attach this Watcher to
        // it as a filtering watcher.
        const native = parent.getNativeWatcher()
        const subpath = remaining.length === 0 ? '' : path.join(...remaining)

        watcher.attachToNative(native, subpath)
      },
      children: children => {
        const newNative = attachToNew()

        // One or more NativeWatchers exist on child directories of the requested path.
        for (let i = 0; i < children.length; i++) {
          const child = children[i]
          const childNative = child.getNativeWatcher()
          childNative.reattachTo(newNative, normalizedDirectory)
          childNative.dispose()

          // Don't await this Promise. Subscribers can listen for `onDidStop` to be notified if they choose.
          childNative.stop()
        }
      },
      missing: attachToNew
    })
  }
}
