const path = require('path');

const _ = require('underscore-plus');
const fs = require('fs-plus');
const { Emitter, Disposable, CompositeDisposable } = require('event-kit');
const TextBuffer = require('text-buffer');
const { watchPath } = require('./path-watcher');

const DefaultDirectoryProvider = require('./default-directory-provider');
const Model = require('./model');
const GitRepositoryProvider = require('./git-repository-provider');

// Extended: Represents a project that's opened in Atom.
//
// An instance of this class is always available as the `atom.project` global.
module.exports = class Project extends Model {
  /*
  Section: Construction and Destruction
  */

  constructor({
    notificationManager,
    packageManager,
    config,
    applicationDelegate,
    grammarRegistry
  }) {
    super();
    this.notificationManager = notificationManager;
    this.applicationDelegate = applicationDelegate;
    this.grammarRegistry = grammarRegistry;

    this.emitter = new Emitter();
    this.buffers = [];
    this.rootDirectories = [];
    this.repositories = [];
    this.directoryProviders = [];
    this.defaultDirectoryProvider = new DefaultDirectoryProvider();
    this.repositoryPromisesByPath = new Map();
    this.repositoryProviders = [new GitRepositoryProvider(this, config)];
    this.loadPromisesByPath = {};
    this.watcherPromisesByPath = {};
    this.retiredBufferIDs = new Set();
    this.retiredBufferPaths = new Set();
    this.subscriptions = new CompositeDisposable();
    this.consumeServices(packageManager);
  }

  destroyed() {
    for (let buffer of this.buffers.slice()) {
      buffer.destroy();
    }
    for (let repository of this.repositories.slice()) {
      if (repository != null) repository.destroy();
    }
    for (let path in this.watcherPromisesByPath) {
      this.watcherPromisesByPath[path].then(watcher => {
        watcher.dispose();
      });
    }
    this.rootDirectories = [];
    this.repositories = [];
  }

  reset(packageManager) {
    this.emitter.dispose();
    this.emitter = new Emitter();

    this.subscriptions.dispose();
    this.subscriptions = new CompositeDisposable();

    for (let buffer of this.buffers) {
      if (buffer != null) buffer.destroy();
    }
    this.buffers = [];
    this.setPaths([]);
    this.loadPromisesByPath = {};
    this.retiredBufferIDs = new Set();
    this.retiredBufferPaths = new Set();
    this.consumeServices(packageManager);
  }

  destroyUnretainedBuffers() {
    for (let buffer of this.getBuffers()) {
      if (!buffer.isRetained()) buffer.destroy();
    }
  }

  // Layers the contents of a project's file's config
  // on top of the current global config.
  replace(projectSpecification) {
    if (projectSpecification == null) {
      atom.config.clearProjectSettings();
      this.setPaths([]);
    } else {
      if (projectSpecification.originPath == null) {
        return;
      }

      // If no path is specified, set to directory of originPath.
      if (!Array.isArray(projectSpecification.paths)) {
        projectSpecification.paths = [
          path.dirname(projectSpecification.originPath)
        ];
      }
      atom.config.resetProjectSettings(
        projectSpecification.config,
        projectSpecification.originPath
      );
      this.setPaths(projectSpecification.paths);
    }
    this.emitter.emit('did-replace', projectSpecification);
  }

  onDidReplace(callback) {
    return this.emitter.on('did-replace', callback);
  }

  /*
  Section: Serialization
  */

  deserialize(state) {
    this.retiredBufferIDs = new Set();
    this.retiredBufferPaths = new Set();

    const handleBufferState = bufferState => {
      if (bufferState.shouldDestroyOnFileDelete == null) {
        bufferState.shouldDestroyOnFileDelete = () =>
          atom.config.get('core.closeDeletedFileTabs');
      }

      // Use a little guilty knowledge of the way TextBuffers are serialized.
      // This allows TextBuffers that have never been saved (but have filePaths) to be deserialized, but prevents
      // TextBuffers backed by files that have been deleted from being saved.
      bufferState.mustExist = bufferState.digestWhenLastPersisted !== false;

      return TextBuffer.deserialize(bufferState).catch(_ => {
        this.retiredBufferIDs.add(bufferState.id);
        this.retiredBufferPaths.add(bufferState.filePath);
        return null;
      });
    };

    const bufferPromises = [];
    for (let bufferState of state.buffers) {
      bufferPromises.push(handleBufferState(bufferState));
    }

    return Promise.all(bufferPromises).then(buffers => {
      this.buffers = buffers.filter(Boolean);
      for (let buffer of this.buffers) {
        this.grammarRegistry.maintainLanguageMode(buffer);
        this.subscribeToBuffer(buffer);
      }
      this.setPaths(state.paths || [], { mustExist: true, exact: true });
    });
  }

  serialize(options = {}) {
    return {
      deserializer: 'Project',
      paths: this.getPaths(),
      buffers: _.compact(
        this.buffers.map(function(buffer) {
          if (buffer.isRetained()) {
            const isUnloading = options.isUnloading === true;
            return buffer.serialize({
              markerLayers: isUnloading,
              history: isUnloading
            });
          }
        })
      )
    };
  }

  /*
  Section: Event Subscription
  */

  // Public: Invoke the given callback when the project paths change.
  //
  // * `callback` {Function} to be called after the project paths change.
  //    * `projectPaths` An {Array} of {String} project paths.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangePaths(callback) {
    return this.emitter.on('did-change-paths', callback);
  }

  // Public: Invoke the given callback when a text buffer is added to the
  // project.
  //
  // * `callback` {Function} to be called when a text buffer is added.
  //   * `buffer` A {TextBuffer} item.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddBuffer(callback) {
    return this.emitter.on('did-add-buffer', callback);
  }

  // Public: Invoke the given callback with all current and future text
  // buffers in the project.
  //
  // * `callback` {Function} to be called with current and future text buffers.
  //   * `buffer` A {TextBuffer} item.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeBuffers(callback) {
    for (let buffer of this.getBuffers()) {
      callback(buffer);
    }
    return this.onDidAddBuffer(callback);
  }

  // Extended: Invoke a callback when a filesystem change occurs within any open
  // project path.
  //
  // ```js
  // const disposable = atom.project.onDidChangeFiles(events => {
  //   for (const event of events) {
  //     // "created", "modified", "deleted", or "renamed"
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
  // disposable.dispose()
  // ```
  //
  // To watch paths outside of open projects, use the `watchPaths` function instead; see {PathWatcher}.
  //
  // When writing tests against functionality that uses this method, be sure to wait for the
  // {Promise} returned by {::getWatcherPromise} before manipulating the filesystem to ensure that
  // the watcher is receiving events.
  //
  // * `callback` {Function} to be called with batches of filesystem events reported by
  //   the operating system.
  //    * `events` An {Array} of objects that describe a batch of filesystem events.
  //     * `action` {String} describing the filesystem action that occurred. One of `"created"`,
  //       `"modified"`, `"deleted"`, or `"renamed"`.
  //     * `path` {String} containing the absolute path to the filesystem entry
  //       that was acted upon.
  //     * `oldPath` For rename events, {String} containing the filesystem entry's
  //       former absolute path.
  //
  // Returns a {Disposable} to manage this event subscription.
  onDidChangeFiles(callback) {
    return this.emitter.on('did-change-files', callback);
  }

  // Public: Invoke the given callback with all current and future
  // repositories in the project.
  //
  // * `callback` {Function} to be called with current and future
  //    repositories.
  //   * `repository` A {GitRepository} that is present at the time of
  //     subscription or that is added at some later time.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to
  // unsubscribe.
  observeRepositories(callback) {
    for (const repo of this.repositories) {
      if (repo != null) {
        callback(repo);
      }
    }

    return this.onDidAddRepository(callback);
  }

  // Public: Invoke the given callback when a repository is added to the
  // project.
  //
  // * `callback` {Function} to be called when a repository is added.
  //   * `repository` A {GitRepository}.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to
  // unsubscribe.
  onDidAddRepository(callback) {
    return this.emitter.on('did-add-repository', callback);
  }

  /*
  Section: Accessing the git repository
  */

  // Public: Get an {Array} of {GitRepository}s associated with the project's
  // directories.
  //
  // This method will be removed in 2.0 because it does synchronous I/O.
  // Prefer the following, which evaluates to a {Promise} that resolves to an
  // {Array} of {GitRepository} objects:
  // ```
  // Promise.all(atom.project.getDirectories().map(
  //     atom.project.repositoryForDirectory.bind(atom.project)))
  // ```
  getRepositories() {
    return this.repositories;
  }

  // Public: Get the repository for a given directory asynchronously.
  //
  // * `directory` {Directory} for which to get a {GitRepository}.
  //
  // Returns a {Promise} that resolves with either:
  // * {GitRepository} if a repository can be created for the given directory
  // * `null` if no repository can be created for the given directory.
  repositoryForDirectory(directory) {
    const pathForDirectory = directory.getRealPathSync();
    let promise = this.repositoryPromisesByPath.get(pathForDirectory);
    if (!promise) {
      const promises = this.repositoryProviders.map(provider =>
        provider.repositoryForDirectory(directory)
      );
      promise = Promise.all(promises).then(repositories => {
        const repo = repositories.find(repo => repo != null) || null;

        // If no repository is found, remove the entry for the directory in
        // @repositoryPromisesByPath in case some other RepositoryProvider is
        // registered in the future that could supply a Repository for the
        // directory.
        if (repo == null)
          this.repositoryPromisesByPath.delete(pathForDirectory);

        if (repo && repo.onDidDestroy) {
          repo.onDidDestroy(() =>
            this.repositoryPromisesByPath.delete(pathForDirectory)
          );
        }

        return repo;
      });
      this.repositoryPromisesByPath.set(pathForDirectory, promise);
    }
    return promise;
  }

  /*
  Section: Managing Paths
  */

  // Public: Get an {Array} of {String}s containing the paths of the project's
  // directories.
  getPaths() {
    try {
      return this.rootDirectories.map(rootDirectory => rootDirectory.getPath());
    } catch (e) {
      atom.notifications.addError(
        "Please clear Atom's window state with: atom --clear-window-state"
      );
    }
  }

  // Public: Set the paths of the project's directories.
  //
  // * `projectPaths` {Array} of {String} paths.
  // * `options` An optional {Object} that may contain the following keys:
  //   * `mustExist` If `true`, throw an Error if any `projectPaths` do not exist. Any remaining `projectPaths` that
  //     do exist will still be added to the project. Default: `false`.
  //   * `exact` If `true`, only add a `projectPath` if it names an existing directory. If `false` and any `projectPath`
  //     is a file or does not exist, its parent directory will be added instead. Default: `false`.
  setPaths(projectPaths, options = {}) {
    for (let repository of this.repositories) {
      if (repository != null) repository.destroy();
    }
    this.rootDirectories = [];
    this.repositories = [];

    for (let path in this.watcherPromisesByPath) {
      this.watcherPromisesByPath[path].then(watcher => {
        watcher.dispose();
      });
    }
    this.watcherPromisesByPath = {};

    const missingProjectPaths = [];
    for (let projectPath of projectPaths) {
      try {
        this.addPath(projectPath, {
          emitEvent: false,
          mustExist: true,
          exact: options.exact === true
        });
      } catch (e) {
        if (e.missingProjectPaths != null) {
          missingProjectPaths.push(...e.missingProjectPaths);
        } else {
          throw e;
        }
      }
    }

    this.emitter.emit('did-change-paths', projectPaths);

    if (options.mustExist === true && missingProjectPaths.length > 0) {
      const err = new Error('One or more project directories do not exist');
      err.missingProjectPaths = missingProjectPaths;
      throw err;
    }
  }

  // Public: Add a path to the project's list of root paths
  //
  // * `projectPath` {String} The path to the directory to add.
  // * `options` An optional {Object} that may contain the following keys:
  //   * `mustExist` If `true`, throw an Error if the `projectPath` does not exist. If `false`, a `projectPath` that does
  //     not exist is ignored. Default: `false`.
  //   * `exact` If `true`, only add `projectPath` if it names an existing directory. If `false`, if `projectPath` is a
  //     a file or does not exist, its parent directory will be added instead.
  addPath(projectPath, options = {}) {
    const directory = this.getDirectoryForProjectPath(projectPath);
    let ok = true;
    if (options.exact === true) {
      ok = directory.getPath() === projectPath;
    }
    ok = ok && directory.existsSync();

    if (!ok) {
      if (options.mustExist === true) {
        const err = new Error(`Project directory ${directory} does not exist`);
        err.missingProjectPaths = [projectPath];
        throw err;
      } else {
        return;
      }
    }

    for (let existingDirectory of this.getDirectories()) {
      if (existingDirectory.getPath() === directory.getPath()) {
        return;
      }
    }

    this.rootDirectories.push(directory);

    const didChangeCallback = events => {
      // Stop event delivery immediately on removal of a rootDirectory, even if its watcher
      // promise has yet to resolve at the time of removal
      if (this.rootDirectories.includes(directory)) {
        this.emitter.emit('did-change-files', events);
      }
    };

    // We'll use the directory's custom onDidChangeFiles callback, if available.
    // CustomDirectory::onDidChangeFiles should match the signature of
    // Project::onDidChangeFiles below (although it may resolve asynchronously)
    this.watcherPromisesByPath[directory.getPath()] =
      directory.onDidChangeFiles != null
        ? Promise.resolve(directory.onDidChangeFiles(didChangeCallback))
        : watchPath(directory.getPath(), {}, didChangeCallback);

    for (let watchedPath in this.watcherPromisesByPath) {
      if (!this.rootDirectories.find(dir => dir.getPath() === watchedPath)) {
        this.watcherPromisesByPath[watchedPath].then(watcher => {
          watcher.dispose();
        });
      }
    }

    let repo = null;
    for (let provider of this.repositoryProviders) {
      if (provider.repositoryForDirectorySync) {
        repo = provider.repositoryForDirectorySync(directory);
      }
      if (repo) {
        break;
      }
    }
    this.repositories.push(repo != null ? repo : null);
    if (repo != null) {
      this.emitter.emit('did-add-repository', repo);
    }

    if (options.emitEvent !== false) {
      this.emitter.emit('did-change-paths', this.getPaths());
    }
  }

  getProvidedDirectoryForProjectPath(projectPath) {
    for (let provider of this.directoryProviders) {
      if (typeof provider.directoryForURISync === 'function') {
        const directory = provider.directoryForURISync(projectPath);
        if (directory) {
          return directory;
        }
      }
    }
    return null;
  }

  getDirectoryForProjectPath(projectPath) {
    let directory = this.getProvidedDirectoryForProjectPath(projectPath);
    if (directory == null) {
      directory = this.defaultDirectoryProvider.directoryForURISync(
        projectPath
      );
    }
    return directory;
  }

  // Extended: Access a {Promise} that resolves when the filesystem watcher associated with a project
  // root directory is ready to begin receiving events.
  //
  // This is especially useful in test cases, where it's important to know that the watcher is
  // ready before manipulating the filesystem to produce events.
  //
  // * `projectPath` {String} One of the project's root directories.
  //
  // Returns a {Promise} that resolves with the {PathWatcher} associated with this project root
  // once it has initialized and is ready to start sending events. The Promise will reject with
  // an error instead if `projectPath` is not currently a root directory.
  getWatcherPromise(projectPath) {
    return (
      this.watcherPromisesByPath[projectPath] ||
      Promise.reject(new Error(`${projectPath} is not a project root`))
    );
  }

  // Public: remove a path from the project's list of root paths.
  //
  // * `projectPath` {String} The path to remove.
  removePath(projectPath) {
    // The projectPath may be a URI, in which case it should not be normalized.
    if (!this.getPaths().includes(projectPath)) {
      projectPath = this.defaultDirectoryProvider.normalizePath(projectPath);
    }

    let indexToRemove = null;
    for (let i = 0; i < this.rootDirectories.length; i++) {
      const directory = this.rootDirectories[i];
      if (directory.getPath() === projectPath) {
        indexToRemove = i;
        break;
      }
    }

    if (indexToRemove != null) {
      this.rootDirectories.splice(indexToRemove, 1);
      const [removedRepository] = this.repositories.splice(indexToRemove, 1);
      if (!this.repositories.includes(removedRepository)) {
        if (removedRepository) removedRepository.destroy();
      }
      if (this.watcherPromisesByPath[projectPath] != null) {
        this.watcherPromisesByPath[projectPath].then(w => w.dispose());
      }
      delete this.watcherPromisesByPath[projectPath];
      this.emitter.emit('did-change-paths', this.getPaths());
      return true;
    } else {
      return false;
    }
  }

  // Public: Get an {Array} of {Directory}s associated with this project.
  getDirectories() {
    return this.rootDirectories;
  }

  resolvePath(uri) {
    if (!uri) {
      return;
    }

    if (uri.match(/[A-Za-z0-9+-.]+:\/\//)) {
      // leave path alone if it has a scheme
      return uri;
    } else {
      let projectPath;
      if (fs.isAbsolute(uri)) {
        return this.defaultDirectoryProvider.normalizePath(fs.resolveHome(uri));
        // TODO: what should we do here when there are multiple directories?
      } else if ((projectPath = this.getPaths()[0])) {
        return this.defaultDirectoryProvider.normalizePath(
          fs.resolveHome(path.join(projectPath, uri))
        );
      } else {
        return undefined;
      }
    }
  }

  relativize(fullPath) {
    return this.relativizePath(fullPath)[1];
  }

  // Public: Get the path to the project directory that contains the given path,
  // and the relative path from that project directory to the given path.
  //
  // * `fullPath` {String} An absolute path.
  //
  // Returns an {Array} with two elements:
  // * `projectPath` The {String} path to the project directory that contains the
  //   given path, or `null` if none is found.
  // * `relativePath` {String} The relative path from the project directory to
  //   the given path.
  relativizePath(fullPath) {
    let result = [null, fullPath];
    if (fullPath != null) {
      for (let rootDirectory of this.rootDirectories) {
        const relativePath = rootDirectory.relativize(fullPath);
        if (relativePath != null && relativePath.length < result[1].length) {
          result = [rootDirectory.getPath(), relativePath];
        }
      }
    }
    return result;
  }

  // Public: Determines whether the given path (real or symbolic) is inside the
  // project's directory.
  //
  // This method does not actually check if the path exists, it just checks their
  // locations relative to each other.
  //
  // ## Examples
  //
  // Basic operation
  //
  // ```coffee
  // # Project's root directory is /foo/bar
  // project.contains('/foo/bar/baz')        # => true
  // project.contains('/usr/lib/baz')        # => false
  // ```
  //
  // Existence of the path is not required
  //
  // ```coffee
  // # Project's root directory is /foo/bar
  // fs.existsSync('/foo/bar/baz')           # => false
  // project.contains('/foo/bar/baz')        # => true
  // ```
  //
  // * `pathToCheck` {String} path
  //
  // Returns whether the path is inside the project's root directory.
  contains(pathToCheck) {
    return this.rootDirectories.some(dir => dir.contains(pathToCheck));
  }

  /*
  Section: Private
  */

  consumeServices({ serviceHub }) {
    serviceHub.consume('atom.directory-provider', '^0.1.0', provider => {
      this.directoryProviders.unshift(provider);
      return new Disposable(() => {
        return this.directoryProviders.splice(
          this.directoryProviders.indexOf(provider),
          1
        );
      });
    });

    return serviceHub.consume(
      'atom.repository-provider',
      '^0.1.0',
      provider => {
        this.repositoryProviders.unshift(provider);
        if (this.repositories.includes(null)) {
          this.setPaths(this.getPaths());
        }
        return new Disposable(() => {
          return this.repositoryProviders.splice(
            this.repositoryProviders.indexOf(provider),
            1
          );
        });
      }
    );
  }

  // Retrieves all the {TextBuffer}s in the project; that is, the
  // buffers for all open files.
  //
  // Returns an {Array} of {TextBuffer}s.
  getBuffers() {
    return this.buffers.slice();
  }

  // Is the buffer for the given path modified?
  isPathModified(filePath) {
    const bufferForPath = this.findBufferForPath(this.resolvePath(filePath));
    return bufferForPath && bufferForPath.isModified();
  }

  findBufferForPath(filePath) {
    return _.find(this.buffers, buffer => buffer.getPath() === filePath);
  }

  findBufferForId(id) {
    return _.find(this.buffers, buffer => buffer.getId() === id);
  }

  // Only to be used in specs
  bufferForPathSync(filePath) {
    const absoluteFilePath = this.resolvePath(filePath);
    if (this.retiredBufferPaths.has(absoluteFilePath)) {
      return null;
    }

    let existingBuffer;
    if (filePath) {
      existingBuffer = this.findBufferForPath(absoluteFilePath);
    }
    return existingBuffer != null
      ? existingBuffer
      : this.buildBufferSync(absoluteFilePath);
  }

  // Only to be used when deserializing
  bufferForIdSync(id) {
    if (this.retiredBufferIDs.has(id)) {
      return null;
    }

    let existingBuffer;
    if (id) {
      existingBuffer = this.findBufferForId(id);
    }
    return existingBuffer != null ? existingBuffer : this.buildBufferSync();
  }

  // Given a file path, this retrieves or creates a new {TextBuffer}.
  //
  // If the `filePath` already has a `buffer`, that value is used instead. Otherwise,
  // `text` is used as the contents of the new buffer.
  //
  // * `filePath` A {String} representing a path. If `null`, an "Untitled" buffer is created.
  //
  // Returns a {Promise} that resolves to the {TextBuffer}.
  bufferForPath(absoluteFilePath) {
    let existingBuffer;
    if (absoluteFilePath != null) {
      existingBuffer = this.findBufferForPath(absoluteFilePath);
    }
    if (existingBuffer) {
      return Promise.resolve(existingBuffer);
    } else {
      return this.buildBuffer(absoluteFilePath);
    }
  }

  shouldDestroyBufferOnFileDelete() {
    return atom.config.get('core.closeDeletedFileTabs');
  }

  // Still needed when deserializing a tokenized buffer
  buildBufferSync(absoluteFilePath) {
    const params = {
      shouldDestroyOnFileDelete: this.shouldDestroyBufferOnFileDelete
    };

    let buffer;
    if (absoluteFilePath != null) {
      buffer = TextBuffer.loadSync(absoluteFilePath, params);
    } else {
      buffer = new TextBuffer(params);
    }
    this.addBuffer(buffer);
    return buffer;
  }

  // Given a file path, this sets its {TextBuffer}.
  //
  // * `absoluteFilePath` A {String} representing a path.
  // * `text` The {String} text to use as a buffer.
  //
  // Returns a {Promise} that resolves to the {TextBuffer}.
  async buildBuffer(absoluteFilePath) {
    const params = {
      shouldDestroyOnFileDelete: this.shouldDestroyBufferOnFileDelete
    };

    let buffer;
    if (absoluteFilePath != null) {
      if (this.loadPromisesByPath[absoluteFilePath] == null) {
        this.loadPromisesByPath[absoluteFilePath] = TextBuffer.load(
          absoluteFilePath,
          params
        )
          .then(result => {
            delete this.loadPromisesByPath[absoluteFilePath];
            return result;
          })
          .catch(error => {
            delete this.loadPromisesByPath[absoluteFilePath];
            throw error;
          });
      }
      buffer = await this.loadPromisesByPath[absoluteFilePath];
    } else {
      buffer = new TextBuffer(params);
    }

    this.grammarRegistry.autoAssignLanguageMode(buffer);

    this.addBuffer(buffer);
    return buffer;
  }

  addBuffer(buffer, options = {}) {
    this.buffers.push(buffer);
    this.subscriptions.add(this.grammarRegistry.maintainLanguageMode(buffer));
    this.subscribeToBuffer(buffer);
    this.emitter.emit('did-add-buffer', buffer);
    return buffer;
  }

  // Removes a {TextBuffer} association from the project.
  //
  // Returns the removed {TextBuffer}.
  removeBuffer(buffer) {
    const index = this.buffers.indexOf(buffer);
    if (index !== -1) {
      return this.removeBufferAtIndex(index);
    }
  }

  removeBufferAtIndex(index, options = {}) {
    const [buffer] = this.buffers.splice(index, 1);
    return buffer != null ? buffer.destroy() : undefined;
  }

  eachBuffer(...args) {
    let subscriber;
    if (args.length > 1) {
      subscriber = args.shift();
    }
    const callback = args.shift();

    for (let buffer of this.getBuffers()) {
      callback(buffer);
    }
    if (subscriber) {
      return subscriber.subscribe(this, 'buffer-created', buffer =>
        callback(buffer)
      );
    } else {
      return this.on('buffer-created', buffer => callback(buffer));
    }
  }

  subscribeToBuffer(buffer) {
    buffer.onWillSave(async ({ path }) =>
      this.applicationDelegate.emitWillSavePath(path)
    );
    buffer.onDidSave(({ path }) =>
      this.applicationDelegate.emitDidSavePath(path)
    );
    buffer.onDidDestroy(() => this.removeBuffer(buffer));
    buffer.onDidChangePath(() => {
      if (!(this.getPaths().length > 0)) {
        this.setPaths([path.dirname(buffer.getPath())]);
      }
    });
    buffer.onWillThrowWatchError(({ error, handle }) => {
      handle();
      const message =
        `Unable to read file after file \`${error.eventType}\` event.` +
        `Make sure you have permission to access \`${buffer.getPath()}\`.`;
      this.notificationManager.addWarning(message, {
        detail: error.message,
        dismissable: true
      });
    });
  }
};
