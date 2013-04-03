_ = require 'underscore'
fsUtils = require 'fs-utils'

module.exports =
class LoadPathsTask
  aborted: false

  constructor: (@callback) ->

  start: ->
    rootPath = project.getPath()
    ignoredNames = config.get('fuzzyFinder.ignoredNames') ? []
    ignoredNames = ignoredNames.concat(config.get('core.ignoredNames') ? [])
    ignoreGitIgnoredFiles =  config.get('core.hideGitIgnoredFiles')

    paths = []
    isIgnored = (path) ->
      path = path.substring(rootPath.length + 1)
      for segment in path.split('/')
        return true if _.contains(ignoredNames, segment)
      ignoreGitIgnoredFiles and git?.isPathIgnored(fsUtils.join(rootPath, path))
    onFile = (path) ->
      return if @aborted
      paths.push(path) unless isIgnored(path)
    onDirectory = (path) =>
      not @aborted and not isIgnored(path)
    onDone = =>
      @callback(paths) unless @aborted

    fsUtils.traverseTree(rootPath, onFile, onDirectory, onDone)

  abort: ->
    @aborted = true
