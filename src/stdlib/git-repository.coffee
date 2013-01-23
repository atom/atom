class window.GitRepository
  constructor: (path) ->
    unless repo = $git.getRepository(path)
      throw new Error("No Git repository found searching path: " + path)
    repo.constructor = GitRepository
    repo.__proto__ = GitRepository.prototype
    return repo

  getHead: $git.getHead
  getPath: $git.getPath
  getStatus: $git.getStatus
  isIgnored: $git.isIgnored
  checkoutHead: $git.checkoutHead
  getDiffStats: $git.getDiffStats
  isSubmodule: $git.isSubmodule
  refreshIndex: $git.refreshIndex
  destroy: $git.destroy
