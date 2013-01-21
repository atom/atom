AtomPackage = require 'atom-package'
TextMatePackage = require 'text-mate-package'
fs = require 'fs'

AtomPackage.prototype.loadSnippets = ->
  snippetsDirPath = fs.join(@path, 'snippets')
  snippets.loadDirectory(snippetsDirPath) if fs.exists(snippetsDirPath)

TextMatePackage.prototype.loadSnippets = ->
  snippetsDirPath = fs.join(@path, 'Snippets')
  if fs.exists(snippetsDirPath)
    tmSnippets = fs.list(snippetsDirPath).map (snippetPath) -> fs.readPlist(snippetPath)
    snippets.add(@translateSnippets(tmSnippets))

TextMatePackage.prototype.translateSnippets = (tmSnippets) ->
  atomSnippets = {}
  for { scope, name, content, tabTrigger } in tmSnippets
    if scope
      scope = TextMatePackage.cssSelectorFromScopeSelector(scope)
    else
      scope = '*'

    snippetsForScope = (atomSnippets[scope] ?= {})
    snippetsForScope[name] = { prefix: tabTrigger, body: content }
  atomSnippets
