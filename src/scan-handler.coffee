{PathSearcher, PathScanner, search} = require 'scandal'

module.exports = (rootPath, regexSource, options) ->
  callback = @async()

  PATHS_COUNTER_SEARCHED_CHUNK = 50
  pathsSearched = 0

  searcher = new PathSearcher()
  scanner = new PathScanner(rootPath, options)

  searcher.on 'file-error', ({code, path, message}) ->
    emit('scan:file-error', {code, path, message})

  searcher.on 'results-found', (result) ->
    emit('scan:result-found', result)

  scanner.on 'path-found', ->
    pathsSearched++
    if pathsSearched % PATHS_COUNTER_SEARCHED_CHUNK == 0
      emit('scan:paths-searched', pathsSearched)

  flags = "g"
  flags += "i" if options.ignoreCase
  regex = new RegExp(regexSource, flags)
  search regex, scanner, searcher, ->
    emit('scan:paths-searched', pathsSearched)
    callback()
