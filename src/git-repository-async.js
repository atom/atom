'use babel'

const Git = require('nodegit')
const path = require('path')
const {Emitter, Disposable, CompositeDisposable} = require('event-kit')

// GitUtils is temporarily used for ::relativize only, because I don't want
// to port it just yet. TODO: remove
const GitUtils = require('git-utils')

module.exports = class GitRepositoryAsync {
  static open (path) {
    // QUESTION: Should this wrap Git.Repository and reject with a nicer message?
    return new GitRepositoryAsync(path)
  }

  constructor (path) {
    this.repo = null
    this.emitter = new Emitter()
    this.subscriptions = new CompositeDisposable()
    this.pathStatusCache = {}
    this._gitUtilsRepo = GitUtils.open(path) // TODO remove after porting ::relativize
    this.repoPromise = Git.Repository.open(path)
  }

  destroy () {
    this.subscriptions.dispose()
  }

  getPath () {
    return this.repoPromise.then((repo) => {
      return Promise.resolve(repo.path().replace(/\/$/, ''))
    })
  }

  isPathIgnored (_path) {
    return this.repoPromise.then((repo) => {
      return Promise.resolve(Git.Ignore.pathIsIgnored(repo, _path))
    })
  }

  isPathModified (_path) {
    return this._filterStatusesByPath(_path).then(function (statuses) {
      var ret = statuses.filter((status) => {
        return status.isModified()
      }).length > 0
      return Promise.resolve(ret)
    })
  }

  isPathNew (_path) {
    return this._filterStatusesByPath(_path).then(function (statuses) {
      var ret = statuses.filter((status) => {
        return status.isNew()
      }).length > 0
      return Promise.resolve(ret)
    })
  }

  checkoutHead (_path) {
    return this.repoPromise.then((repo) => {
      var checkoutOptions = new Git.CheckoutOptions()
      checkoutOptions.paths = [this._gitUtilsRepo.relativize(_path)]
      checkoutOptions.checkoutStrategy = Git.Checkout.STRATEGY.FORCE | Git.Checkout.STRATEGY.DISABLE_PATHSPEC_MATCH
      Git.Checkout.head(repo, checkoutOptions)
    })
  }

  // Returns a Promise that resolves to the status bit of a given path if it has
  // one, otherwise 'current'.
  getPathStatus (_path) {
    var relativePath = this._gitUtilsRepo.relativize(_path)
    return this.repoPromise.then((repo) => {
      return this._filterStatusesByPath(_path)
    }).then((statuses) => {
      var cachedStatus = this.pathStatusCache[relativePath] || 0
      var status = statuses[0] ? statuses[0].statusBit() : Git.Status.STATUS.CURRENT
      console.log('cachedStatus', cachedStatus, 'status', status)
      if (status !== cachedStatus) {
        this.emitter.emit('did-change-status', {path: _path, pathStatus: status})
      }
      this.pathStatusCache[relativePath] = status
      return Promise.resolve(status)
    })
  }

  // Get the status of a directory in the repository's working directory.
  //
  // * `directoryPath` The {String} path to check.
  //
  // Returns a promise resolving to a {Number} representing the status. This value can be passed to
  // {::isStatusModified} or {::isStatusNew} to get more information.

  getDirectoryStatus (directoryPath) {
    var relativePath = this._gitUtilsRepo.relativize(directoryPath)
    return this.repoPromise.then((repo) => {
      return this._filterStatusesByDirectory(relativePath)
    }).then((statuses) => {
      return Promise.all(statuses.map(function (s) { return s.statusBit() })).then(function (bits) {
        var ret = 0
        var filteredBits = bits.filter(function (b) { return b > 0 })
        if (filteredBits.length > 0) {
          ret = filteredBits.pop()
        }
        return Promise.resolve(ret)
      })
    })
  }

  // Utility functions
  // =================

  // TODO fix with bitwise ops
  isStatusNew (statusBit) {
    return statusBit === Git.Status.STATUS.WT_NEW || statusBit === Git.Status.STATUS.INDEX_NEW
  }

  isStatusModified (statusBit) {
    return statusBit === Git.Status.STATUS.WT_MODIFIED || statusBit === Git.Status.STATUS.INDEX_MODIFIED
  }

  _filterStatusesByPath (_path) {
    // Surely I'm missing a built-in way to do this
    var basePath = null
    return this.repoPromise.then((repo) => {
      basePath = repo.workdir()
      return repo.getStatus()
    }).then((statuses) => {
      console.log('statuses', statuses)
      return statuses.filter(function (status) {
        return _path === path.join(basePath, status.path())
      })
    })
  }

  _filterStatusesByDirectory (directoryPath) {
    return this.repoPromise.then(function (repo) {
      return repo.getStatus()
    }).then(function (statuses) {
      var filtered = statuses.filter((status) => {
        return status.path().indexOf(directoryPath) === 0
      })
      return Promise.resolve(filtered)
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

}
