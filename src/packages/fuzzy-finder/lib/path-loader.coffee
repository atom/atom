Task = require 'task'

module.exports =
  startTask: (callback) ->
    projectPaths = []
    taskPath = require.resolve('./load-paths-handler')
    ignoredNames = config.get('fuzzyFinder.ignoredNames') ? []
    ignoredNames = ignoredNames.concat(config.get('core.ignoredNames') ? [])
    ignoreVcsIgnores = config.get('core.excludeVcsIgnoredPaths')

    task = Task.once taskPath, project.getPath(), ignoreVcsIgnores, ignoredNames, ->
      callback(projectPaths)

    task.on 'load-paths:paths-found', (paths) =>
      projectPaths.push(paths...)

    task
