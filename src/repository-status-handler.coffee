Git = require 'git-utils'
path = require 'path'

module.exports = (repoPath) ->
  repo = Git.open(repoPath)

  upstream = {}
  statuses = {}
  submodules = {}
  branch = null

  if repo?
    # Statuses in main repo
    workingDirectoryPath = repo.getWorkingDirectory()
    for filePath, status of repo.getStatus()
      statuses[path.join(workingDirectoryPath, filePath)] = status

    # Statuses in submodules
    for submodulePath, submoduleRepo of repo.submodules
      submodules[submodulePath] =
        upstream: submoduleRepo.getAheadBehindCount()
        branch: submoduleRepo.getHead()

      workingDirectoryPath = submoduleRepo.getWorkingDirectory()
      for filePath, status of submoduleRepo.getStatus()
        statuses[path.join(workingDirectoryPath, filePath)] = status

    upstream = repo.getAheadBehindCount()
    branch = repo.getHead()
    repo.release()

  {statuses, upstream, branch, submodules}
