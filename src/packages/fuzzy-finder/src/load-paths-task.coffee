Task = require 'task'

module.exports =
class LoadPathsTask extends Task
  constructor: (@rootView, @callback)->
    super('fuzzy-finder/src/load-paths-handler')

  started: ->
    ignoredNames = config.get("fuzzyFinder.ignoredNames") ? []
    ignoredNames = ignoredNames.concat(config.get("core.ignoredNames") ? [])
    ignoreGitIgnoredFiles = config.get("core.hideGitIgnoredFiles")
    rootPath = @rootView.project.getPath()
    @callWorkerMethod('loadPaths', rootPath, ignoredNames, ignoreGitIgnoredFiles)

  pathsLoaded: (paths) ->
    @terminate()
    @callback(paths)
