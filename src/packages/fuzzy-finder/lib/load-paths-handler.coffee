fs = require 'fs'
_ = require 'underscore'

module.exports =
  loadPaths: (rootPath, ignoredNames, excludeGitIgnoredPaths) ->
    if excludeGitIgnoredPaths
      Git = require 'git'
      repo = Git.open(rootPath, refreshOnWindowFocus: false)

    paths = []
    isIgnored = (path) ->
      for segment in path.split('/')
        return true if _.contains(ignoredNames, segment)
      repo?.isPathIgnored(fs.join(rootPath, path))
    onFile = (path) ->
      path = path.substring(rootPath.length + 1)
      paths.push(path) unless isIgnored(path)
    onDirectory = (path) ->
      path = path.substring(rootPath.length + 1)
      not isIgnored(path)
    fs.traverseTree(rootPath, onFile, onDirectory)

    repo?.destroy()

    callTaskMethod('pathsLoaded', paths)
