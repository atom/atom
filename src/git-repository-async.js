"use babel";

const Git = require('nodegit')
const path = require('path')

module.exports = class GitRepositoryAsync {
  static open(path) {
    // QUESTION: Should this wrap Git.Repository and reject with a nicer message?
    return new GitRepositoryAsync(Git.Repository.open(path))
  }

  constructor (openPromise) {
    this.repo = null
    // this could be replaced with a function
    this._opening = true

    // Do I use this outside of tests?
    openPromise.then( (repo) => {
      this.repo = repo
      this._opening = false
    }).catch( (e) => {
      this._opening = false
    })

    this.repoPromise = openPromise
  }

  getPath () {
    return this.repoPromise.then( (repo) => {
      return Promise.resolve(repo.path().replace(/\/$/, ''))
    })
  }

  isPathIgnored(_path) {
    return this.repoPromise.then( (repo) => {
      return Promise.resolve(Git.Ignore.pathIsIgnored(repo, _path))
    })
  }

  _filterStatusesByPath(_path) {
    // Surely I'm missing a built-in way to do this
    var basePath = null
    return this.repoPromise.then( (repo) => {
      basePath = repo.workdir()
      return repo.getStatus()
    }).then( (statuses) => {
      return statuses.filter(function (status) {
        return _path == path.join(basePath, status.path())
      })
    })
  }

  isPathModified(_path) {
    return this._filterStatusesByPath(_path).then(function(statuses) {
      var ret = statuses.filter((status)=> {
        return status.isModified()
      }).length > 0
      return Promise.resolve(ret)
    })
  }

  isPathNew(_path) {
    return this._filterStatusesByPath(_path).then(function(statuses) {
      var ret = statuses.filter((status)=> {
        return status.isNew()
      }).length > 0
      return Promise.resolve(ret)
    })
  }

  checkoutHead (_path) {
    return this.repoPromise.then(function (repo) {
      var checkoutOptions = new Git.CheckoutOptions()
      checkoutOptions.paths = [_path]
      checkoutOptions.checkoutStrategy = Git.Checkout.STRATEGY.FORCE | Git.Checkout.STRATEGY.DISABLE_PATHSPEC_MATCH
      Git.Checkout.head(repo, checkoutOptions)
    })
  }
}
