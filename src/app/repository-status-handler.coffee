Git = nodeRequire 'git-utils'
fs = require 'fs'

module.exports =
  loadStatuses: (path) ->
    repo = Git.open(path)
    if repo?
      workingDirectoryPath = repo.getWorkingDirectory()
      statuses = {}
      for path, status of repo.getStatuses()
        statuses[fs.join(workingDirectoryPath, path)] = status
      upstream = repo.getAheadBehindCount()
    else
      upstream = {}
      statuses = {}

    callTaskMethod('statusesLoaded', {statuses, upstream})
