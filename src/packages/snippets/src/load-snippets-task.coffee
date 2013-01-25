Task = require 'Task'
TextMatePackage = require 'text-mate-package'

module.exports =
class LoadSnippetsTask extends Task
  constructor: (@snippets) ->
    super('snippets/src/load-snippets-handler')
    @packages = atom.getPackages()
    @packages.push(path: config.configDirPath)

  started: ->
    @loadNextPackageSnippets()

  loadNextPackageSnippets: ->
    unless @packages.length
      @snippets.loaded = true
      return

    @packageBeingLoaded = @packages.shift()
    if @packageBeingLoaded instanceof TextMatePackage
      method = 'loadTextmateSnippets'
    else
      method = 'loadAtomSnippets'
    @callWorkerMethod(method, @packageBeingLoaded.path)

  snippetsLoaded: (snippets) ->
    @snippets.add(snippet) for snippet in snippets
    @loadNextPackageSnippets()
