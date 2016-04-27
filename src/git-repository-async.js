'use babel'

import {Repository} from 'ohnogit'
import {CompositeDisposable, Disposable} from 'event-kit'

// For the most part, this class behaves the same as `GitRepository`, with a few
// notable differences:
//   * Errors are generally propagated out to the caller instead of being
//     swallowed within `GitRepositoryAsync`.
//   * Methods accepting a path shouldn't be given a null path, unless it is
//     specifically allowed as noted in the method's documentation.
export default class GitRepositoryAsync {
  static open (path, options = {}) {
    // QUESTION: Should this wrap Git.Repository and reject with a nicer message?
    return new GitRepositoryAsync(path, options)
  }

  static get Git () {
    return Repository.Git
  }

  // The name of the error thrown when an action is attempted on a destroyed
  // repository.
  static get DestroyedErrorName () {
    return Repository.DestroyedErrorName
  }

  constructor (_path, options = {}) {
    this.repo = Repository.open(_path, options)

    this.subscriptions = new CompositeDisposable()

    let {refreshOnWindowFocus = true} = options
    if (refreshOnWindowFocus) {
      const onWindowFocus = () => this.refreshStatus()
      window.addEventListener('focus', onWindowFocus)
      this.subscriptions.add(new Disposable(() => window.removeEventListener('focus', onWindowFocus)))
    }

    const {project, subscribeToBuffers} = options
    this.project = project
    if (this.project && subscribeToBuffers) {
      this.project.getBuffers().forEach(buffer => this.subscribeToBuffer(buffer))
      this.subscriptions.add(this.project.onDidAddBuffer(buffer => this.subscribeToBuffer(buffer)))
    }
  }

  // This exists to provide backwards compatibility.
  get _refreshingPromise () {
    return this.repo._refreshingPromise
  }

  get openedPath () {
    return this.repo.openedPath
  }

  // Public: Destroy this {GitRepositoryAsync} object.
  //
  // This destroys any tasks and subscriptions and releases the underlying
  // libgit2 repository handle. This method is idempotent.
  destroy () {
    this.repo.destroy()

    if (this.subscriptions) {
      this.subscriptions.dispose()
      this.subscriptions = null
    }
  }

  // Event subscription
  // ==================

  // Public: Invoke the given callback when this GitRepositoryAsync's destroy()
  // method is invoked.
  //
  // * `callback` {Function}
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy (callback) {
    return this.repo.onDidDestroy(callback)
  }

  // Public: Invoke the given callback when a specific file's status has
  // changed. When a file is updated, reloaded, etc, and the status changes, this
  // will be fired.
  //
  // * `callback` {Function}
  //   * `event` {Object}
  //     * `path` {String} the old parameters the decoration used to have
  //     * `pathStatus` {Number} representing the status. This value can be passed to
  //       {::isStatusModified} or {::isStatusNew} to get more information.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeStatus (callback) {
    return this.repo.onDidChangeStatus(callback)
  }

  // Public: Invoke the given callback when a multiple files' statuses have
  // changed. For example, on window focus, the status of all the paths in the
  // repo is checked. If any of them have changed, this will be fired. Call
  // {::getPathStatus(path)} to get the status for your path of choice.
  //
  // * `callback` {Function}
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeStatuses (callback) {
    return this.repo.onDidChangeStatuses(callback)
  }

  // Repository details
  // ==================

  // Public: A {String} indicating the type of version control system used by
  // this repository.
  //
  // Returns `"git"`.
  getType () {
    return 'git'
  }

  // Public: Returns a {Promise} which resolves to the {String} path of the
  // repository.
  getPath () {
    return this.repo.getPath()
  }

  // Public: Returns a {Promise} which resolves to the {String} working
  // directory path of the repository.
  getWorkingDirectory (_path) {
    return this.repo.getWorkingDirectory()
  }

  // Public: Returns a {Promise} that resolves to true if at the root, false if
  // in a subfolder of the repository.
  isProjectAtRoot () {
    if (!this.project) return Promise.resolve(false)

    if (!this.projectAtRoot) {
      this.projectAtRoot = this.getWorkingDirectory()
        .then(wd => this.project.relativize(wd) === '')
    }

    return this.projectAtRoot
  }

  // Public: Makes a path relative to the repository's working directory.
  //
  // * `path` The {String} path to relativize.
  //
  // Returns a {Promise} which resolves to the relative {String} path.
  relativizeToWorkingDirectory (_path) {
    return this.repo.relativizeToWorkingDirectory(_path)
  }

  // Public: Makes a path relative to the repository's working directory.
  //
  // * `path` The {String} path to relativize.
  // * `workingDirectory` The {String} working directory path.
  //
  // Returns the relative {String} path.
  relativize (_path, workingDirectory) {
    return this.repo.relativize(_path, workingDirectory)
  }

  // Public: Returns a {Promise} which resolves to whether the given branch
  // exists.
  hasBranch (branch) {
    return this.repo.hasBranch(branch)
  }

  // Public: Retrieves a shortened version of the HEAD reference value.
  //
  // This removes the leading segments of `refs/heads`, `refs/tags`, or
  // `refs/remotes`.  It also shortens the SHA-1 of a detached `HEAD` to 7
  // characters.
  //
  // * `path` An optional {String} path in the repository to get this information
  //   for, only needed if the repository contains submodules.
  //
  // Returns a {Promise} which resolves to a {String}.
  getShortHead (_path) {
    return this.repo.getShortHead(_path)
  }

  // Public: Is the given path a submodule in the repository?
  //
  // * `path` The {String} path to check.
  //
  // Returns a {Promise} that resolves true if the given path is a submodule in
  // the repository.
  isSubmodule (_path) {
    return this.repo.isSubmodule(_path)
  }

  // Public: Returns the number of commits behind the current branch is from the
  // its upstream remote branch.
  //
  // * `reference` The {String} branch reference name.
  // * `path`      The {String} path in the repository to get this information
  //               for, only needed if the repository contains submodules.
  //
  // Returns a {Promise} which resolves to an {Object} with the following keys:
  //   * `ahead`  The {Number} of commits ahead.
  //   * `behind` The {Number} of commits behind.
  getAheadBehindCount (reference, _path) {
    return this.repo.getAheadBehindCount(reference, _path)
  }

  // Public: Get the cached ahead/behind commit counts for the current branch's
  // upstream branch.
  //
  // * `path` An optional {String} path in the repository to get this information
  //   for, only needed if the repository has submodules.
  //
  // Returns a {Promise} which resolves to an {Object} with the following keys:
  //   * `ahead`  The {Number} of commits ahead.
  //   * `behind` The {Number} of commits behind.
  getCachedUpstreamAheadBehindCount (_path) {
    return this.repo.getCachedUpstreamAheadBehindCount(_path)
  }

  // Public: Returns the git configuration value specified by the key.
  //
  // * `path` An optional {String} path in the repository to get this information
  //   for, only needed if the repository has submodules.
  //
  // Returns a {Promise} which resolves to the {String} git configuration value
  // specified by the key.
  getConfigValue (key, _path) {
    return this.repo.getConfigValue(key, _path)
  }

  // Public: Get the URL for the 'origin' remote.
  //
  // * `path` (optional) {String} path in the repository to get this information
  //   for, only needed if the repository has submodules.
  //
  // Returns a {Promise} which resolves to the {String} origin url of the
  // repository.
  getOriginURL (_path) {
    return this.repo.getOriginURL(_path)
  }

  // Public: Returns the upstream branch for the current HEAD, or null if there
  // is no upstream branch for the current HEAD.
  //
  // * `path` An optional {String} path in the repo to get this information for,
  //   only needed if the repository contains submodules.
  //
  // Returns a {Promise} which resolves to a {String} branch name such as
  // `refs/remotes/origin/master`.
  getUpstreamBranch (_path) {
    return this.repo.getUpstreamBranch(_path)
  }

  // Public: Gets all the local and remote references.
  //
  // * `path` An optional {String} path in the repository to get this information
  //   for, only needed if the repository has submodules.
  //
  // Returns a {Promise} which resolves to an {Object} with the following keys:
  //  * `heads`   An {Array} of head reference names.
  //  * `remotes` An {Array} of remote reference names.
  //  * `tags`    An {Array} of tag reference names.
  getReferences (_path) {
    return this.repo.getReferences(_path)
  }

  // Public: Get the SHA for the given reference.
  //
  // * `reference` The {String} reference to get the target of.
  // * `path` An optional {String} path in the repo to get the reference target
  //   for. Only needed if the repository contains submodules.
  //
  // Returns a {Promise} which resolves to the current {String} SHA for the
  // given reference.
  getReferenceTarget (reference, _path) {
    return this.repo.getReferenceTarget(reference, _path)
  }

  // Reading Status
  // ==============

  // Public: Resolves true if the given path is modified.
  //
  // * `path` The {String} path to check.
  //
  // Returns a {Promise} which resolves to a {Boolean} that's true if the `path`
  // is modified.
  isPathModified (_path) {
    return this.repo.isPathModified(_path)
  }

  // Public: Resolves true if the given path is new.
  //
  // * `path` The {String} path to check.
  //
  // Returns a {Promise} which resolves to a {Boolean} that's true if the `path`
  // is new.
  isPathNew (_path) {
    return this.repo.isPathNew(_path)
  }

  // Public: Is the given path ignored?
  //
  // * `path` The {String} path to check.
  //
  // Returns a {Promise} which resolves to a {Boolean} that's true if the `path`
  // is ignored.
  isPathIgnored (_path) {
    return this.repo.isPathIgnored(_path)
  }

  // Get the status of a directory in the repository's working directory.
  //
  // * `directoryPath` The {String} path to check.
  //
  // Returns a {Promise} resolving to a {Number} representing the status. This
  // value can be passed to {::isStatusModified} or {::isStatusNew} to get more
  // information.
  getDirectoryStatus (directoryPath) {
    return this.repo.getDirectoryStatus(directoryPath)
  }

  // Refresh the status bit for the given path.
  //
  // Note that if the status of the path has changed, this will emit a
  // 'did-change-status' event.
  //
  // * `path` The {String} path whose status should be refreshed.
  //
  // Returns a {Promise} which resolves to a {Number} which is the refreshed
  // status bit for the path.
  refreshStatusForPath (_path) {
    return this.repo.refreshStatusForPath(_path)
  }

  // Returns a Promise that resolves to the status bit of a given path if it has
  // one, otherwise 'current'.
  getPathStatus (_path) {
    return this.refreshStatusForPath(_path)
  }

  // Public: Get the cached status for the given path.
  //
  // * `path` A {String} path in the repository, relative or absolute.
  //
  // Returns a {Promise} which resolves to a status {Number} or null if the
  // path is not in the cache.
  getCachedPathStatus (_path) {
    return this.repo.getCachedPathStatus(_path)
  }

  // Public: Get the cached statuses for the repository.
  //
  // Returns an {Object} of {Number} statuses, keyed by {String} working
  // directory-relative file names.
  getCachedPathStatuses () {
    return this.repo.pathStatusCache
  }

  // Public: Returns true if the given status indicates modification.
  //
  // * `statusBit` A {Number} representing the status.
  //
  // Returns a {Boolean} that's true if the `statusBit` indicates modification.
  isStatusModified (statusBit) {
    return this.repo.isStatusModified(statusBit)
  }

  // Public: Returns true if the given status indicates a new path.
  //
  // * `statusBit` A {Number} representing the status.
  //
  // Returns a {Boolean} that's true if the `statusBit` indicates a new path.
  isStatusNew (statusBit) {
    return this.repo.isStatusNew(statusBit)
  }

  // Public: Returns true if the given status indicates the path is staged.
  //
  // * `statusBit` A {Number} representing the status.
  //
  // Returns a {Boolean} that's true if the `statusBit` indicates the path is
  // staged.
  isStatusStaged (statusBit) {
    return this.repo.isStatusStaged(statusBit)
  }

  // Public: Returns true if the given status indicates the path is ignored.
  //
  // * `statusBit` A {Number} representing the status.
  //
  // Returns a {Boolean} that's true if the `statusBit` indicates the path is
  // ignored.
  isStatusIgnored (statusBit) {
    return this.repo.isStatusIgnored(statusBit)
  }

  // Public: Returns true if the given status indicates the path is deleted.
  //
  // * `statusBit` A {Number} representing the status.
  //
  // Returns a {Boolean} that's true if the `statusBit` indicates the path is
  // deleted.
  isStatusDeleted (statusBit) {
    return this.repo.isStatusDeleted(statusBit)
  }

  // Retrieving Diffs
  // ================
  // Public: Retrieves the number of lines added and removed to a path.
  //
  // This compares the working directory contents of the path to the `HEAD`
  // version.
  //
  // * `path` The {String} path to check.
  //
  // Returns a {Promise} which resolves to an {Object} with the following keys:
  //   * `added` The {Number} of added lines.
  //   * `deleted` The {Number} of deleted lines.
  getDiffStats (_path) {
    return this.repo.getDiffStats(_path)
  }

  // Public: Retrieves the line diffs comparing the `HEAD` version of the given
  // path and the given text.
  //
  // * `path` The {String} path relative to the repository.
  // * `text` The {String} to compare against the `HEAD` contents
  //
  // Returns an {Array} of hunk {Object}s with the following keys:
  //   * `oldStart` The line {Number} of the old hunk.
  //   * `newStart` The line {Number} of the new hunk.
  //   * `oldLines` The {Number} of lines in the old hunk.
  //   * `newLines` The {Number} of lines in the new hunk
  getLineDiffs (_path, text) {
    return this.repo.getLineDiffs(_path, text)
  }

  // Checking Out
  // ============

  // Public: Restore the contents of a path in the working directory and index
  // to the version at `HEAD`.
  //
  // This is essentially the same as running:
  //
  // ```sh
  //   git reset HEAD -- <path>
  //   git checkout HEAD -- <path>
  // ```
  //
  // * `path` The {String} path to checkout.
  //
  // Returns a {Promise} that resolves or rejects depending on whether the
  // method was successful.
  checkoutHead (_path) {
    return this.repo.checkoutHead(_path)
  }

  // Public: Checks out a branch in your repository.
  //
  // * `reference` The {String} reference to checkout.
  // * `create`    A {Boolean} value which, if true creates the new reference if
  //   it doesn't exist.
  //
  // Returns a {Promise} that resolves if the method was successful.
  checkoutReference (reference, create) {
    return this.repo.checkoutReference(reference, create)
  }

  // Private
  // =======

  checkoutHeadForEditor (editor) {
    const filePath = editor.getPath()
    if (!filePath) {
      return Promise.reject()
    }

    if (editor.buffer.isModified()) {
      editor.buffer.reload()
    }

    return this.checkoutHead(filePath)
  }

  // Refreshes the git status.
  //
  // Returns a {Promise} which will resolve to {null} when refresh is complete.
  refreshStatus () {
    let projectPathsPromises = [Promise.resolve('')]
    if (this.project) {
      projectPathsPromises = this.project.getPaths()
        .map(p => this.relativizeToWorkingDirectory(p))
    }

    return Promise.all(projectPathsPromises)
      .then(paths => paths.map(p => p.length > 0 ? p + '/**' : '*'))
      .then(pathspecs => this.repo.refreshStatus(pathspecs))
  }

  // Get the NodeGit repository for the given path.
  //
  // * `path` The optional {String} path within the repository. This is only
  //          needed if you want to get the repository for that path if it is a
  //          submodule.
  //
  // Returns a {Promise} which resolves to the {NodeGit.Repository}.
  getRepo (_path) {
    return this.repo.getRepo(_path)
  }

  // Open a new instance of the underlying {NodeGit.Repository}.
  //
  // By opening multiple connections to the same underlying repository, users
  // can safely access the same repository concurrently.
  //
  // Returns the new {NodeGit.Repository}.
  openRepository () {
    return this.repo.openRepository()
  }

  // Section: Private
  // ================

  // Has the repository been destroyed?
  //
  // Returns a {Boolean}.
  _isDestroyed () {
    return this.repo._isDestroyed()
  }

  // Subscribe to events on the given buffer.
  subscribeToBuffer (buffer) {
    const bufferSubscriptions = new CompositeDisposable()

    const refreshStatusForBuffer = () => {
      const _path = buffer.getPath()
      if (_path) {
        this.refreshStatusForPath(_path)
      }
    }

    bufferSubscriptions.add(
      buffer.onDidSave(refreshStatusForBuffer),
      buffer.onDidReload(refreshStatusForBuffer),
      buffer.onDidChangePath(refreshStatusForBuffer),
      buffer.onDidDestroy(() => {
        bufferSubscriptions.dispose()
        this.subscriptions.remove(bufferSubscriptions)
      })
    )

    this.subscriptions.add(bufferSubscriptions)
  }
}
