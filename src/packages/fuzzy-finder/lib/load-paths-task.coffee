_ = require 'underscore'
BufferedProcess = require 'buffered-process'
$ = require 'jquery'

module.exports =
class LoadPathsTask
  aborted: false

  constructor: (@callback) ->

  start: ->
    rootPath = project.getPath()
    ignoredNames = config.get('fuzzyFinder.ignoredNames') ? []
    ignoredNames = ignoredNames.concat(config.get('core.ignoredNames') ? [])
    ignoreGitIgnoredFiles =  config.get('core.hideGitIgnoredFiles')

    command = require.resolve 'nak'
    args = ['-l', rootPath]
    args.unshift("--addVCSIgnores") if config.get('nak.addVCSIgnores')
    args.unshift("-d", "#{ignoredNames.join(',')}") if ignoredNames.length > 0

    paths = []
    deferred = $.Deferred()
    exit = (code) =>
      if code is -1
        deferred.reject({command, code})
      else
        @callback(paths)
        deferred.resolve()
    stdout = (data) ->
      paths = paths.concat(data.split("\n"))

    new BufferedProcess({command, args, stdout, exit})
    deferred

  abort: ->
    @aborted = true