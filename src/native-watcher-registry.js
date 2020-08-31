const path = require('path');

// Private: re-join the segments split from an absolute path to form another absolute path.
function absolute(...parts) {
  const candidate = path.join(...parts);
  return path.isAbsolute(candidate)
    ? candidate
    : path.join(path.sep, candidate);
}

// Private: Map userland filesystem watcher subscriptions efficiently to deliver filesystem change notifications to
// each watcher with the most efficient coverage of native watchers.
//
// * If two watchers subscribe to the same directory, use a single native watcher for each.
// * Re-use a native watcher watching a parent directory for a watcher on a child directory. If the parent directory
//   watcher is removed, it will be split into child watchers.
// * If any child directories already being watched, stop and replace them with a watcher on the parent directory.
//
// Uses a trie whose structure mirrors the directory structure.
class RegistryTree {
  // Private: Construct a tree with no native watchers.
  //
  // * `basePathSegments` the position of this tree's root relative to the filesystem's root as an {Array} of directory
  //   names.
  // * `createNative` {Function} used to construct new native watchers. It should accept an absolute path as an argument
  //   and return a new {NativeWatcher}.
  constructor(basePathSegments, createNative) {
    this.basePathSegments = basePathSegments;
    this.root = new RegistryNode();
    this.createNative = createNative;
  }

  // Private: Identify the native watcher that should be used to produce events at a watched path, creating a new one
  // if necessary.
  //
  // * `pathSegments` the path to watch represented as an {Array} of directory names relative to this {RegistryTree}'s
  //   root.
  // * `attachToNative` {Function} invoked with the appropriate native watcher and the absolute path to its watch root.
  add(pathSegments, attachToNative) {
    const absolutePathSegments = this.basePathSegments.concat(pathSegments);
    const absolutePath = absolute(...absolutePathSegments);

    const attachToNew = childPaths => {
      const native = this.createNative(absolutePath);
      const leaf = new RegistryWatcherNode(
        native,
        absolutePathSegments,
        childPaths
      );
      this.root = this.root.insert(pathSegments, leaf);

      const sub = native.onWillStop(() => {
        sub.dispose();
        this.root =
          this.root.remove(pathSegments, this.createNative) ||
          new RegistryNode();
      });

      attachToNative(native, absolutePath);
      return native;
    };

    this.root.lookup(pathSegments).when({
      parent: (parent, remaining) => {
        // An existing NativeWatcher is watching the same directory or a parent directory of the requested path.
        // Attach this Watcher to it as a filtering watcher and record it as a dependent child path.
        const native = parent.getNativeWatcher();
        parent.addChildPath(remaining);
        attachToNative(native, absolute(...parent.getAbsolutePathSegments()));
      },
      children: children => {
        // One or more NativeWatchers exist on child directories of the requested path. Create a new native watcher
        // on the parent directory, note the subscribed child paths, and cleanly stop the child native watchers.
        const newNative = attachToNew(children.map(child => child.path));

        for (let i = 0; i < children.length; i++) {
          const childNode = children[i].node;
          const childNative = childNode.getNativeWatcher();
          childNative.reattachTo(newNative, absolutePath);
          childNative.dispose();
          childNative.stop();
        }
      },
      missing: () => attachToNew([])
    });
  }

  // Private: Access the root node of the tree.
  getRoot() {
    return this.root;
  }

  // Private: Return a {String} representation of this tree's structure for diagnostics and testing.
  print() {
    return this.root.print();
  }
}

// Private: Non-leaf node in a {RegistryTree} used by the {NativeWatcherRegistry} to cover the allocated {Watcher}
// instances with the most efficient set of {NativeWatcher} instances possible. Each {RegistryNode} maps to a directory
// in the filesystem tree.
class RegistryNode {
  // Private: Construct a new, empty node representing a node with no watchers.
  constructor() {
    this.children = {};
  }

  // Private: Recursively discover any existing watchers corresponding to a path.
  //
  // * `pathSegments` filesystem path of a new {Watcher} already split into an Array of directory names.
  //
  // Returns: A {ParentResult} if the exact requested directory or a parent directory is being watched, a
  //   {ChildrenResult} if one or more child paths are being watched, or a {MissingResult} if no relevant watchers
  //   exist.
  lookup(pathSegments) {
    if (pathSegments.length === 0) {
      return new ChildrenResult(this.leaves([]));
    }

    const child = this.children[pathSegments[0]];
    if (child === undefined) {
      return new MissingResult(this);
    }

    return child.lookup(pathSegments.slice(1));
  }

  // Private: Insert a new {RegistryWatcherNode} into the tree, creating new intermediate {RegistryNode} instances as
  // needed. Any existing children of the watched directory are removed.
  //
  // * `pathSegments` filesystem path of the new {Watcher}, already split into an Array of directory names.
  // * `leaf` initialized {RegistryWatcherNode} to insert
  //
  // Returns: The root of a new tree with the {RegistryWatcherNode} inserted at the correct location. Callers should
  // replace their node references with the returned value.
  insert(pathSegments, leaf) {
    if (pathSegments.length === 0) {
      return leaf;
    }

    const pathKey = pathSegments[0];
    let child = this.children[pathKey];
    if (child === undefined) {
      child = new RegistryNode();
    }
    this.children[pathKey] = child.insert(pathSegments.slice(1), leaf);
    return this;
  }

  // Private: Remove a {RegistryWatcherNode} by its exact watched directory.
  //
  // * `pathSegments` absolute pre-split filesystem path of the node to remove.
  // * `createSplitNative` callback to be invoked with each child path segment {Array} if the {RegistryWatcherNode}
  //   is split into child watchers rather than removed outright. See {RegistryWatcherNode.remove}.
  //
  // Returns: The root of a new tree with the {RegistryWatcherNode} removed. Callers should replace their node
  // references with the returned value.
  remove(pathSegments, createSplitNative) {
    if (pathSegments.length === 0) {
      // Attempt to remove a path with child watchers. Do nothing.
      return this;
    }

    const pathKey = pathSegments[0];
    const child = this.children[pathKey];
    if (child === undefined) {
      // Attempt to remove a path that isn't watched. Do nothing.
      return this;
    }

    // Recurse
    const newChild = child.remove(pathSegments.slice(1), createSplitNative);
    if (newChild === null) {
      delete this.children[pathKey];
    } else {
      this.children[pathKey] = newChild;
    }

    // Remove this node if all of its children have been removed
    return Object.keys(this.children).length === 0 ? null : this;
  }

  // Private: Discover all {RegistryWatcherNode} instances beneath this tree node and the child paths
  //  that they are watching.
  //
  // * `prefix` {Array} of intermediate path segments to prepend to the resulting child paths.
  //
  // Returns: A possibly empty {Array} of `{node, path}` objects describing {RegistryWatcherNode}
  //  instances beneath this node.
  leaves(prefix) {
    const results = [];
    for (const p of Object.keys(this.children)) {
      results.push(...this.children[p].leaves(prefix.concat([p])));
    }
    return results;
  }

  // Private: Return a {String} representation of this subtree for diagnostics and testing.
  print(indent = 0) {
    let spaces = '';
    for (let i = 0; i < indent; i++) {
      spaces += ' ';
    }

    let result = '';
    for (const p of Object.keys(this.children)) {
      result += `${spaces}${p}\n${this.children[p].print(indent + 2)}`;
    }
    return result;
  }
}

// Private: Leaf node within a {NativeWatcherRegistry} tree. Represents a directory that is covered by a
// {NativeWatcher}.
class RegistryWatcherNode {
  // Private: Allocate a new node to track a {NativeWatcher}.
  //
  // * `nativeWatcher` An existing {NativeWatcher} instance.
  // * `absolutePathSegments` The absolute path to this {NativeWatcher}'s directory as an {Array} of
  //   path segments.
  // * `childPaths` {Array} of child directories that are currently the responsibility of this
  //   {NativeWatcher}, if any. Directories are represented as arrays of the path segments between this
  //   node's directory and the watched child path.
  constructor(nativeWatcher, absolutePathSegments, childPaths) {
    this.nativeWatcher = nativeWatcher;
    this.absolutePathSegments = absolutePathSegments;

    // Store child paths as joined strings so they work as Set members.
    this.childPaths = new Set();
    for (let i = 0; i < childPaths.length; i++) {
      this.childPaths.add(path.join(...childPaths[i]));
    }
  }

  // Private: Assume responsibility for a new child path. If this node is removed, it will instead
  // split into a subtree with a new {RegistryWatcherNode} for each child path.
  //
  // * `childPathSegments` the {Array} of path segments between this node's directory and the watched
  //   child directory.
  addChildPath(childPathSegments) {
    this.childPaths.add(path.join(...childPathSegments));
  }

  // Private: Stop assuming responsibility for a previously assigned child path. If this node is
  // removed, the named child path will no longer be allocated a {RegistryWatcherNode}.
  //
  // * `childPathSegments` the {Array} of path segments between this node's directory and the no longer
  //   watched child directory.
  removeChildPath(childPathSegments) {
    this.childPaths.delete(path.join(...childPathSegments));
  }

  // Private: Accessor for the {NativeWatcher}.
  getNativeWatcher() {
    return this.nativeWatcher;
  }

  // Private: Return the absolute path watched by this {NativeWatcher} as an {Array} of directory names.
  getAbsolutePathSegments() {
    return this.absolutePathSegments;
  }

  // Private: Identify how this watcher relates to a request to watch a directory tree.
  //
  // * `pathSegments` filesystem path of a new {Watcher} already split into an Array of directory names.
  //
  // Returns: A {ParentResult} referencing this node.
  lookup(pathSegments) {
    return new ParentResult(this, pathSegments);
  }

  // Private: Remove this leaf node if the watcher's exact path matches. If this node is covering additional
  // {Watcher} instances on child paths, it will be split into a subtree.
  //
  // * `pathSegments` filesystem path of the node to remove.
  // * `createSplitNative` callback invoked with each {Array} of absolute child path segments to create a native
  //   watcher on a subtree of this node.
  //
  // Returns: If `pathSegments` match this watcher's path exactly, returns `null` if this node has no `childPaths`
  // or a new {RegistryNode} on a newly allocated subtree if it did. If `pathSegments` does not match the watcher's
  // path, it's an attempt to remove a subnode that doesn't exist, so the remove call has no effect and returns
  // `this` unaltered.
  remove(pathSegments, createSplitNative) {
    if (pathSegments.length !== 0) {
      return this;
    } else if (this.childPaths.size > 0) {
      let newSubTree = new RegistryTree(
        this.absolutePathSegments,
        createSplitNative
      );

      for (const childPath of this.childPaths) {
        const childPathSegments = childPath.split(path.sep);
        newSubTree.add(childPathSegments, (native, attachmentPath) => {
          this.nativeWatcher.reattachTo(native, attachmentPath);
        });
      }

      return newSubTree.getRoot();
    } else {
      return null;
    }
  }

  // Private: Discover this {RegistryWatcherNode} instance.
  //
  // * `prefix` {Array} of intermediate path segments to prepend to the resulting child paths.
  //
  // Returns: An {Array} containing a `{node, path}` object describing this node.
  leaves(prefix) {
    return [{ node: this, path: prefix }];
  }

  // Private: Return a {String} representation of this watcher for diagnostics and testing. Indicates the number of
  // child paths that this node's {NativeWatcher} is responsible for.
  print(indent = 0) {
    let result = '';
    for (let i = 0; i < indent; i++) {
      result += ' ';
    }
    result += '[watcher';
    if (this.childPaths.size > 0) {
      result += ` +${this.childPaths.size}`;
    }
    result += ']\n';

    return result;
  }
}

// Private: A {RegistryNode} traversal result that's returned when neither a directory, its children, nor its parents
// are present in the tree.
class MissingResult {
  // Private: Instantiate a new {MissingResult}.
  //
  // * `lastParent` the final successfully traversed {RegistryNode}.
  constructor(lastParent) {
    this.lastParent = lastParent;
  }

  // Private: Dispatch within a map of callback actions.
  //
  // * `actions` {Object} containing a `missing` key that maps to a callback to be invoked when no results were returned
  //   by {RegistryNode.lookup}. The callback will be called with the last parent node that was encountered during the
  //   traversal.
  //
  // Returns: the result of the `actions` callback.
  when(actions) {
    return actions.missing(this.lastParent);
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
  constructor(parent, remainingPathSegments) {
    this.parent = parent;
    this.remainingPathSegments = remainingPathSegments;
  }

  // Private: Dispatch within a map of callback actions.
  //
  // * `actions` {Object} containing a `parent` key that maps to a callback to be invoked when a parent of a requested
  //   requested directory is returned by a {RegistryNode.lookup} call. The callback will be called with the
  //   {RegistryWatcherNode} instance and an {Array} of the {String} path segments that separate the parent node
  //   and the requested directory.
  //
  // Returns: the result of the `actions` callback.
  when(actions) {
    return actions.parent(this.parent, this.remainingPathSegments);
  }
}

// Private: A {RegistryNode.lookup} traversal result that's returned when one or more children of the requested
// directory are already being watched.
class ChildrenResult {
  // Private: Instantiate a new {ChildrenResult}.
  //
  // * `children` {Array} of the {RegistryWatcherNode} instances that were discovered.
  constructor(children) {
    this.children = children;
  }

  // Private: Dispatch within a map of callback actions.
  //
  // * `actions` {Object} containing a `children` key that maps to a callback to be invoked when a parent of a requested
  //   requested directory is returned by a {RegistryNode.lookup} call. The callback will be called with the
  //   {RegistryWatcherNode} instance.
  //
  // Returns: the result of the `actions` callback.
  when(actions) {
    return actions.children(this.children);
  }
}

// Private: Track the directories being monitored by native filesystem watchers. Minimize the number of native watchers
// allocated to receive events for a desired set of directories by:
//
// 1. Subscribing to the same underlying {NativeWatcher} when watching the same directory multiple times.
// 2. Subscribing to an existing {NativeWatcher} on a parent of a desired directory.
// 3. Replacing multiple {NativeWatcher} instances on child directories with a single new {NativeWatcher} on the
//    parent.
class NativeWatcherRegistry {
  // Private: Instantiate an empty registry.
  //
  // * `createNative` {Function} that will be called with a normalized filesystem path to create a new native
  //   filesystem watcher.
  constructor(createNative) {
    this.tree = new RegistryTree([], createNative);
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
  async attach(watcher) {
    const normalizedDirectory = await watcher.getNormalizedPathPromise();
    const pathSegments = normalizedDirectory
      .split(path.sep)
      .filter(segment => segment.length > 0);

    this.tree.add(pathSegments, (native, nativePath) => {
      watcher.attachToNative(native, nativePath);
    });
  }

  // Private: Generate a visual representation of the currently active watchers managed by this
  // registry.
  //
  // Returns a {String} showing the tree structure.
  print() {
    return this.tree.print();
  }
}

module.exports = { NativeWatcherRegistry };
