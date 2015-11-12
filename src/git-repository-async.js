'use babel'

const path = require('path')

const fs = require('fs-plus')
const Git = require('nodegit')
const {Emitter, CompositeDisposable} = require('event-kit')

module.exports = class GitRepositoryAsync {
  static open (path, options = {}) {
    return new GitRepositoryAsync(path, options)
  }

  static get Git () {
    return Git
  }

  constructor (path, options) {
    this.project = options.project
    this.pathStatusCache = {}

    // All the async methods in this class will call this.repoPromise.then(...)
    this.repoPromise = Git.Repository.open(path)

    this.subscriptions = new CompositeDisposable()
    this.emitter = new Emitter()

    this.isCaseInsensitive = fs.isCaseInsensitive()

    if (this.project) {
      this.project.getBuffers().forEach((buffer) => { this.subscribeToBuffer(buffer) })

      this.subscriptions.add(this.project.onDidAddBuffer((buffer) => {
        this.subscribeToBuffer(buffer)
      }))
    }

    return this
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
        this.getPathStatus(_path).catch(function (e) {
          console.trace(e)
        })
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

  relativizeAsync (_path) {
    this.repoPromise.then((repo) => {
      return this.relativize(_path, repo.workdir())
    })
  }

  relativize (_path, workingDirectory) {
    if (!Boolean(workingDirectory)) {
      workingDirectory = this.getWorkingDirectorySync() // TODO
    }
    // Cargo-culted from git-utils. Could use a refactor maybe. Short circuits everywhere!
    if (!_path) {
      return _path
    }

    if (process.platform === 'win32') {
      _path = _path.replace(/\\/g, '/')
    } else {
      if (_path[0] !== '/') {
        return _path
      }
    }

    if (this.isCaseInsensitive) {
      let lowerCasePath = _path.toLowerCase()

      if (workingDirectory) {
        workingDirectory = workingDirectory.toLowerCase()
        if (lowerCasePath.indexOf(`${workingDirectory}/`) === 0) {
          return _path.substring(workingDirectory.length + 1)
        } else {
          if (lowerCasePath === workingDirectory) {
            return ''
          }
        }
      }

      if (this.openedWorkingDirectory) {
        workingDirectory = this.openedWorkingDirectory.toLowerCase()
        if (lowerCasePath.indexOf(`${workingDirectory}/`) === 0) {
          return _path.substring(workingDirectory.length + 1)
        } else {
          if (lowerCasePath === workingDirectory) {
            return ''
          }
        }
      }
    } else {
      workingDirectory = this.getWorkingDirectory() // TODO
      if (workingDirectory) {
        if (_path.indexOf(`${workingDirectory}/`) === 0) {
          return _path.substring(workingDirectory.length + 1)
        } else {
          if (_path === workingDirectory) {
            return ''
          }
        }
      }

      if (this.openedWorkingDirectory) {
        if (_path.indexOf(`${this.openedWorkingDirectory}/`) === 0) {
          return _path.substring(this.openedWorkingDirectory.length + 1)
        } else {
          if (_path === this.openedWorkingDirectory) {
            return ''
          }
        }
      }
    }
    return _path
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

  // Returns a Promise that resolves to the status bit of a given path if it has
  // one, otherwise 'current'.
  getPathStatus (_path) {
    let relativePath
    return this.repoPromise.then((repo) => {
      relativePath = this.relativize(_path, repo.workdir())
      return this._filterStatusesByPath(_path)
    }).then(statuses => {
      let cachedStatus = this.pathStatusCache[relativePath] || 0
      let status = statuses[0] ? statuses[0].statusBit() : Git.Status.STATUS.CURRENT

      if (status > 0) {
        this.pathStatusCache[relativePath] = status
      } else {
        delete this.pathStatusCache[relativePath]
      }

      if (status !== cachedStatus) {
        this.emitter.emit('did-change-status', {path: _path, pathStatus: status})
      }

      return status
    }).catch(e => {
      console.trace(e)
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
