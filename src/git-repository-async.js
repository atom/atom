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

  isPathModified(_path) {
    // Surely I'm missing a built-in way to do this
    var basePath = null
    return this.repoPromise.then( (repo) => {
      basePath = repo.workdir()
      return repo.getStatus()
    }).then( (statuses) => {
      console.log(statuses.map(function(x){return x.path()}));
      ret = statuses.filter((status)=> {
        return _path == path.join(basePath, status.path()) && (status.isModified() || status.isDeleted())
      }).length > 0
      return Promise.resolve(ret)
    })
  }
}
