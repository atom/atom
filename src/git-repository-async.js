'use babel'

const Git = require('nodegit')
const path = require('path')
const {Emitter, Disposable, CompositeDisposable} = require('event-kit')

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

  constructor (path, options) {
    this.repo = null
    this.emitter = new Emitter()
    this.subscriptions = new CompositeDisposable()
    this.pathStatusCache = {}
    this._gitUtilsRepo = GitUtils.open(path) // TODO remove after porting ::relativize
    this.repoPromise = Git.Repository.open(path)

    var {project, refreshOnWindowFocus} = options
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
    // XXX _filterSBD already gets repoPromise
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
        var newPathStatusCache = _.object(statusesByPath)
        return Promise.resolve(newPathStatusCache)
      })
    }).then((newPathStatusCache) => {
      if (!_.isEqual(this.pathStatusCache, newPathStatusCache)) {
        this.emitter.emit('did-change-statuses')
      }
      this.pathStatusCache = newPathStatusCache
      return Promise.resolve(newPathStatusCache)
    })
  }

  // Section: Private
  // ================

  subscribeToBuffer (buffer) {
    var getBufferPathStatus = () => {
      var _path = buffer.getPath()
      var bufferSubscriptions = new CompositeDisposable()

      if (_path) {
        // We don't need to do anything with this promise, we just want the
        // emitted event side effect
        this.getPathStatus(_path)
      }

      bufferSubscriptions.add(
        buffer.onDidSave(getBufferPathStatus),
        buffer.onDidReload(getBufferPathStatus),
        buffer.onDidChangePath(getBufferPathStatus)
      )

      bufferSubscriptions.add(() => {
        buffer.onDidDestroy(() => {
          bufferSubscriptions.dispose()
          this.subscriptions.remove(bufferSubscriptions)
        })
      })

      this.subscriptions.add(bufferSubscriptions)
      return
    }
  }

  getCachedPathStatus (_path) {
    return this.pathStatusCache[this._gitUtilsRepo.relativize(_path)]
  }

  // TODO fix with bitwise ops
  isStatusNew (statusBit) {
    return Object.is(statusBit, Git.Status.STATUS.WT_NEW) || Object.is(statusBit, Git.Status.STATUS.INDEX_NEW)
  }

  isStatusModified (statusBit) {
    return Object.is(statusBit, Git.Status.STATUS.WT_MODIFIED) || Object.is(statusBit, Git.Status.STATUS.INDEX_MODIFIED)
  }

  _filterStatusesByPath (_path) {
    // Surely I'm missing a built-in way to do this
    var basePath = null
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
