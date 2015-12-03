'use babel'

import fs from 'fs-plus'
import Git from 'nodegit'
import path from 'path'
import {Emitter, CompositeDisposable, Disposable} from 'event-kit'

const modifiedStatusFlags = Git.Status.STATUS.WT_MODIFIED | Git.Status.STATUS.INDEX_MODIFIED | Git.Status.STATUS.WT_DELETED | Git.Status.STATUS.INDEX_DELETED | Git.Status.STATUS.WT_TYPECHANGE | Git.Status.STATUS.INDEX_TYPECHANGE
const newStatusFlags = Git.Status.STATUS.WT_NEW | Git.Status.STATUS.INDEX_NEW
const deletedStatusFlags = Git.Status.STATUS.WT_DELETED | Git.Status.STATUS.INDEX_DELETED
const indexStatusFlags = Git.Status.STATUS.INDEX_NEW | Git.Status.STATUS.INDEX_MODIFIED | Git.Status.STATUS.INDEX_DELETED | Git.Status.STATUS.INDEX_RENAMED | Git.Status.STATUS.INDEX_TYPECHANGE

// Just using this for _.isEqual and _.object, we should impl our own here
import _ from 'underscore-plus'

export default class GitRepositoryAsync {
  static open (path, options = {}) {
    // QUESTION: Should this wrap Git.Repository and reject with a nicer message?
    return new GitRepositoryAsync(path, options)
  }

  static get Git () {
    return Git
  }

  constructor (_path, options) {
    this.repo = null
    this.emitter = new Emitter()
    this.subscriptions = new CompositeDisposable()
    this.pathStatusCache = {}
    this.repoPromise = Git.Repository.open(_path)
    this.isCaseInsensitive = fs.isCaseInsensitive()
    this.upstreamByPath = {}

    this._refreshingCount = 0

    let {refreshOnWindowFocus} = options || true
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
  }

  // Event subscription
  // ==================

  onDidDestroy (callback) {
    return this.emitter.on('did-destroy', callback)
  }

  onDidChangeStatus (callback) {
    return this.emitter.on('did-change-status', callback)
  }

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
    return this.repoPromise.then(repo => repo.path().replace(/\/$/, ''))
  }

  // Public: Returns a {Promise} which resolves to the {String} working
  // directory path of the repository.
  getWorkingDirectory () {
    return this.repoPromise.then(repo => repo.workdir())
  }

  // Public: Returns a {Promise} that resolves to true if at the root, false if
  // in a subfolder of the repository.
  isProjectAtRoot () {
    if (!this.projectAtRoot && this.project) {
      this.projectAtRoot = Promise.resolve(() => {
        return this.repoPromise.then(repo => this.project.relativize(repo.workdir()))
      })
    }

    return this.projectAtRoot
  }

  // Public: Makes a path relative to the repository's working directory.
  relativize (_path, workingDirectory) {
    // Cargo-culted from git-utils. The original implementation also handles
    // this.openedWorkingDirectory, which is set by git-utils when the
    // repository is opened. Those branches of the if tree aren't included here
    // yet, but if we determine we still need that here it should be simple to
    // port.
    //
    // The original implementation also handled null workingDirectory as it
    // pulled it from a sync function that could return null. We require it
    // to be passed here.
    if (!_path || !workingDirectory) {
      return _path
    }

    if (process.platform === 'win32') {
      _path = _path.replace(/\\/g, '/')
    } else {
      if (_path[0] !== '/') {
        return _path
      }
    }

    if (!/\/$/.test(workingDirectory)) {
      workingDirectory = `${workingDirectory}/`
    }

    if (this.isCaseInsensitive) {
      const lowerCasePath = _path.toLowerCase()

      workingDirectory = workingDirectory.toLowerCase()
      if (lowerCasePath.indexOf(workingDirectory) === 0) {
        return _path.substring(workingDirectory.length)
      } else {
        if (lowerCasePath === workingDirectory) {
          return ''
        }
      }
    }

    return _path
  }

  // Public: Returns a {Promise} which resolves to whether the given branch
  // exists.
  hasBranch (branch) {
    return this.repoPromise
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
    return this._getRepo(_path)
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
    return this.repoPromise
      .then(repo => repo.openIndex())
      .then(index => {
        // TODO: This'll probably be wrong if the submodule doesn't exist in the
        // index yet? Is that a thing?
        const entry = index.getByPath(_path)
        const submoduleMode = 57344 // TODO compose this from libgit2 constants
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
    return this._getRepo(_path)
      .then(repo => Promise.all([repo, repo.getBranch(reference)]))
      .then(([repo, local]) => Promise.all([repo, local, Git.Branch.upstream(local)]))
      .then(([repo, local, upstream]) => {
        if (!upstream) return {ahead: 0, behind: 0}

        return Git.Graph.aheadBehind(repo, local.target(), upstream.target())
      })
  }

  // Public: Get the cached ahead/behind commit counts for the current branch's
  // upstream branch.
  //
  // * `path` An optional {String} path in the repository to get this information
  //   for, only needed if the repository has submodules.
  //
  // Returns an {Object} with the following keys:
  //   * `ahead`  The {Number} of commits ahead.
  //   * `behind` The {Number} of commits behind.
  getCachedUpstreamAheadBehindCount (_path) {
    return this.upstreamByPath[_path || '.']
  }

  // Public: Returns the git configuration value specified by the key.
  //
  // * `path` An optional {String} path in the repository to get this information
  //   for, only needed if the repository has submodules.
  //
  // Returns a {Promise} which resolves to the {String} git configuration value
  // specified by the key.
  getConfigValue (key, _path) {
    return this._getRepo(_path)
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
    return this._getRepo(_path)
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
    return this._getRepo(_path)
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
    return this._getRepo(_path)
      .then(repo => Git.Reference.nameToId(repo, reference))
      .then(oid => oid.tostrS())
  }

  // Reading Status
  // ==============

  isPathModified (_path) {
    return this._filterStatusesByPath(_path).then(statuses => {
      return statuses.filter(status => status.isModified()).length > 0
    })
  }

  isPathNew (_path) {
    return this._filterStatusesByPath(_path).then(statuses => {
      return statuses.filter(status => status.isNew()).length > 0
    })
  }

  isPathIgnored (_path) {
    return this.repoPromise.then(repo => Git.Ignore.pathIsIgnored(repo, _path))
  }

  // Get the status of a directory in the repository's working directory.
  //
  // * `directoryPath` The {String} path to check.
  //
  // Returns a promise resolving to a {Number} representing the status. This value can be passed to
  // {::isStatusModified} or {::isStatusNew} to get more information.

  getDirectoryStatus (directoryPath) {
    let relativePath
    // XXX _filterSBD already gets repoPromise
    return this.repoPromise
      .then(repo => {
        relativePath = this.relativize(directoryPath, repo.workdir())
        return this._filterStatusesByDirectory(relativePath)
      })
      .then(statuses => {
        return Promise.all(statuses.map(s => s.statusBit())).then(bits => {
          let directoryStatus = 0
          const filteredBits = bits.filter(b => b > 0)
          if (filteredBits.length > 0) {
            filteredBits.forEach(bit => directoryStatus |= bit)
          }

          return directoryStatus
        })
      })
  }

  // Refresh the status bit for the given path.
  //
  // Note that if the status of the path has changed, this will emit a
  // 'did-change-status' event.
  //
  // path    :: String
  //            The path whose status should be refreshed.
  //
  // Returns :: Promise<Number>
  //            The refreshed status bit for the path.
  refreshStatusForPath (_path) {
    this._refreshingCount++

    let relativePath
    return this.repoPromise
      .then(repo => {
        relativePath = this.relativize(_path, repo.workdir())
        return this._filterStatusesByPath(_path)
      })
      .then(statuses => {
        const cachedStatus = this.pathStatusCache[relativePath] || 0
        const status = statuses[0] ? statuses[0].statusBit() : Git.Status.STATUS.CURRENT
        if (status !== cachedStatus) {
          this.pathStatusCache[relativePath] = status
          this.emitter.emit('did-change-status', {path: _path, pathStatus: status})
        }

        return status
      })
      .then(status => {
        this._refreshingCount--
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
    return this.repoPromise
      .then(repo => this.relativize(_path, repo.workdir()))
      .then(relativePath => this.pathStatusCache[relativePath])
  }

  isStatusNew (statusBit) {
    return (statusBit & newStatusFlags) > 0
  }

  isStatusModified (statusBit) {
    return (statusBit & modifiedStatusFlags) > 0
  }

  isStatusStaged (statusBit) {
    return (statusBit & indexStatusFlags) > 0
  }

  isStatusIgnored (statusBit) {
    return (statusBit & (1 << 14)) > 0
  }

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
    return this.repoPromise
      .then(repo => Promise.all([repo, repo.getHeadCommit()]))
      .then(([repo, headCommit]) => Promise.all([repo, headCommit.getTree()]))
      .then(([repo, tree]) => {
        const options = new Git.DiffOptions()
        options.pathspec = _path
        return Git.Diff.treeToWorkdir(repo, tree, options)
      })
      .then(diff => diff.patches())
      .then(patches => Promise.all(patches.map(p => p.hunks()))) // patches :: Array<Patch>
      .then(hunks => Promise.all(_.flatten(hunks).map(h => h.lines()))) // hunks :: Array<Array<Hunk>>
      .then(lines => { // lines :: Array<Array<Line>>
        const stats = {added: 0, deleted: 0}
        for (const line of _.flatten(lines)) {
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
    // # Ignore eol of line differences on windows so that files checked in as
    // # LF don't report every line modified when the text contains CRLF endings.
    // options = ignoreEolWhitespace: process.platform is 'win32'
    // repo = @getRepo(path)
    // repo.getLineDiffs(repo.relativize(path), text, options)
    throw new Error('Unimplemented')
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
    return this.repoPromise
      .then(repo => {
        const checkoutOptions = new Git.CheckoutOptions()
        checkoutOptions.paths = [this.relativize(_path, repo.workdir())]
        checkoutOptions.checkoutStrategy = Git.Checkout.STRATEGY.FORCE | Git.Checkout.STRATEGY.DISABLE_PATHSPEC_MATCH
        return Git.Checkout.head(repo, checkoutOptions)
      })
      .then(() => this.refreshStatusForPath(_path))
  }

  _createBranch (name) {
    return this.repoPromise
      .then(repo => Promise.all([repo, repo.getHeadCommit()]))
      .then(([repo, commit]) => repo.createBranch(name, commit))
  }

  // Public: Checks out a branch in your repository.
  //
  // * `reference` The {String} reference to checkout.
  // * `create`    A {Boolean} value which, if true creates the new reference if
  //   it doesn't exist.
  //
  // Returns a {Promise} that resolves if the method was successful.
  checkoutReference (reference, create) {
    return this.repoPromise
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
    return new Promise((resolve, reject) => {
      const filePath = editor.getPath()
      if (filePath) {
        if (editor.buffer.isModified()) {
          editor.buffer.reload()
        }
        resolve(filePath)
      } else {
        reject()
      }
    }).then(filePath => this.checkoutHead(filePath))
  }

  // Get the current branch and update this.branch.
  //
  // Returns :: Promise<String>
  //            The branch name.
  _refreshBranch () {
    return this.repoPromise
      .then(repo => repo.getCurrentBranch())
      .then(ref => ref.name())
      .then(branchName => this.branch = branchName)
  }

  _refreshAheadBehindCount (branchName) {
    return this.getAheadBehindCount(branchName)
      .then(counts => this.upstreamByPath['.'] = counts)
  }

  _refreshStatus () {
    this._refreshingCount++

    return this.repoPromise
      .then(repo => repo.getStatus())
      .then(statuses => {
        // update the status cache
        const statusPairs = statuses.map(status => [status.path(), status.statusBit()])
        return Promise.all(statusPairs)
          .then(statusesByPath => _.object(statusesByPath))
      })
      .then(newPathStatusCache => {
        if (!_.isEqual(this.pathStatusCache, newPathStatusCache) && this.emitter != null) {
          this.emitter.emit('did-change-statuses')
        }
        this.pathStatusCache = newPathStatusCache
        return newPathStatusCache
      })
      .then(_ => this._refreshingCount--)
  }

  // Refreshes the git status.
  //
  // Returns :: Promise<null>
  //            Resolves when refresh has completed.
  refreshStatus () {
    // TODO add submodule tracking

    const status = this._refreshStatus()
    const branch = this._refreshBranch()
    const aheadBehind = branch.then(branchName => this._refreshAheadBehindCount(branchName))

    return Promise.all([status, branch, aheadBehind]).then(_ => null)
  }

  // Section: Private
  // ================

  _isRefreshing () {
    return this._refreshingCount === 0
  }

  _getRepo (_path) {
    if (!_path) return this.repoPromise

    return this.isSubmodule(_path)
      .then(isSubmodule => {
        if (isSubmodule) {
          return Git.Repository.open(_path)
        } else {
          return this.repoPromise
        }
      })
  }

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
    return
  }

  _filterStatusesByPath (_path) {
    // Surely I'm missing a built-in way to do this
    let basePath = null
    return this.repoPromise
      .then(repo => {
        basePath = repo.workdir()
        return repo.getStatus()
      })
      .then(statuses => {
        return statuses.filter(status => _path === path.join(basePath, status.path()))
      })
  }

  _filterStatusesByDirectory (directoryPath) {
    return this.repoPromise
      .then(repo => repo.getStatus())
      .then(statuses => {
        return statuses.filter(status => status.path().indexOf(directoryPath) === 0)
      })
  }
}
