'use babel'

import fs from 'fs-plus'
import Git from 'nodegit'
import path from 'path'
import {Emitter, CompositeDisposable} from 'event-kit'

const modifiedStatusFlags = Git.Status.STATUS.WT_MODIFIED | Git.Status.STATUS.INDEX_MODIFIED | Git.Status.STATUS.WT_DELETED | Git.Status.STATUS.INDEX_DELETED | Git.Status.STATUS.WT_TYPECHANGE | Git.Status.STATUS.INDEX_TYPECHANGE
const newStatusFlags = Git.Status.STATUS.WT_NEW | Git.Status.STATUS.INDEX_NEW
const deletedStatusFlags = Git.Status.STATUS.WT_DELETED | Git.Status.STATUS.INDEX_DELETED
const indexStatusFlags = Git.Status.STATUS.INDEX_NEW | Git.Status.STATUS.INDEX_MODIFIED | Git.Status.STATUS.INDEX_DELETED | Git.Status.STATUS.INDEX_RENAMED | Git.Status.STATUS.INDEX_TYPECHANGE

// Just using this for _.isEqual and _.object, we should impl our own here
import _ from 'underscore-plus'

module.exports = class GitRepositoryAsync {
  static open (path, options = {}) {
    // QUESTION: Should this wrap Git.Repository and reject with a nicer message?
    return new GitRepositoryAsync(path, options)
  }

  static get Git () {
    return Git
  }

  constructor (path, options) {
    this.repo = null
    this.emitter = new Emitter()
    this.subscriptions = new CompositeDisposable()
    this.pathStatusCache = {}
    this.repoPromise = Git.Repository.open(path)
    this.isCaseInsensitive = fs.isCaseInsensitive()

    const {project} = options
    this.project = project

    if (this.project) {
      this.subscriptions.add(this.project.onDidAddBuffer(buffer => {
        this.subscribeToBuffer(buffer)
      }))

      this.project.getBuffers().forEach(buffer => { this.subscribeToBuffer(buffer) })
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

  getPath () {
    return this.repoPromise.then(repo => repo.path().replace(/\/$/, ''))
  }

  isPathIgnored (_path) {
    return this.repoPromise.then(repo => Git.Ignore.pathIsIgnored(repo, _path))
  }

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

  checkoutHead (_path) {
    return this.repoPromise
      .then(repo => {
        const checkoutOptions = new Git.CheckoutOptions()
        checkoutOptions.paths = [this.relativize(_path, repo.workdir())]
        checkoutOptions.checkoutStrategy = Git.Checkout.STRATEGY.FORCE | Git.Checkout.STRATEGY.DISABLE_PATHSPEC_MATCH
        return Git.Checkout.head(repo, checkoutOptions)
      })
      .then(() => this.getPathStatus(_path))
  }

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

  // Returns a Promise that resolves to the status bit of a given path if it has
  // one, otherwise 'current'.
  getPathStatus (_path) {
    let relativePath
    return this.repoPromise
      .then(repo => {
        relativePath = this.relativize(_path, repo.workdir())
        return this._filterStatusesByPath(_path)
      })
      .then(statuses => {
        const cachedStatus = this.pathStatusCache[relativePath] || 0
        const status = statuses[0] ? statuses[0].statusBit() : Git.Status.STATUS.CURRENT
        if (status !== cachedStatus && this.emitter != null) {
          this.emitter.emit('did-change-status', {path: _path, pathStatus: status})
        }
        this.pathStatusCache[relativePath] = status
        return status
      })
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

  // Get the current branch and update this.branch.
  //
  // Returns :: Promise<String>
  //            The branch name.
  _refreshBranch () {
    return this.repoPromise
      .then(repo => repo.getCurrentBranch())
      .then(ref => ref.name())
      .then(branchRef => this.branch = branchRef)
  }

  // Refreshes the git status. Note: the sync GitRepository class does this with
  // a separate process, let's see if we can avoid that.
  refreshStatus () {
    // TODO add upstream, branch, and submodule tracking
    const status = this.repoPromise
      .then(repo => repo.getStatus())
      .then(statuses => {
        // update the status cache
        return Promise.all(statuses.map(status => [status.path(), status.statusBit()]))
          .then(statusesByPath => _.object(statusesByPath))
      })
      .then(newPathStatusCache => {
        if (!_.isEqual(this.pathStatusCache, newPathStatusCache) && this.emitter != null) {
          this.emitter.emit('did-change-statuses')
        }
        this.pathStatusCache = newPathStatusCache
        return newPathStatusCache
      })

    const branch = this._refreshBranch()

    return Promise.all([status, branch])
  }

  // Section: Private
  // ================

  subscribeToBuffer (buffer) {
    const bufferSubscriptions = new CompositeDisposable()

    const getBufferPathStatus = () => {
      const _path = buffer.getPath()
      if (_path) {
        // We don't need to do anything with this promise, we just want the
        // emitted event side effect
        this.getPathStatus(_path)
      }
    }

    bufferSubscriptions.add(
      buffer.onDidSave(getBufferPathStatus),
      buffer.onDidReload(getBufferPathStatus),
      buffer.onDidChangePath(getBufferPathStatus),
      buffer.onDidDestroy(() => {
        bufferSubscriptions.dispose()
        this.subscriptions.remove(bufferSubscriptions)
      })
    )

    this.subscriptions.add(bufferSubscriptions)
    return
  }

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

  getCachedPathStatus (_path) {
    return this.repoPromise.then(repo => {
      return this.pathStatusCache[this.relativize(_path, repo.workdir())]
    })
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
  // Event subscription
  // ==================

  onDidChangeStatus (callback) {
    return this.emitter.on('did-change-status', callback)
  }

  onDidChangeStatuses (callback) {
    return this.emitter.on('did-change-statuses', callback)
  }

  onDidDestroy (callback) {
    return this.emitter.on('did-destroy', callback)
  }

  //
  // Section: Repository Details
  //

  // Returns a {Promise} that resolves true if at the root, false if in a
  // subfolder of the repository.
  isProjectAtRoot () {
    if (this.projectAtRoot === undefined) {
      this.projectAtRoot = Promise.resolve(() => {
        return this.repoPromise.then(repo => this.project.relativize(repo.workdir))
      })
    }

    return this.projectAtRoot
  }

  // Returns a {Promise} that resolves true if the given path is a submodule in
  // the repository.
  isSubmodule (_path) {
    return this.repoPromise
      .then(repo => repo.openIndex())
      .then(index => {
        const entry = index.getByPath(_path)
        const submoduleMode = 57344 // TODO compose this from libgit2 constants
        return entry.mode === submoduleMode
      })
  }
}
