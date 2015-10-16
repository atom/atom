'use babel'

const Git = require('nodegit')
const path = require('path')

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
    this._gitUtilsRepo = GitUtils.open(path) // TODO remove after porting ::relativize
    this.repoPromise = Git.Repository.open(path)
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
    return this.repoPromise.then(function (repo) {
      var checkoutOptions = new Git.CheckoutOptions()
      checkoutOptions.paths = [_path]
      checkoutOptions.checkoutStrategy = Git.Checkout.STRATEGY.FORCE | Git.Checkout.STRATEGY.DISABLE_PATHSPEC_MATCH
      Git.Checkout.head(repo, checkoutOptions)
    })
  }
}
