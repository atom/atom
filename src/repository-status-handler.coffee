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
      statuses[filePath] = status

    # Statuses in submodules
    for submodulePath, submoduleRepo of repo.submodules
      submodules[submodulePath] =
        branch: submoduleRepo.getHead()
        upstream: submoduleRepo.getAheadBehindCount()

      workingDirectoryPath = submoduleRepo.getWorkingDirectory()
      for filePath, status of submoduleRepo.getStatus()
        absolutePath = path.join(workingDirectoryPath, filePath)
        # Make path relative to parent repository
        relativePath = repo.relativize(absolutePath)
        statuses[relativePath] = status

    upstream = repo.getAheadBehindCount()
    branch = repo.getHead()
    repo.release()

  {statuses, upstream, branch, submodules}
