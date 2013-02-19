Task = require 'task'

module.exports =
class LoadPathsTask extends Task
  constructor: (@callback) ->
    super('fuzzy-finder/lib/load-paths-handler')

  started: ->
    ignoredNames = config.get('fuzzyFinder.ignoredNames') ? []
    ignoredNames = ignoredNames.concat(config.get('core.ignoredNames') ? [])
    excludeGitIgnoredPaths = config.get('core.hideGitIgnoredFiles')
    rootPath = rootView.project.getPath()
    @callWorkerMethod('loadPaths', rootPath, ignoredNames, excludeGitIgnoredPaths)

  pathsLoaded: (paths) ->
    @done()
    @callback(paths)
