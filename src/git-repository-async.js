"use babel";

const Git = require('nodegit')

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
}
