const fs = require('fs');
const path = require('path');

const { Emitter, Disposable, CompositeDisposable } = require('event-kit');
const nsfw = require('@atom/nsfw');
const watcher = require('@atom/watcher');
const { NativeWatcherRegistry } = require('./native-watcher-registry');

// Private: Associate native watcher action flags with descriptive String equivalents.
const ACTION_MAP = new Map([
  [nsfw.actions.MODIFIED, 'modified'],
  [nsfw.actions.CREATED, 'created'],
  [nsfw.actions.DELETED, 'deleted'],
  [nsfw.actions.RENAMED, 'renamed']
]);

// Private: Possible states of a {NativeWatcher}.
const WATCHER_STATE = {
  STOPPED: Symbol('stopped'),
  STARTING: Symbol('starting'),
  RUNNING: Symbol('running'),
  STOPPING: Symbol('stopping')
};

// Private: Interface with and normalize events from a filesystem watcher implementation.
class NativeWatcher {
  // Private: Initialize a native watcher on a path.
  //
  // Events will not be produced until {start()} is called.
  constructor(normalizedPath) {
    this.normalizedPath = normalizedPath;
    this.emitter = new Emitter();
    this.subs = new CompositeDisposable();

    this.state = WATCHER_STATE.STOPPED;

    this.onEvents = this.onEvents.bind(this);
    this.onError = this.onError.bind(this);
  }

  // Private: Begin watching for filesystem events.
  //
  // Has no effect if the watcher has already been started.
  async start() {
    if (this.state !== WATCHER_STATE.STOPPED) {
      return;
    }
    this.state = WATCHER_STATE.STARTING;

    await this.doStart();

    this.state = WATCHER_STATE.RUNNING;
    this.emitter.emit('did-start');
  }

  doStart() {
    return Promise.reject(new Error('doStart() not overridden'));
  }

  // Private: Return true if the underlying watcher is actively listening for filesystem events.
  isRunning() {
    return this.state === WATCHER_STATE.RUNNING;
  }

  // Private: Register a callback to be invoked when the filesystem watcher has been initialized.
  //
  // Returns: A {Disposable} to revoke the subscription.
  onDidStart(callback) {
    return this.emitter.on('did-start', callback);
  }

  // Private: Register a callback to be invoked with normalized filesystem events as they arrive. Starts the watcher
  // automatically if it is not already running. The watcher will be stopped automatically when all subscribers
  // dispose their subscriptions.
  //
  // Returns: A {Disposable} to revoke the subscription.
  onDidChange(callback) {
    this.start();

    const sub = this.emitter.on('did-change', callback);
    return new Disposable(() => {
      sub.dispose();
      if (this.emitter.listenerCountForEventName('did-change') === 0) {
        this.stop();
      }
    });
  }

  // Private: Register a callback to be invoked when a {Watcher} should attach to a different {NativeWatcher}.
  //
  // Returns: A {Disposable} to revoke the subscription.
  onShouldDetach(callback) {
    return this.emitter.on('should-detach', callback);
  }

  // Private: Register a callback to be invoked when a {NativeWatcher} is about to be stopped.
  //
  // Returns: A {Disposable} to revoke the subscription.
  onWillStop(callback) {
    return this.emitter.on('will-stop', callback);
  }

  // Private: Register a callback to be invoked when the filesystem watcher has been stopped.
  //
  // Returns: A {Disposable} to revoke the subscription.
  onDidStop(callback) {
    return this.emitter.on('did-stop', callback);
  }

  // Private: Register a callback to be invoked with any errors reported from the watcher.
  //
  // Returns: A {Disposable} to revoke the subscription.
  onDidError(callback) {
    return this.emitter.on('did-error', callback);
  }

  // Private: Broadcast an `onShouldDetach` event to prompt any {Watcher} instances bound here to attach to a new
  // {NativeWatcher} instead.
  //
  // * `replacement` the new {NativeWatcher} instance that a live {Watcher} instance should reattach to instead.
  // * `watchedPath` absolute path watched by the new {NativeWatcher}.
  reattachTo(replacement, watchedPath, options) {
    this.emitter.emit('should-detach', { replacement, watchedPath, options });
  }

  // Private: Stop the native watcher and release any operating system resources associated with it.
  //
  // Has no effect if the watcher is not running.
  async stop() {
    if (this.state !== WATCHER_STATE.RUNNING) {
      return;
    }
    this.state = WATCHER_STATE.STOPPING;
    this.emitter.emit('will-stop');

    await this.doStop();

    this.state = WATCHER_STATE.STOPPED;

    this.emitter.emit('did-stop');
  }

  doStop() {
    return Promise.resolve();
  }

  // Private: Detach any event subscribers.
  dispose() {
    this.emitter.dispose();
  }

  // Private: Callback function invoked by the native watcher when a debounced group of filesystem events arrive.
  // Normalize and re-broadcast them to any subscribers.
  //
  // * `events` An Array of filesystem events.
  onEvents(events) {
    this.emitter.emit('did-change', events);
  }

  // Private: Callback function invoked by the native watcher when an error occurs.
  //
  // * `err` The native filesystem error.
  onError(err) {
    this.emitter.emit('did-error', err);
  }
}

// Private: Emulate a "filesystem watcher" by subscribing to Atom events like buffers being saved. This will miss
// any changes made to files outside of Atom, but it also has no overhead.
class AtomNativeWatcher extends NativeWatcher {
  async doStart() {
    const getRealPath = givenPath => {
      if (!givenPath) {
        return Promise.resolve(null);
      }

      return new Promise(resolve => {
        fs.realpath(givenPath, (err, resolvedPath) => {
          err ? resolve(null) : resolve(resolvedPath);
        });
      });
    };

    this.subs.add(
      atom.workspace.observeTextEditors(async editor => {
        let realPath = await getRealPath(editor.getPath());
        if (!realPath || !realPath.startsWith(this.normalizedPath)) {
          return;
        }

        const announce = (action, oldPath) => {
          const payload = { action, path: realPath };
          if (oldPath) payload.oldPath = oldPath;
          this.onEvents([payload]);
        };

        const buffer = editor.getBuffer();

        this.subs.add(buffer.onDidConflict(() => announce('modified')));
        this.subs.add(buffer.onDidReload(() => announce('modified')));
        this.subs.add(
          buffer.onDidSave(event => {
            if (event.path === realPath) {
              announce('modified');
            } else {
              const oldPath = realPath;
              realPath = event.path;
              announce('renamed', oldPath);
            }
          })
        );

        this.subs.add(buffer.onDidDelete(() => announce('deleted')));

        this.subs.add(
          buffer.onDidChangePath(newPath => {
            if (newPath !== this.normalizedPath) {
              const oldPath = this.normalizedPath;
              this.normalizedPath = newPath;
              announce('renamed', oldPath);
            }
          })
        );
      })
    );

    // Giant-ass brittle hack to hook files (and eventually directories) created from the TreeView.
    const treeViewPackage = await atom.packages.getLoadedPackage('tree-view');
    if (!treeViewPackage) return;
    await treeViewPackage.activationPromise;
    const treeViewModule = treeViewPackage.mainModule;
    if (!treeViewModule) return;
    const treeView = treeViewModule.getTreeViewInstance();

    const isOpenInEditor = async eventPath => {
      const openPaths = await Promise.all(
        atom.workspace
          .getTextEditors()
          .map(editor => getRealPath(editor.getPath()))
      );
      return openPaths.includes(eventPath);
    };

    this.subs.add(
      treeView.onFileCreated(async event => {
        const realPath = await getRealPath(event.path);
        if (!realPath) return;

        this.onEvents([{ action: 'added', path: realPath }]);
      })
    );

    this.subs.add(
      treeView.onEntryDeleted(async event => {
        const realPath = await getRealPath(event.path);
        if (!realPath || (await isOpenInEditor(realPath))) return;

        this.onEvents([{ action: 'deleted', path: realPath }]);
      })
    );

    this.subs.add(
      treeView.onEntryMoved(async event => {
        const [realNewPath, realOldPath] = await Promise.all([
          getRealPath(event.newPath),
          getRealPath(event.initialPath)
        ]);
        if (
          !realNewPath ||
          !realOldPath ||
          (await isOpenInEditor(realNewPath)) ||
          (await isOpenInEditor(realOldPath))
        )
          return;

        this.onEvents([
          { action: 'renamed', path: realNewPath, oldPath: realOldPath }
        ]);
      })
    );
  }
}

// Private: Implement a native watcher by translating events from an NSFW watcher.
class NSFWNativeWatcher extends NativeWatcher {
  async doStart(rootPath, eventCallback, errorCallback) {
    const handler = events => {
      this.onEvents(
        events.map(event => {
          const action =
            ACTION_MAP.get(event.action) || `unexpected (${event.action})`;
          const payload = { action };

          if (event.file) {
            payload.path = path.join(event.directory, event.file);
          } else {
            payload.oldPath = path.join(
              event.directory,
              typeof event.oldFile === 'undefined' ? '' : event.oldFile
            );
            payload.path = path.join(
              event.directory,
              typeof event.newFile === 'undefined' ? '' : event.newFile
            );
          }

          return payload;
        })
      );
    };

    this.watcher = await nsfw(this.normalizedPath, handler, {
      debounceMS: 100,
      errorCallback: this.onError
    });

    await this.watcher.start();
  }

  doStop() {
    return this.watcher.stop();
  }
}

// Extended: Manage a subscription to filesystem events that occur beneath a root directory. Construct these by
// calling `watchPath`. To watch for events within active project directories, use {Project::onDidChangeFiles}
// instead.
//
// Multiple PathWatchers may be backed by a single native watcher to conserve operation system resources.
//
// Call {::dispose} to stop receiving events and, if possible, release underlying resources. A PathWatcher may be
// added to a {CompositeDisposable} to manage its lifetime along with other {Disposable} resources like event
// subscriptions.
//
// ```js
// const {watchPath} = require('atom')
//
// const disposable = await watchPath('/var/log', {}, events => {
//   console.log(`Received batch of ${events.length} events.`)
//   for (const event of events) {
//     // "created", "modified", "deleted", "renamed"
//     console.log(`Event action: ${event.action}`)
//
//     // absolute path to the filesystem entry that was touched
//     console.log(`Event path: ${event.path}`)
//
//     if (event.action === 'renamed') {
//       console.log(`.. renamed from: ${event.oldPath}`)
//     }
//   }
// })
//
//  // Immediately stop receiving filesystem events. If this is the last
//  // watcher, asynchronously release any OS resources required to
//  // subscribe to these events.
//  disposable.dispose()
// ```
//
// `watchPath` accepts the following arguments:
//
// `rootPath` {String} specifies the absolute path to the root of the filesystem content to watch.
//
// `options` Control the watcher's behavior. Currently a placeholder.
//
// `eventCallback` {Function} to be called each time a batch of filesystem events is observed. Each event object has
// the keys: `action`, a {String} describing the filesystem action that occurred, one of `"created"`, `"modified"`,
// `"deleted"`, or `"renamed"`; `path`, a {String} containing the absolute path to the filesystem entry that was acted
// upon; for rename events only, `oldPath`, a {String} containing the filesystem entry's former absolute path.
class PathWatcher {
  // Private: Instantiate a new PathWatcher. Call {watchPath} instead.
  //
  // * `nativeWatcherRegistry` {NativeWatcherRegistry} used to find and consolidate redundant watchers.
  // * `watchedPath` {String} containing the absolute path to the root of the watched filesystem tree.
  // * `options` See {watchPath} for options.
  //
  constructor(nativeWatcherRegistry, watchedPath, options) {
    this.watchedPath = watchedPath;
    this.nativeWatcherRegistry = nativeWatcherRegistry;

    this.normalizedPath = null;
    this.native = null;
    this.changeCallbacks = new Map();

    this.attachedPromise = new Promise(resolve => {
      this.resolveAttachedPromise = resolve;
    });

    this.startPromise = new Promise((resolve, reject) => {
      this.resolveStartPromise = resolve;
      this.rejectStartPromise = reject;
    });

    this.normalizedPathPromise = new Promise((resolve, reject) => {
      fs.realpath(watchedPath, (err, real) => {
        if (err) {
          reject(err);
          return;
        }

        this.normalizedPath = real;
        resolve(real);
      });
    });
    this.normalizedPathPromise.catch(err => this.rejectStartPromise(err));

    this.emitter = new Emitter();
    this.subs = new CompositeDisposable();
  }

  // Private: Return a {Promise} that will resolve with the normalized root path.
  getNormalizedPathPromise() {
    return this.normalizedPathPromise;
  }

  // Private: Return a {Promise} that will resolve the first time that this watcher is attached to a native watcher.
  getAttachedPromise() {
    return this.attachedPromise;
  }

  // Extended: Return a {Promise} that will resolve when the underlying native watcher is ready to begin sending events.
  // When testing filesystem watchers, it's important to await this promise before making filesystem changes that you
  // intend to assert about because there will be a delay between the instantiation of the watcher and the activation
  // of the underlying OS resources that feed its events.
  //
  // PathWatchers acquired through `watchPath` are already started.
  //
  // ```js
  // const {watchPath} = require('atom')
  // const ROOT = path.join(__dirname, 'fixtures')
  // const FILE = path.join(ROOT, 'filename.txt')
  //
  // describe('something', function () {
  //   it("doesn't miss events", async function () {
  //     const watcher = watchPath(ROOT, {}, events => {})
  //     await watcher.getStartPromise()
  //     fs.writeFile(FILE, 'contents\n', err => {
  //       // The watcher is listening and the event should be
  //       // received asynchronously
  //     }
  //   })
  // })
  // ```
  getStartPromise() {
    return this.startPromise;
  }

  // Private: Attach another {Function} to be called with each batch of filesystem events. See {watchPath} for the
  // spec of the callback's argument.
  //
  // * `callback` {Function} to be called with each batch of filesystem events.
  //
  // Returns a {Disposable} that will stop the underlying watcher when all callbacks mapped to it have been disposed.
  onDidChange(callback) {
    if (this.native) {
      const sub = this.native.onDidChange(events =>
        this.onNativeEvents(events, callback)
      );
      this.changeCallbacks.set(callback, sub);

      this.native.start();
    } else {
      // Attach to a new native listener and retry
      this.nativeWatcherRegistry.attach(this).then(() => {
        this.onDidChange(callback);
      });
    }

    return new Disposable(() => {
      const sub = this.changeCallbacks.get(callback);
      this.changeCallbacks.delete(callback);
      sub.dispose();
    });
  }

  // Extended: Invoke a {Function} when any errors related to this watcher are reported.
  //
  // * `callback` {Function} to be called when an error occurs.
  //   * `err` An {Error} describing the failure condition.
  //
  // Returns a {Disposable}.
  onDidError(callback) {
    return this.emitter.on('did-error', callback);
  }

  // Private: Wire this watcher to an operating system-level native watcher implementation.
  attachToNative(native) {
    this.subs.dispose();
    this.native = native;

    if (native.isRunning()) {
      this.resolveStartPromise();
    } else {
      this.subs.add(
        native.onDidStart(() => {
          this.resolveStartPromise();
        })
      );
    }

    // Transfer any native event subscriptions to the new NativeWatcher.
    for (const [callback, formerSub] of this.changeCallbacks) {
      const newSub = native.onDidChange(events =>
        this.onNativeEvents(events, callback)
      );
      this.changeCallbacks.set(callback, newSub);
      formerSub.dispose();
    }

    this.subs.add(
      native.onDidError(err => {
        this.emitter.emit('did-error', err);
      })
    );

    this.subs.add(
      native.onShouldDetach(({ replacement, watchedPath }) => {
        if (
          this.native === native &&
          replacement !== native &&
          this.normalizedPath.startsWith(watchedPath)
        ) {
          this.attachToNative(replacement);
        }
      })
    );

    this.subs.add(
      native.onWillStop(() => {
        if (this.native === native) {
          this.subs.dispose();
          this.native = null;
        }
      })
    );

    this.resolveAttachedPromise();
  }

  // Private: Invoked when the attached native watcher creates a batch of native filesystem events. The native watcher's
  // events may include events for paths above this watcher's root path, so filter them to only include the relevant
  // ones, then re-broadcast them to our subscribers.
  onNativeEvents(events, callback) {
    const isWatchedPath = eventPath =>
      eventPath.startsWith(this.normalizedPath);

    const filtered = [];
    for (let i = 0; i < events.length; i++) {
      const event = events[i];

      if (event.action === 'renamed') {
        const srcWatched = isWatchedPath(event.oldPath);
        const destWatched = isWatchedPath(event.path);

        if (srcWatched && destWatched) {
          filtered.push(event);
        } else if (srcWatched && !destWatched) {
          filtered.push({
            action: 'deleted',
            kind: event.kind,
            path: event.oldPath
          });
        } else if (!srcWatched && destWatched) {
          filtered.push({
            action: 'created',
            kind: event.kind,
            path: event.path
          });
        }
      } else {
        if (isWatchedPath(event.path)) {
          filtered.push(event);
        }
      }
    }

    if (filtered.length > 0) {
      callback(filtered);
    }
  }

  // Extended: Unsubscribe all subscribers from filesystem events. Native resources will be released asynchronously,
  // but this watcher will stop broadcasting events immediately.
  dispose() {
    for (const sub of this.changeCallbacks.values()) {
      sub.dispose();
    }

    this.emitter.dispose();
    this.subs.dispose();
  }
}

// Private: Globally tracked state used to de-duplicate related [PathWatchers]{PathWatcher} backed by emulated Atom
// events or NSFW.
class PathWatcherManager {
  // Private: Access the currently active manager instance, creating one if necessary.
  static active() {
    if (!this.activeManager) {
      this.activeManager = new PathWatcherManager(
        atom.config.get('core.fileSystemWatcher')
      );
      this.sub = atom.config.onDidChange(
        'core.fileSystemWatcher',
        ({ newValue }) => {
          this.transitionTo(newValue);
        }
      );
    }
    return this.activeManager;
  }

  // Private: Replace the active {PathWatcherManager} with a new one that creates [NativeWatchers]{NativeWatcher}
  // based on the value of `setting`.
  static async transitionTo(setting) {
    const current = this.active();

    if (this.transitionPromise) {
      await this.transitionPromise;
    }

    if (current.setting === setting) {
      return;
    }
    current.isShuttingDown = true;

    let resolveTransitionPromise = () => {};
    this.transitionPromise = new Promise(resolve => {
      resolveTransitionPromise = resolve;
    });

    const replacement = new PathWatcherManager(setting);
    this.activeManager = replacement;

    await Promise.all(
      Array.from(current.live, async ([root, native]) => {
        const w = await replacement.createWatcher(root, {}, () => {});
        native.reattachTo(w.native, root, w.native.options || {});
      })
    );

    current.stopAllWatchers();

    resolveTransitionPromise();
    this.transitionPromise = null;
  }

  // Private: Initialize global {PathWatcher} state.
  constructor(setting) {
    this.setting = setting;
    this.live = new Map();

    const initLocal = NativeConstructor => {
      this.nativeRegistry = new NativeWatcherRegistry(normalizedPath => {
        const nativeWatcher = new NativeConstructor(normalizedPath);

        this.live.set(normalizedPath, nativeWatcher);
        const sub = nativeWatcher.onWillStop(() => {
          this.live.delete(normalizedPath);
          sub.dispose();
        });

        return nativeWatcher;
      });
    };

    if (setting === 'atom') {
      initLocal(AtomNativeWatcher);
    } else if (setting === 'experimental') {
      //
    } else if (setting === 'poll') {
      //
    } else {
      initLocal(NSFWNativeWatcher);
    }

    this.isShuttingDown = false;
  }

  useExperimentalWatcher() {
    return this.setting === 'experimental' || this.setting === 'poll';
  }

  // Private: Create a {PathWatcher} tied to this global state. See {watchPath} for detailed arguments.
  async createWatcher(rootPath, options, eventCallback) {
    if (this.isShuttingDown) {
      await this.constructor.transitionPromise;
      return PathWatcherManager.active().createWatcher(
        rootPath,
        options,
        eventCallback
      );
    }

    if (this.useExperimentalWatcher()) {
      if (this.setting === 'poll') {
        options.poll = true;
      }

      const w = await watcher.watchPath(rootPath, options, eventCallback);
      this.live.set(rootPath, w.native);
      return w;
    }

    const w = new PathWatcher(this.nativeRegistry, rootPath, options);
    w.onDidChange(eventCallback);
    await w.getStartPromise();
    return w;
  }

  // Private: Directly access the {NativeWatcherRegistry}.
  getRegistry() {
    if (this.useExperimentalWatcher()) {
      return watcher.getRegistry();
    }

    return this.nativeRegistry;
  }

  // Private: Sample watcher usage statistics. Only available for experimental watchers.
  status() {
    if (this.useExperimentalWatcher()) {
      return watcher.status();
    }

    return {};
  }

  // Private: Return a {String} depicting the currently active native watchers.
  print() {
    if (this.useExperimentalWatcher()) {
      return watcher.printWatchers();
    }

    return this.nativeRegistry.print();
  }

  // Private: Stop all living watchers.
  //
  // Returns a {Promise} that resolves when all native watcher resources are disposed.
  stopAllWatchers() {
    if (this.useExperimentalWatcher()) {
      return watcher.stopAllWatchers();
    }

    return Promise.all(Array.from(this.live, ([, w]) => w.stop()));
  }
}

// Extended: Invoke a callback with each filesystem event that occurs beneath a specified path. If you only need to
// watch events within the project's root paths, use {Project::onDidChangeFiles} instead.
//
// watchPath handles the efficient re-use of operating system resources across living watchers. Watching the same path
// more than once, or the child of a watched path, will re-use the existing native watcher.
//
// * `rootPath` {String} specifies the absolute path to the root of the filesystem content to watch.
// * `options` Control the watcher's behavior.
// * `eventCallback` {Function} or other callable to be called each time a batch of filesystem events is observed.
//    * `events` {Array} of objects that describe the events that have occurred.
//      * `action` {String} describing the filesystem action that occurred. One of `"created"`, `"modified"`,
//        `"deleted"`, or `"renamed"`.
//      * `path` {String} containing the absolute path to the filesystem entry that was acted upon.
//      * `oldPath` For rename events, {String} containing the filesystem entry's former absolute path.
//
// Returns a {Promise} that will resolve to a {PathWatcher} once it has started. Note that every {PathWatcher}
// is a {Disposable}, so they can be managed by a {CompositeDisposable} if desired.
//
// ```js
// const {watchPath} = require('atom')
//
// const disposable = await watchPath('/var/log', {}, events => {
//   console.log(`Received batch of ${events.length} events.`)
//   for (const event of events) {
//     // "created", "modified", "deleted", "renamed"
//     console.log(`Event action: ${event.action}`)
//     // absolute path to the filesystem entry that was touched
//     console.log(`Event path: ${event.path}`)
//     if (event.action === 'renamed') {
//       console.log(`.. renamed from: ${event.oldPath}`)
//     }
//   }
// })
//
//  // Immediately stop receiving filesystem events. If this is the last watcher, asynchronously release any OS
//  // resources required to subscribe to these events.
//  disposable.dispose()
// ```
//
function watchPath(rootPath, options, eventCallback) {
  return PathWatcherManager.active().createWatcher(
    rootPath,
    options,
    eventCallback
  );
}

// Private: Return a Promise that resolves when all {NativeWatcher} instances associated with a FileSystemManager
// have stopped listening. This is useful for `afterEach()` blocks in unit tests.
function stopAllWatchers() {
  return PathWatcherManager.active().stopAllWatchers();
}

// Private: Show the currently active native watchers in a formatted {String}.
watchPath.printWatchers = function() {
  return PathWatcherManager.active().print();
};

// Private: Access the active {NativeWatcherRegistry}.
watchPath.getRegistry = function() {
  return PathWatcherManager.active().getRegistry();
};

// Private: Sample usage statistics for the active watcher.
watchPath.status = function() {
  return PathWatcherManager.active().status();
};

// Private: Configure @atom/watcher ("experimental") directly.
watchPath.configure = function(...args) {
  return watcher.configure(...args);
};

module.exports = { watchPath, stopAllWatchers };
