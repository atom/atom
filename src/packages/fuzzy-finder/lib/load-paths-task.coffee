Task = require 'task'

module.exports =
class LoadPathsTask extends Task
  constructor: (@callback) ->
    super(require.resolve('./load-paths-handler'))

  started: ->
    @paths = []
    ignoredNames = config.get('fuzzyFinder.ignoredNames') ? []
    ignoredNames = ignoredNames.concat(config.get('core.ignoredNames') ? [])
    @callWorkerMethod('loadPaths', project.getPath(), ignoredNames)

  pathsLoaded: (paths) ->
    @paths.push(paths...)

  pathLoadingComplete: ->
    @callback(@paths)
    @done()
