path = require "path"
async = require "async"
{PathSearcher, PathScanner, search} = require 'scandal'

module.exports = (rootPaths, regexSource, options, searchOptions={}) ->
  callback = @async()

  PATHS_COUNTER_SEARCHED_CHUNK = 50
  pathsSearched = 0

  searcher = new PathSearcher(searchOptions)

  searcher.on 'file-error', ({code, path, message}) ->
    emit('scan:file-error', {code, path, message})

  searcher.on 'results-found', (result) ->
    emit('scan:result-found', result)

  flags = "g"
  flags += "i" if options.ignoreCase
  regex = new RegExp(regexSource, flags)

  async.each(
    rootPaths,
    (rootPath, next) ->
      options2 = Object.assign {}, options,
        inclusions: processPaths(rootPath, options.inclusions)
        globalExclusions: processPaths(rootPath, options.globalExclusions)

      scanner = new PathScanner(rootPath, options2)

      scanner.on 'path-found', ->
        pathsSearched++
        if pathsSearched % PATHS_COUNTER_SEARCHED_CHUNK is 0
          emit('scan:paths-searched', pathsSearched)

      search regex, scanner, searcher, ->
        emit('scan:paths-searched', pathsSearched)
        next()
    callback
  )

processPaths = (rootPath, paths) ->
  return paths unless paths?.length > 0
  rootPathBase = path.basename(rootPath)
  results = []
  for givenPath in paths
    segments = givenPath.split(path.sep)
    firstSegment = segments.shift()
    results.push(givenPath)
    if firstSegment is rootPathBase
      if segments.length is 0
        results.push(path.join("**", "*"))
      else
        results.push(path.join(segments...))
  results
