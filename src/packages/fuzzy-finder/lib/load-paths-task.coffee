_ = require 'underscore'
BufferedProcess = require 'buffered-process'

module.exports =
class LoadPathsTask
  constructor: (@callback) ->

  start: ->
    rootPath = project.getPath()
    ignoredNames = config.get('fuzzyFinder.ignoredNames') ? []
    ignoredNames = ignoredNames.concat(config.get('core.ignoredNames') ? [])

    command = require.resolve 'nak'
    args = ['--list', rootPath]
    args.unshift('--addVCSIgnores') if config.get('core.excludeVcsIgnoredPaths')
    args.unshift('--ignore', ignoredNames.join(',')) if ignoredNames.length > 0
    args.unshift('--follow')

    paths = []
    exit = (code) =>
      if code is 0
        @callback(paths)
      else
        @callback([])
    stdout = (data) ->
      paths.push(_.compact(data.split('\n'))...)

    @process = new BufferedProcess({command, args, stdout, exit})

  abort: ->
    if @process?
      @process.kill()
      @process = null
