Git = require 'git-utils'
path = require 'path'

process.title = 'repository-status-handler'

module.exports = () ->
  @async()
  
  process.on 'message', ({repoPath, paths}) =>
    paths = paths || []

    repo = Git.open(repoPath)

    statuses = {}
    upstream = {}
    submodules = {}
    branch = null

    if repo?
      # Statuses in main repo
      workingDirectoryPath = repo.getWorkingDirectory()
      repoStatus = (if paths.length > 0 then repo.getStatusForPaths(paths) else repo.getStatus())
      for filePath, status of repoStatus
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

    emit repoPath, {statuses, upstream, branch, submodules}
