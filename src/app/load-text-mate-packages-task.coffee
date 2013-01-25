Task = require 'Task'

module.exports =
class LoadTextMatePackagesTask extends Task

  constructor: (@packages) ->
    super('load-text-mate-packages-handler')

  started: ->
    @loadNextPackage()

  loadNextPackage: ->
    unless @packages.length
      rootView.trigger 'grammars-loaded'
      return

    @package = @packages.shift()
    @callWorkerMethod('loadPackage', @package.name)

  packageLoaded: (grammars) ->
    @package.loadGrammars(grammars)
    @loadNextPackage()
