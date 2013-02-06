Task = require 'task'
TextMatePackage = require 'text-mate-package'

module.exports =
class LoadSnippetsTask extends Task
  constructor: (@snippets) ->
    super('snippets/src/load-snippets-handler')
    @packages = atom.getLoadedPackages()
    @packages.push(path: config.configDirPath)

  started: ->
    @loadNextPackageSnippets()

  loadNextPackageSnippets: ->
    unless @packages.length
      @terminate()
      @snippets.loaded = true
      return

    @packageBeingLoaded = @packages.shift()
    if @packageBeingLoaded instanceof TextMatePackage
      @loadTextMateSnippets(@packageBeingLoaded.path)
    else
      @loadAtomSnippets(@packageBeingLoaded.path)

  loadAtomSnippets: (path) ->
    @callWorkerMethod('loadAtomSnippets', path)

  loadTextMateSnippets: (path) ->
    @callWorkerMethod('loadTextMateSnippets', path)

  snippetsLoaded: (snippets) ->
    @snippets.add(snippet) for snippet in snippets
    @loadNextPackageSnippets()
