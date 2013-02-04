fs = require 'fs'
_ = require 'underscore'
Git = require 'git'

module.exports =
  loadPaths: (rootPath, ignoredNames, excludeGitIgnoredPaths) ->
    paths = []
    repo = Git.open(rootPath, refreshIndexOnFocus: false) if excludeGitIgnoredPaths
    isIgnored = (path) ->
      for segment in path.split('/')
        return true if _.contains(ignoredNames, segment)
      repo?.isPathIgnored(fs.join(rootPath, path))
    onFile = (path) ->
      paths.push(path) unless isIgnored(path)
    onDirectory = (path) ->
      not isIgnored(path)
    fs.traverseTree(rootPath, onFile, onDirectory)
    repo?.destroy()
    callTaskMethod('pathsLoaded', paths)
