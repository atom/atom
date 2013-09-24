{PathSearcher, PathScanner, search} = require 'scandal'

module.exports = (rootPath, regexSource, options) ->
  callback = @async()

  searcher = new PathSearcher()
  scanner = new PathScanner(rootPath, rootPath)

  searcher.on 'results-found', (result) ->
    emit('scan:result-found', result)

  flags = "g"
  flags += "i" if options.ignoreCase
  regex = new RegExp(regexSource, flags)
  search regex, scanner, searcher, callback
