Git = require 'git-utils'
path = require 'path'

module.exports = (repoPath) ->
  repo = Git.open(repoPath)
  if repo?
    workingDirectoryPath = repo.getWorkingDirectory()
    statuses = {}

    # Statuses in main repo
    for filePath, status of repo.getStatus()
      statuses[path.join(workingDirectoryPath, filePath)] = status

    # Statuses in submodules
    for submodulePath, submoduleRepo of repo.submodules
      workingDirectoryPath = submoduleRepo.getWorkingDirectory()
      for filePath, status of submoduleRepo.getStatus()
        statuses[path.join(workingDirectoryPath, filePath)] = status

    upstream = repo.getAheadBehindCount()
    branch = repo.getHead()
    repo.release()
  else
    upstream = {}
    statuses = {}
    branch = null

  {statuses, upstream, branch}
