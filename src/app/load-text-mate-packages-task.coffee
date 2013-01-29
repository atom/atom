Task = require 'Task'

module.exports =
class LoadTextMatePackagesTask extends Task

  constructor: (@packages) ->
    super('load-text-mate-packages-handler')

  started: ->
    @loadNextPackage()

  loadNextPackage: ->
    unless @packages.length
      @terminate()
      syntax.trigger 'grammars-loaded'
      return

    @package = @packages.shift()
    @loadPackage(@package.name)

  loadPackage: (name) ->
    @callWorkerMethod('loadPackage', name)

  packageLoaded: (grammars) ->
    @package.loadGrammars(grammars)
    @loadNextPackage()
