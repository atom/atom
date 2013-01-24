module.exports =
  loadTextmateSnippets: ({path}) ->
    fs = require 'fs'
    snippetsDirPath = fs.join(path, 'Snippets')
    snippets = fs.list(snippetsDirPath).map (snippetPath) ->
      fs.readPlist(snippetPath)
    self.postMessage
      type: 'loadSnippets'
      snippets: snippets

  loadAtomSnippets: ({path}) ->
    fs = require 'fs'
    snippetsDirPath = fs.join(path, 'snippets')
    snippets = []
    for snippetsPath in fs.list(snippetsDirPath)
      continue if fs.base(snippetsPath).indexOf('.') is 0
      try
        snippets.push(fs.readObject(snippetsPath))
      catch e
        console.warn "Error reading snippets file '#{snippetsPath}'"
    self.postMessage
      type: 'loadSnippets'
      snippets: snippets
