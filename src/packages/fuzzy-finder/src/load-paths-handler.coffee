fs = require 'fs'
_ = require 'underscore'
Git = require 'git'

module.exports =
  loadPaths: (rootPath, ignoredNames, ignoreGitIgnoredFiles) ->
    paths = []
    repo = Git.open(rootPath, refreshIndexOnFocus: false) if ignoreGitIgnoredFiles
    isIgnored = (path) ->
      for segment in path.split('/')
        return true if _.contains(ignoredNames, segment)
      return true if repo?.isPathIgnored(fs.join(rootPath, path))
      false
    onFile = (path) ->
      paths.push(path) unless isIgnored(path)
    onDirectory = (path) ->
      not isIgnored(path)
    fs.traverseTree(rootPath, onFile, onDirectory)
    repo?.destroy()
    callTaskMethod('pathsLoaded', paths)
