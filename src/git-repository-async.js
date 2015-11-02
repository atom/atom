'use babel'

const Git = require('nodegit')
const path = require('path')
const {Emitter, Disposable, CompositeDisposable} = require('event-kit')

const modifiedStatusFlags = Git.Status.STATUS.WT_MODIFIED | Git.Status.STATUS.INDEX_MODIFIED | Git.Status.STATUS.WT_DELETED | Git.Status.STATUS.INDEX_DELETED | Git.Status.STATUS.WT_TYPECHANGE | Git.Status.STATUS.INDEX_TYPECHANGE
const newStatusFlags = Git.Status.STATUS.WT_NEW | Git.Status.STATUS.INDEX_NEW
const deletedStatusFlags = Git.Status.STATUS.WT_DELETED | Git.Status.STATUS.INDEX_DELETED
const indexStatusFlags = Git.Status.STATUS.INDEX_NEW | Git.Status.STATUS.INDEX_MODIFIED | Git.Status.STATUS.INDEX_DELETED | Git.Status.STATUS.INDEX_RENAMED | Git.Status.STATUS.INDEX_TYPECHANGE

// Temporary requires
// ==================
// GitUtils is temporarily used for ::relativize only, because I don't want
// to port it just yet. TODO: remove
const GitUtils = require('git-utils')
// Just using this for _.isEqual and _.object, we should impl our own here
const _ = require('underscore-plus')

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
    this._gitUtilsRepo = GitUtils.open(path) // TODO remove after porting ::relativize
    this.repoPromise = Git.Repository.open(path)

    let {project, refreshOnWindowFocus} = options
    this.project = project
    if (refreshOnWindowFocus === undefined) {
      refreshOnWindowFocus = true
    }
    if (refreshOnWindowFocus) {
      // TODO
    }

    if (this.project) {
      this.subscriptions.add(this.project.onDidAddBuffer((buffer) => {
        this.subscribeToBuffer(buffer)
      }))

      this.project.getBuffers().forEach((buffer) => { this.subscribeToBuffer(buffer) })
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
    return this.repoPromise.then((repo) => {
      return repo.path().replace(/\/$/, '')
    })
  }

  isPathIgnored (_path) {
    return this.repoPromise.then((repo) => {
      return Git.Ignore.pathIsIgnored(repo, _path)
    })
  }

  isPathModified (_path) {
    return this._filterStatusesByPath(_path).then(function (statuses) {
      return statuses.filter((status) => {
        return status.isModified()
      }).length > 0
    })
  }

  isPathNew (_path) {
    return this._filterStatusesByPath(_path).then(function (statuses) {
      return statuses.filter((status) => {
        return status.isNew()
      }).length > 0
    })
  }

  checkoutHead (_path) {
    return this.repoPromise.then((repo) => {
      let checkoutOptions = new Git.CheckoutOptions()
      checkoutOptions.paths = [this._gitUtilsRepo.relativize(_path)]
      checkoutOptions.checkoutStrategy = Git.Checkout.STRATEGY.FORCE | Git.Checkout.STRATEGY.DISABLE_PATHSPEC_MATCH
      return Git.Checkout.head(repo, checkoutOptions)
    }).then(() => {
      return this.getPathStatus(_path)
    })
  }

  checkoutHeadForEditor (editor) {
    return new Promise(function (resolve, reject) {
      let filePath = editor.getPath()
      if (filePath) {
        if (editor.buffer.isModified()) {
          editor.buffer.reload()
        }
        resolve(filePath)
      } else {
        reject()
      }
    }).then((filePath) => {
      return this.checkoutHead(filePath)
    })
  }

  // Returns a Promise that resolves to the status bit of a given path if it has
  // one, otherwise 'current'.
  getPathStatus (_path) {
    let relativePath = this._gitUtilsRepo.relativize(_path)
    return this.repoPromise.then((repo) => {
      return this._filterStatusesByPath(_path)
    }).then((statuses) => {
      let cachedStatus = this.pathStatusCache[relativePath] || 0
      let status = statuses[0] ? statuses[0].statusBit() : Git.Status.STATUS.CURRENT
      if (status !== cachedStatus) {
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
    let relativePath = this._gitUtilsRepo.relativize(directoryPath)
    // XXX _filterSBD already gets repoPromise
    return this.repoPromise.then((repo) => {
      return this._filterStatusesByDirectory(relativePath)
    }).then((statuses) => {
      return Promise.all(statuses.map(function (s) { return s.statusBit() })).then(function (bits) {
        let directoryStatus = 0
        let filteredBits = bits.filter(function (b) { return b > 0 })
        if (filteredBits.length > 0) {
          filteredBits.forEach(function (bit) {
            directoryStatus |= bit
          })
        }

        return directoryStatus
      })
    })
  }

  // Refreshes the git status. Note: the sync GitRepository class does this with
  // a separate process, let's see if we can avoid that.
  refreshStatus () {
    // TODO add upstream, branch, and submodule tracking
    return this.repoPromise.then((repo) => {
      return repo.getStatus()
    }).then((statuses) => {
      // update the status cache
      return Promise.all(statuses.map((status) => {
        return [status.path(), status.statusBit()]
      })).then((statusesByPath) => {
        return _.object(statusesByPath)
      })
    }).then((newPathStatusCache) => {
      if (!_.isEqual(this.pathStatusCache, newPathStatusCache)) {
        this.emitter.emit('did-change-statuses')
      }
      this.pathStatusCache = newPathStatusCache
      return newPathStatusCache
    })
  }

  // Section: Private
  // ================

  subscribeToBuffer (buffer) {
    let bufferSubscriptions = new CompositeDisposable()

    let getBufferPathStatus = () => {
      let _path = buffer.getPath()
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

  getCachedPathStatus (_path) {
    return this.pathStatusCache[this._gitUtilsRepo.relativize(_path)]
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
    return this.repoPromise.then((repo) => {
      basePath = repo.workdir()
      return repo.getStatus()
    }).then((statuses) => {
      return statuses.filter(function (status) {
        return _path === path.join(basePath, status.path())
      })
    })
  }

  _filterStatusesByDirectory (directoryPath) {
    return this.repoPromise.then(function (repo) {
      return repo.getStatus()
    }).then(function (statuses) {
      return statuses.filter((status) => {
        return status.path().indexOf(directoryPath) === 0
      })
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
        return this.repoPromise.then((repo) => {
          return this.project.relativize(repo.workdir)
        })
      })
    }

    return this.projectAtRoot
  }

  // Returns a {Promise} that resolves true if the given path is a submodule in
  // the repository.
  isSubmodule (_path) {
    return this.repoPromise.then(function (repo) {
      return repo.openIndex()
    }).then(function (index) {
      let entry = index.getByPath(_path)
      let submoduleMode = 57344 // TODO compose this from libgit2 constants

      if (entry.mode === submoduleMode) {
        return true
      } else {
        return false
      }
    })
  }
}
