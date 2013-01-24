Task = require 'Task'
TextMatePackage = require 'text-mate-package'

module.exports =
class SnippetsTask extends Task

  constructor: (@snippets) ->
    super('snippets/src/snippets-reader')

    @packages = atom.getPackages()
    @packages.push(path: config.configDirPath)

  onProgress: (event) =>
    if event.data.type is 'loadSnippets'
      rawSnippets = event.data.snippets
      if @package instanceof TextMatePackage
        @snippets.add(@translateTextmateSnippets(rawSnippets))
      else
        @snippets.add(snippet) for snippet in rawSnippets

    @package = @packages.shift()
    if not @package?
      @snippets.loaded = true
      return

    if @package instanceof TextMatePackage
      eventType = 'loadTextmateSnippets'
    else
      eventType = 'loadAtomSnippets'
    { type: eventType, path: @package.path }

  translateTextmateSnippets: (tmSnippets) ->
    atomSnippets = {}
    for { scope, name, content, tabTrigger } in tmSnippets
      if scope
        scope = TextMatePackage.cssSelectorFromScopeSelector(scope)
      else
        scope = '*'

      snippetsForScope = (atomSnippets[scope] ?= {})
      snippetsForScope[name] = { prefix: tabTrigger, body: content }
    atomSnippets
