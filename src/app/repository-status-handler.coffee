Git = require 'git-utils'
fsUtils = require 'fs-utils'
path = require 'path'

module.exports = (repoPath) ->
  repo = Git.open(repoPath)
  if repo?
    workingDirectoryPath = repo.getWorkingDirectory()
    statuses = {}
    for filePath, status of repo.getStatus()
      statuses[path.join(workingDirectoryPath, filePath)] = status
    upstream = repo.getAheadBehindCount()
    repo.release()
  else
    upstream = {}
    statuses = {}

  {statuses, upstream}
