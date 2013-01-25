fs = require 'fs'
TextMatePackage = require 'text-mate-package'

module.exports =
  snippetsLoaded: (snippets) -> callTaskMethod('snippetsLoaded', snippets)

  loadTextmateSnippets: (path) ->
    snippetsDirPath = fs.join(path, 'Snippets')
    snippets = fs.list(snippetsDirPath).map (snippetPath) ->
      fs.readPlist(snippetPath)
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
