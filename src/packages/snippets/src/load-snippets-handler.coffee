fs = require 'fs'
TextMatePackage = require 'text-mate-package'
PEG = require 'pegjs'

module.exports =

  parser: PEG.buildParser(fs.read(require.resolve 'snippets/snippets.pegjs'), trackLineAndColumn: true)

  snippetsLoaded: (snippets) ->
    for snippet in snippets
      for selector, snippetsByName of snippet
        for name, attributes of snippetsByName
          attributes.bodyTree = @parser.parse(attributes.body)
    callTaskMethod('snippetsLoaded', snippets)

  loadTextmateSnippets: (path) ->
    snippetsDirPath = fs.join(path, 'Snippets')
    snippets = []

    for snippetsPath in fs.list(snippetsDirPath)
      logWarning = ->
        console.warn "Error reading TextMate snippets file '#{snippetsPath}'"

      continue if fs.base(snippetsPath).indexOf('.') is 0
      try
        if object = fs.readPlist(snippetsPath)
          snippets.push(object) if object
        else
          logWarning()
      catch e
        logWarning()

    @snippetsLoaded(@translateTextmateSnippets(snippets))

  loadAtomSnippets: (path) ->
    snippetsDirPath = fs.join(path, 'snippets')
    snippets = []
    for snippetsPath in fs.list(snippetsDirPath)
      continue if fs.base(snippetsPath).indexOf('.') is 0
      try
        snippets.push(fs.readObject(snippetsPath))
      catch e
        console.warn "Error reading snippets file '#{snippetsPath}'"
    @snippetsLoaded(snippets)

  translateTextmateSnippets: (tmSnippets) ->
    atomSnippets = {}
    for { scope, name, content, tabTrigger } in tmSnippets
      if scope
        scope = TextMatePackage.cssSelectorFromScopeSelector(scope)
      else
        scope = '*'

      snippetsForScope = (atomSnippets[scope] ?= {})
      snippetsForScope[name] = { prefix: tabTrigger, body: content }
    [atomSnippets]
