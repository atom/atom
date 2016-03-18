'use babel'

import fs from 'fs-plus'
import path from 'path'
import Git from 'nodegit'
import {Emitter, CompositeDisposable, Disposable} from 'event-kit'

const modifiedStatusFlags = Git.Status.STATUS.WT_MODIFIED | Git.Status.STATUS.INDEX_MODIFIED | Git.Status.STATUS.WT_DELETED | Git.Status.STATUS.INDEX_DELETED | Git.Status.STATUS.WT_TYPECHANGE | Git.Status.STATUS.INDEX_TYPECHANGE
const newStatusFlags = Git.Status.STATUS.WT_NEW | Git.Status.STATUS.INDEX_NEW
const deletedStatusFlags = Git.Status.STATUS.WT_DELETED | Git.Status.STATUS.INDEX_DELETED
const indexStatusFlags = Git.Status.STATUS.INDEX_NEW | Git.Status.STATUS.INDEX_MODIFIED | Git.Status.STATUS.INDEX_DELETED | Git.Status.STATUS.INDEX_RENAMED | Git.Status.STATUS.INDEX_TYPECHANGE
const ignoredStatusFlags = 1 << 14 // TODO: compose this from libgit2 constants
const submoduleMode = 57344 // TODO: compose this from libgit2 constants

// Just using this for _.isEqual and _.object, we should impl our own here
import _ from 'underscore-plus'

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
    return Git
  }

  // The name of the error thrown when an action is attempted on a destroyed
  // repository.
  static get DestroyedErrorName () {
    return 'GitRepositoryAsync.destroyed'
  }

  constructor (_path, options = {}) {
    Git.enableThreadSafety()

    this.emitter = new Emitter()
    this.subscriptions = new CompositeDisposable()
    this.pathStatusCache = {}

    // NB: These needs to happen before the following .openRepository call.
    this.openedPath = _path
    this._openExactPath = options.openExactPath || false

    this.repoPromise = this.openRepository()
    this.isCaseInsensitive = fs.isCaseInsensitive()
    this.upstream = {}
    this.submodules = {}

    this._refreshingPromise = Promise.resolve()

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

  // Public: Destroy this {GitRepositoryAsync} object.
  //
  // This destroys any tasks and subscriptions and releases the underlying
  // libgit2 repository handle. This method is idempotent.
  destroy () {
    if (this.emitter) {
      this.emitter.emit('did-destroy')
      this.emitter.dispose()
      this.emitter = null
    }
    if (this.subscriptions) {
      this.subscriptions.dispose()
      this.subscriptions = null
    }

    this.repoPromise = null
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
    return this.emitter.on('did-destroy', callback)
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
    return this.emitter.on('did-change-status', callback)
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
    return this.emitter.on('did-change-statuses', callback)
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
    return this.getRepo().then(repo => repo.path().replace(/\/$/, ''))
  }

  // Public: Returns a {Promise} which resolves to the {String} working
  // directory path of the repository.
  getWorkingDirectory () {
    return this.getRepo().then(repo => repo.workdir())
  }

  // Public: Returns a {Promise} that resolves to true if at the root, false if
  // in a subfolder of the repository.
  isProjectAtRoot () {
    if (!this.project) return Promise.resolve(false)

    if (!this.projectAtRoot) {
      this.projectAtRoot = this.getRepo()
        .then(repo => this.project.relativize(repo.workdir()) === '')
    }

    return this.projectAtRoot
  }

  // Public: Makes a path relative to the repository's working directory.
  //
  // * `path` The {String} path to relativize.
  //
  // Returns a {Promise} which resolves to the relative {String} path.
  relativizeToWorkingDirectory (_path) {
    return this.getRepo()
      .then(repo => this.relativize(_path, repo.workdir()))
  }

  // Public: Makes a path relative to the repository's working directory.
  //
  // * `path` The {String} path to relativize.
  // * `workingDirectory` The {String} working directory path.
  //
  // Returns the relative {String} path.
  relativize (_path, workingDirectory) {
    // The original implementation also handled null workingDirectory as it
    // pulled it from a sync function that could return null. We require it
    // to be passed here.
    let openedWorkingDirectory
    if (!_path || !workingDirectory) {
      return _path
    }

    // If the opened directory and the workdir differ, this is a symlinked repo
    // root, so we have to do all the checks below twice--once against the realpath
    // and one against the opened path
    const opened = this.openedPath.replace(/\/\.git$/, '')
    if (path.relative(opened, workingDirectory) !== '') {
      openedWorkingDirectory = opened
    }

    if (process.platform === 'win32') {
      _path = _path.replace(/\\/g, '/')
    } else {
      if (_path[0] !== '/') {
        return _path
      }
    }

    workingDirectory = workingDirectory.replace(/\/$/, '')

    // Depending on where the paths come from, they may have a '/private/'
    // prefix. Standardize by stripping that out.
    _path = _path.replace(/^\/private\//i, '/')
    workingDirectory = workingDirectory.replace(/^\/private\//i, '/')

    const originalPath = _path
    const originalWorkingDirectory = workingDirectory
    if (this.isCaseInsensitive) {
      _path = _path.toLowerCase()
      workingDirectory = workingDirectory.toLowerCase()
    }

    if (_path.indexOf(workingDirectory) === 0) {
      return originalPath.substring(originalWorkingDirectory.length + 1)
    } else if (_path === workingDirectory) {
      return ''
    }

    if (openedWorkingDirectory) {
      openedWorkingDirectory = openedWorkingDirectory.replace(/\/$/, '')
      openedWorkingDirectory = openedWorkingDirectory.replace(/^\/private\//i, '/')

      const originalOpenedWorkingDirectory = openedWorkingDirectory
      if (this.isCaseInsensitive) {
        openedWorkingDirectory = openedWorkingDirectory.toLowerCase()
      }

      if (_path.indexOf(openedWorkingDirectory) === 0) {
        return originalPath.substring(originalOpenedWorkingDirectory.length + 1)
      } else if (_path === openedWorkingDirectory) {
        return ''
      }
    }

    return _path
  }

  // Public: Returns a {Promise} which resolves to whether the given branch
  // exists.
  hasBranch (branch) {
    return this.getRepo()
      .then(repo => repo.getBranch(branch))
      .then(branch => branch != null)
      .catch(_ => false)
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
    return this.getRepo(_path)
      .then(repo => repo.getCurrentBranch())
      .then(branch => branch.shorthand())
  }

  // Public: Is the given path a submodule in the repository?
  //
  // * `path` The {String} path to check.
  //
  // Returns a {Promise} that resolves true if the given path is a submodule in
  // the repository.
  isSubmodule (_path) {
    return this.getRepo()
      .then(repo => repo.openIndex())
      .then(index => Promise.all([index, this.relativizeToWorkingDirectory(_path)]))
      .then(([index, relativePath]) => {
        const entry = index.getByPath(relativePath)
        if (!entry) return false

        return entry.mode === submoduleMode
      })
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
    return this.getRepo(_path)
      .then(repo => Promise.all([repo, repo.getBranch(reference)]))
      .then(([repo, local]) => {
        const upstream = Git.Branch.upstream(local)
        return Promise.all([repo, local, upstream])
      })
      .then(([repo, local, upstream]) => {
        return Git.Graph.aheadBehind(repo, local.target(), upstream.target())
      })
      .catch(_ => ({ahead: 0, behind: 0}))
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
    return this.relativizeToWorkingDirectory(_path)
      .then(relativePath => this._submoduleForPath(_path))
      .then(submodule => {
        if (submodule) {
          return submodule.getCachedUpstreamAheadBehindCount(_path)
        } else {
          return this.upstream
        }
      })
  }

  // Public: Returns the git configuration value specified by the key.
  //
  // * `path` An optional {String} path in the repository to get this information
  //   for, only needed if the repository has submodules.
  //
  // Returns a {Promise} which resolves to the {String} git configuration value
  // specified by the key.
  getConfigValue (key, _path) {
    return this.getRepo(_path)
      .then(repo => repo.configSnapshot())
      .then(config => config.getStringBuf(key))
      .catch(_ => null)
  }

  // Public: Get the URL for the 'origin' remote.
  //
  // * `path` (optional) {String} path in the repository to get this information
  //   for, only needed if the repository has submodules.
  //
  // Returns a {Promise} which resolves to the {String} origin url of the
  // repository.
  getOriginURL (_path) {
    return this.getConfigValue('remote.origin.url', _path)
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
    return this.getRepo(_path)
      .then(repo => repo.getCurrentBranch())
      .then(branch => Git.Branch.upstream(branch))
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
    return this.getRepo(_path)
      .then(repo => repo.getReferences(Git.Reference.TYPE.LISTALL))
      .then(refs => {
        const heads = []
        const remotes = []
        const tags = []
        for (const ref of refs) {
          if (ref.isTag()) {
            tags.push(ref.name())
          } else if (ref.isRemote()) {
            remotes.push(ref.name())
          } else if (ref.isBranch()) {
            heads.push(ref.name())
          }
        }
        return {heads, remotes, tags}
      })
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
    return this.getRepo(_path)
      .then(repo => Git.Reference.nameToId(repo, reference))
      .then(oid => oid.tostrS())
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
    return this.relativizeToWorkingDirectory(_path)
      .then(relativePath => this._getStatus([relativePath]))
      .then(statuses => statuses.some(status => status.isModified()))
  }

  // Public: Resolves true if the given path is new.
  //
  // * `path` The {String} path to check.
  //
  // Returns a {Promise} which resolves to a {Boolean} that's true if the `path`
  // is new.
  isPathNew (_path) {
    return this.relativizeToWorkingDirectory(_path)
      .then(relativePath => this._getStatus([relativePath]))
      .then(statuses => statuses.some(status => status.isNew()))
  }

  // Public: Is the given path ignored?
  //
  // * `path` The {String} path to check.
  //
  // Returns a {Promise} which resolves to a {Boolean} that's true if the `path`
  // is ignored.
  isPathIgnored (_path) {
    return this.getRepo()
      .then(repo => {
        const relativePath = this.relativize(_path, repo.workdir())
        return Git.Ignore.pathIsIgnored(repo, relativePath)
      })
      .then(ignored => Boolean(ignored))
  }

  // Get the status of a directory in the repository's working directory.
  //
  // * `directoryPath` The {String} path to check.
  //
  // Returns a {Promise} resolving to a {Number} representing the status. This
  // value can be passed to {::isStatusModified} or {::isStatusNew} to get more
  // information.
  getDirectoryStatus (directoryPath) {
    return this.relativizeToWorkingDirectory(directoryPath)
      .then(relativePath => {
        const pathspec = relativePath + '/**'
        return this._getStatus([pathspec])
      })
      .then(statuses => {
        return Promise.all(statuses.map(s => s.statusBit())).then(bits => {
          return bits
            .filter(b => b > 0)
            .reduce((status, bit) => status | bit, 0)
        })
      })
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
    let relativePath
    return this.getRepo()
      .then(repo => {
        relativePath = this.relativize(_path, repo.workdir())
        return this._getStatus([relativePath])
      })
      .then(statuses => {
        const cachedStatus = this.pathStatusCache[relativePath] || 0
        const status = statuses[0] ? statuses[0].statusBit() : Git.Status.STATUS.CURRENT
        if (status !== cachedStatus) {
          if (status === Git.Status.STATUS.CURRENT) {
            delete this.pathStatusCache[relativePath]
          } else {
            this.pathStatusCache[relativePath] = status
          }

          this.emitter.emit('did-change-status', {path: _path, pathStatus: status})
        }

        return status
      })
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
    return this.relativizeToWorkingDirectory(_path)
      .then(relativePath => this.pathStatusCache[relativePath])
  }

  // Public: Get the cached statuses for the repository.
  //
  // Returns an {Object} of {Number} statuses, keyed by {String} working
  // directory-relative file names.
  getCachedPathStatuses () {
    return this.pathStatusCache
  }

  // Public: Returns true if the given status indicates modification.
  //
  // * `statusBit` A {Number} representing the status.
  //
  // Returns a {Boolean} that's true if the `statusBit` indicates modification.
  isStatusModified (statusBit) {
    return (statusBit & modifiedStatusFlags) > 0
  }

  // Public: Returns true if the given status indicates a new path.
  //
  // * `statusBit` A {Number} representing the status.
  //
  // Returns a {Boolean} that's true if the `statusBit` indicates a new path.
  isStatusNew (statusBit) {
    return (statusBit & newStatusFlags) > 0
  }

  // Public: Returns true if the given status indicates the path is staged.
  //
  // * `statusBit` A {Number} representing the status.
  //
  // Returns a {Boolean} that's true if the `statusBit` indicates the path is
  // staged.
  isStatusStaged (statusBit) {
    return (statusBit & indexStatusFlags) > 0
  }

  // Public: Returns true if the given status indicates the path is ignored.
  //
  // * `statusBit` A {Number} representing the status.
  //
  // Returns a {Boolean} that's true if the `statusBit` indicates the path is
  // ignored.
  isStatusIgnored (statusBit) {
    return (statusBit & ignoredStatusFlags) > 0
  }

  // Public: Returns true if the given status indicates the path is deleted.
  //
  // * `statusBit` A {Number} representing the status.
  //
  // Returns a {Boolean} that's true if the `statusBit` indicates the path is
  // deleted.
  isStatusDeleted (statusBit) {
    return (statusBit & deletedStatusFlags) > 0
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
    return this.getRepo()
      .then(repo => Promise.all([repo, repo.getHeadCommit()]))
      .then(([repo, headCommit]) => Promise.all([repo, headCommit.getTree()]))
      .then(([repo, tree]) => {
        const options = new Git.DiffOptions()
        options.contextLines = 0
        options.flags = Git.Diff.OPTION.DISABLE_PATHSPEC_MATCH
        options.pathspec = this.relativize(_path, repo.workdir())
        if (process.platform === 'win32') {
          // Ignore eol of line differences on windows so that files checked in
          // as LF don't report every line modified when the text contains CRLF
          // endings.
          options.flags |= Git.Diff.OPTION.IGNORE_WHITESPACE_EOL
        }
        return Git.Diff.treeToWorkdir(repo, tree, options)
      })
      .then(diff => this._getDiffLines(diff))
      .then(lines => {
        const stats = {added: 0, deleted: 0}
        for (const line of lines) {
          const origin = line.origin()
          if (origin === Git.Diff.LINE.ADDITION) {
            stats.added++
          } else if (origin === Git.Diff.LINE.DELETION) {
            stats.deleted++
          }
        }
        return stats
      })
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
    let relativePath = null
    return this.getRepo()
      .then(repo => {
        relativePath = this.relativize(_path, repo.workdir())
        return repo.getHeadCommit()
      })
      .then(commit => commit.getEntry(relativePath))
      .then(entry => entry.getBlob())
      .then(blob => {
        const options = new Git.DiffOptions()
        options.contextLines = 0
        if (process.platform === 'win32') {
          // Ignore eol of line differences on windows so that files checked in
          // as LF don't report every line modified when the text contains CRLF
          // endings.
          options.flags = Git.Diff.OPTION.IGNORE_WHITESPACE_EOL
        }
        return this._diffBlobToBuffer(blob, text, options)
      })
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
    return this.getRepo()
      .then(repo => {
        const checkoutOptions = new Git.CheckoutOptions()
        checkoutOptions.paths = [this.relativize(_path, repo.workdir())]
        checkoutOptions.checkoutStrategy = Git.Checkout.STRATEGY.FORCE | Git.Checkout.STRATEGY.DISABLE_PATHSPEC_MATCH
        return Git.Checkout.head(repo, checkoutOptions)
      })
      .then(() => this.refreshStatusForPath(_path))
  }

  // Public: Checks out a branch in your repository.
  //
  // * `reference` The {String} reference to checkout.
  // * `create`    A {Boolean} value which, if true creates the new reference if
  //   it doesn't exist.
  //
  // Returns a {Promise} that resolves if the method was successful.
  checkoutReference (reference, create) {
    return this.getRepo()
      .then(repo => repo.checkoutBranch(reference))
      .catch(error => {
        if (create) {
          return this._createBranch(reference)
            .then(_ => this.checkoutReference(reference, false))
        } else {
          throw error
        }
      })
      .then(_ => null)
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

  // Create a new branch with the given name.
  //
  // * `name` The {String} name of the new branch.
  //
  // Returns a {Promise} which resolves to a {NodeGit.Ref} reference to the
  // created branch.
  _createBranch (name) {
    return this.getRepo()
      .then(repo => Promise.all([repo, repo.getHeadCommit()]))
      .then(([repo, commit]) => repo.createBranch(name, commit))
  }

  // Get all the hunks in the diff.
  //
  // * `diff` The {NodeGit.Diff} whose hunks should be retrieved.
  //
  // Returns a {Promise} which resolves to an {Array} of {NodeGit.Hunk}.
  _getDiffHunks (diff) {
    return diff.patches()
      .then(patches => Promise.all(patches.map(p => p.hunks()))) // patches :: Array<Patch>
      .then(hunks => _.flatten(hunks)) // hunks :: Array<Array<Hunk>>
  }

  // Get all the lines contained in the diff.
  //
  // * `diff` The {NodeGit.Diff} use lines should be retrieved.
  //
  // Returns a {Promise} which resolves to an {Array} of {NodeGit.Line}.
  _getDiffLines (diff) {
    return this._getDiffHunks(diff)
      .then(hunks => Promise.all(hunks.map(h => h.lines())))
      .then(lines => _.flatten(lines)) // lines :: Array<Array<Line>>
  }

  // Diff the given blob and buffer with the provided options.
  //
  // * `blob` The {NodeGit.Blob}
  // * `buffer` The {String} buffer.
  // * `options` The {NodeGit.DiffOptions}
  //
  // Returns a {Promise} which resolves to an {Array} of {Object}s which have
  // the following keys:
  //   * `oldStart` The {Number} of the old starting line.
  //   * `newStart` The {Number} of the new starting line.
  //   * `oldLines` The {Number} of old lines.
  //   * `newLines` The {Number} of new lines.
  _diffBlobToBuffer (blob, buffer, options) {
    const hunks = []
    const hunkCallback = (delta, hunk, payload) => {
      hunks.push({
        oldStart: hunk.oldStart(),
        newStart: hunk.newStart(),
        oldLines: hunk.oldLines(),
        newLines: hunk.newLines()
      })
    }

    return Git.Diff.blobToBuffer(blob, null, buffer, null, options, null, null, hunkCallback, null)
      .then(_ => hunks)
  }

  // Get the current branch and update this.branch.
  //
  // Returns a {Promise} which resolves to a {boolean} indicating whether the
  // branch name changed.
  _refreshBranch () {
    return this.getRepo()
      .then(repo => repo.getCurrentBranch())
      .then(ref => ref.name())
      .then(branchName => {
        const changed = branchName !== this.branch
        this.branch = branchName
        return changed
      })
  }

  // Refresh the cached ahead/behind count with the given branch.
  //
  // * `branchName` The {String} name of the branch whose ahead/behind should be
  //                used for the refresh.
  //
  // Returns a {Promise} which will resolve to a {boolean} indicating whether
  // the ahead/behind count changed.
  _refreshAheadBehindCount (branchName) {
    return this.getAheadBehindCount(branchName)
      .then(counts => {
        const changed = !_.isEqual(counts, this.upstream)
        this.upstream = counts
        return changed
      })
  }

  // Get the status for this repository.
  //
  // Returns a {Promise} that will resolve to an object of {String} paths to the
  // {Number} status.
  _getRepositoryStatus () {
    let projectPathsPromises = [Promise.resolve('')]
    if (this.project) {
      projectPathsPromises = this.project.getPaths()
        .map(p => this.relativizeToWorkingDirectory(p))
    }

    return Promise.all(projectPathsPromises)
      .then(paths => paths.map(p => p.length > 0 ? p + '/**' : '*'))
      .then(projectPaths => {
        return this._getStatus(projectPaths.length > 0 ? projectPaths : null)
      })
      .then(statuses => {
        const statusPairs = statuses.map(status => [status.path(), status.statusBit()])
        return _.object(statusPairs)
      })
  }

  // Get the status for the given submodule.
  //
  // * `submodule` The {GitRepositoryAsync} for the submodule.
  //
  // Returns a {Promise} which resolves to an {Object}, keyed by {String}
  // repo-relative {Number} statuses.
  async _getSubmoduleStatus (submodule) {
    // At this point, we've called submodule._refreshSubmodules(), which would
    // have refreshed the status on *its* submodules, etc. So we know that its
    // cached path statuses are up-to-date.
    //
    // Now we just need to hoist those statuses into our repository by changing
    // their paths to be relative to us.

    const statuses = submodule.getCachedPathStatuses()
    const repoRelativeStatuses = {}
    const submoduleRepo = await submodule.getRepo()
    const submoduleWorkDir = submoduleRepo.workdir()
    for (const relativePath in statuses) {
      const statusBit = statuses[relativePath]
      const absolutePath = path.join(submoduleWorkDir, relativePath)
      const repoRelativePath = await this.relativizeToWorkingDirectory(absolutePath)
      repoRelativeStatuses[repoRelativePath] = statusBit
    }

    return repoRelativeStatuses
  }

  // Refresh the list of submodules in the repository.
  //
  // Returns a {Promise} which resolves to an {Object} keyed by {String}
  // submodule names with {GitRepositoryAsync} values.
  async _refreshSubmodules () {
    const repo = await this.getRepo()
    const submoduleNames = await repo.getSubmoduleNames()
    for (const name of submoduleNames) {
      const alreadyExists = Boolean(this.submodules[name])
      if (alreadyExists) continue

      const submodule = await Git.Submodule.lookup(repo, name)
      const absolutePath = path.join(repo.workdir(), submodule.path())
      const submoduleRepo = GitRepositoryAsync.open(absolutePath, {openExactPath: true, refreshOnWindowFocus: false})
      this.submodules[name] = submoduleRepo
    }

    for (const name in this.submodules) {
      const repo = this.submodules[name]
      const gone = submoduleNames.indexOf(name) < 0
      if (gone) {
        repo.destroy()
        delete this.submodules[name]
      } else {
        try {
          await repo.refreshStatus()
        } catch (e) {
          // libgit2 will sometimes report submodules that aren't actually valid
          // (https://github.com/libgit2/libgit2/issues/3580). So check the
          // validity of the submodules by removing any that fail.
          repo.destroy()
          delete this.submodules[name]
        }
      }
    }

    return _.values(this.submodules)
  }

  // Get the status for the submodules in the repository.
  //
  // Returns a {Promise} that will resolve to an object of {String} paths to the
  // {Number} status.
  _getSubmoduleStatuses () {
    return this._refreshSubmodules()
      .then(repos => {
        return Promise.all(repos.map(repo => this._getSubmoduleStatus(repo)))
      })
      .then(statuses => _.extend({}, ...statuses))
  }

  // Refresh the cached status.
  //
  // Returns a {Promise} which will resolve to a {boolean} indicating whether
  // any statuses changed.
  _refreshStatus () {
    return Promise.all([this._getRepositoryStatus(), this._getSubmoduleStatuses()])
      .then(([repositoryStatus, submoduleStatus]) => {
        const statusesByPath = _.extend({}, repositoryStatus, submoduleStatus)
        const changed = !_.isEqual(this.pathStatusCache, statusesByPath)
        this.pathStatusCache = statusesByPath
        return changed
      })
  }

  // Refreshes the git status.
  //
  // Returns a {Promise} which will resolve to {null} when refresh is complete.
  refreshStatus () {
    const status = this._refreshStatus()
    const branch = this._refreshBranch()
    const aheadBehind = branch.then(() => this._refreshAheadBehindCount(this.branch))

    this._refreshingPromise = this._refreshingPromise.then(_ => {
      return Promise.all([status, branch, aheadBehind])
        .then(([statusChanged, branchChanged, aheadBehindChanged]) => {
          if (this.emitter && (statusChanged || branchChanged || aheadBehindChanged)) {
            this.emitter.emit('did-change-statuses')
          }

          return null
        })
        // Because all these refresh steps happen asynchronously, it's entirely
        // possible the repository was destroyed while we were working. In which
        // case we should just swallow the error.
        .catch(e => {
          if (this._isDestroyed()) {
            return null
          } else {
            return Promise.reject(e)
          }
        })
        .catch(e => {
          console.error('Error refreshing repository status:')
          console.error(e)
          return Promise.reject(e)
        })
    })
    return this._refreshingPromise
  }

  // Get the submodule for the given path.
  //
  // Returns a {Promise} which resolves to the {GitRepositoryAsync} submodule or
  // null if it isn't a submodule path.
  async _submoduleForPath (_path) {
    let relativePath = await this.relativizeToWorkingDirectory(_path)
    for (const submodulePath in this.submodules) {
      const submoduleRepo = this.submodules[submodulePath]
      if (relativePath === submodulePath) {
        return submoduleRepo
      } else if (relativePath.indexOf(`${submodulePath}/`) === 0) {
        relativePath = relativePath.substring(submodulePath.length + 1)
        const innerSubmodule = await submoduleRepo._submoduleForPath(relativePath)
        return innerSubmodule || submoduleRepo
      }
    }

    return null
  }

  // Get the NodeGit repository for the given path.
  //
  // * `path` The optional {String} path within the repository. This is only
  //          needed if you want to get the repository for that path if it is a
  //          submodule.
  //
  // Returns a {Promise} which resolves to the {NodeGit.Repository}.
  getRepo (_path) {
    if (this._isDestroyed()) {
      const error = new Error('Repository has been destroyed')
      error.name = GitRepositoryAsync.DestroyedErrorName
      return Promise.reject(error)
    }

    if (!_path) return this.repoPromise

    return this._submoduleForPath(_path)
      .then(submodule => submodule ? submodule.getRepo() : this.repoPromise)
  }

  // Open a new instance of the underlying {NodeGit.Repository}.
  //
  // By opening multiple connections to the same underlying repository, users
  // can safely access the same repository concurrently.
  //
  // Returns the new {NodeGit.Repository}.
  openRepository () {
    if (this._openExactPath) {
      return Git.Repository.open(this.openedPath)
    } else {
      return Git.Repository.openExt(this.openedPath, 0, '')
    }
  }

  // Section: Private
  // ================

  // Has the repository been destroyed?
  //
  // Returns a {Boolean}.
  _isDestroyed () {
    return this.repoPromise == null
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

  // Get the status for the given paths.
  //
  // * `paths` The {String} paths whose status is wanted. If undefined, get the
  //           status for the whole repository.
  //
  // Returns a {Promise} which resolves to an {Array} of {NodeGit.StatusFile}
  // statuses for the paths.
  _getStatus (paths, repo) {
    return this.getRepo()
      .then(repo => {
        const opts = {
          flags: Git.Status.OPT.INCLUDE_UNTRACKED | Git.Status.OPT.RECURSE_UNTRACKED_DIRS
        }

        if (paths) {
          opts.pathspec = paths
        }

        return repo.getStatusExt(opts)
      })
  }
}
