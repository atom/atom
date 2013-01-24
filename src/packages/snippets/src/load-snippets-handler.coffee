fs = require 'fs'

module.exports =
  loadTextmateSnippets: (path) ->
    snippetsDirPath = fs.join(path, 'Snippets')
    snippets = fs.list(snippetsDirPath).map (snippetPath) ->
      fs.readPlist(snippetPath)
    @snippetsLoaded(snippets)

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

  snippetsLoaded: (snippets) -> callTaskMethod('snippetsLoaded', snippets)
