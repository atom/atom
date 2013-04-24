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
    args.unshift('--hidden')

    paths = []
    exit = (code) =>
      if code is 0
        @callback(paths)
      else
        console.error "Path loading process exited with status #{code}"
        @callback([])
    stdout = (data) ->
      paths.push(_.compact(data.split('\n'))...)
    stderr = (data) ->
      console.error "Error in LoadPathsTask:\n#{data}"

    @process = new BufferedProcess({command, args, stdout, stderr, exit})

  abort: ->
    if @process?
      @process.kill()
      @process = null
