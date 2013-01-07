AtomPackage = require 'atom-package'
TextMatePackage = require 'text-mate-package'
fs = require 'fs'

AtomPackage.prototype.loadSnippets = ->
  snippetsDirPath = fs.join(@path, 'snippets')
  if fs.exists(snippetsDirPath)
    for snippetsPath in fs.list(snippetsDirPath)
      snippets.load(snippetsPath)

TextMatePackage.prototype.loadSnippets = ->
