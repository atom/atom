_ = require 'underscore'
fs = require 'fs-utils'

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
      for segment in path.split('/')
        return true if _.contains(ignoredNames, segment)
      ignoreGitIgnoredFiles and git?.isPathIgnored(fs.join(rootPath, path))
    onFile = (path) ->
      return if @aborted
      path = path.substring(rootPath.length + 1)
      paths.push(path) unless isIgnored(path)
    onDirectory = (path) =>
      not @aborted and not isIgnored(path.substring(rootPath.length + 1))
    onDone = =>
      @callback(paths) unless @aborted

    fs.traverseTreeAsync(rootPath, onFile, onDirectory, onDone)

  abort: ->
    @aborted = true
