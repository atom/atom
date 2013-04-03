_ = require 'underscore'
BufferedProcess = require 'buffered-process'

module.exports =
class LoadPathsTask
  constructor: (@callback) ->

  start: ->
    rootPath = project.getPath()
    ignoredNames = config.get('fuzzyFinder.ignoredNames') ? []
    ignoredNames = ignoredNames.concat(config.get('core.ignoredNames') ? [])
    ignoreGitIgnoredFiles =  config.get('core.hideGitIgnoredFiles')

    command = require.resolve 'nak'
    args = ['--list', rootPath]
    args.unshift('--addVCSIgnores') if config.get('nak.addVCSIgnores')
    args.unshift('--ignore', ignoredNames.join(',')) if ignoredNames.length > 0
    args.unshift('--follow')

    paths = []
    exit = =>
      @callback(paths)
    stdout = (data) ->
      paths.push(_.compact(data.split('\n'))...)

    @process = new BufferedProcess({command, args, stdout, exit})

  abort: ->
    if @process?
      @process.kill()
      @process = null
