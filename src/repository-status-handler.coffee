Git = require 'git-utils'
path = require 'path'

module.exports = (repoPath, paths = []) ->
  repo = Git.open(repoPath)

  upstream = {}
  submodules = {}

  if repo?
    for submodulePath, submoduleRepo of repo.submodules
      submodules[submodulePath] =
        branch: submoduleRepo.getHead()
        upstream: submoduleRepo.getAheadBehindCount()

    upstream = repo.getAheadBehindCount()
    repo.release()

  {upstream, submodules}
