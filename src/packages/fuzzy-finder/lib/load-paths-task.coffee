Task = require 'task'

module.exports =
class LoadPathsTask extends Task
  constructor: (@callback) ->
    super(require.resolve('./load-paths-handler'))

  started: ->
    @paths = []
    ignoredNames = config.get('fuzzyFinder.ignoredNames') ? []
    ignoredNames = ignoredNames.concat(config.get('core.ignoredNames') ? [])
    ignoreVcsIgnores = config.get('core.excludeVcsIgnoredPaths')
    @callWorkerMethod('loadPaths', project.getPath(), ignoreVcsIgnores, ignoredNames)

  pathsLoaded: (paths) ->
    @paths.push(paths...)
    @trigger 'paths-loaded', @paths

  pathLoadingComplete: ->
    @callback(@paths)
    @done()
