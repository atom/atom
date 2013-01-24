eval("window = {};")
eval("console = {};")
console.warn = ->
  self.postMessage
    type: 'warn'
    details: arguments
console.log = ->
  self.postMessage
    type: 'warn'
    details: arguments
eval("attachEvent = function(){};")

self.addEventListener 'message', (event) ->
  switch event.data.type
    when 'start'
      window.resourcePath = event.data.resourcePath
      importScripts(event.data.requirePath)
      self.postMessage(type:'started')
    else
      self[event.data.type](event.data)

self.loadTextmateSnippets = ({path}) ->
  fs = require 'fs'
  snippetsDirPath = fs.join(path, 'Snippets')
  snippets = fs.list(snippetsDirPath).map (snippetPath) ->
    fs.readPlist(snippetPath)
  self.postMessage
    type: 'loadSnippets'
    snippets: snippets

self.loadAtomSnippets = ({path}) ->
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
