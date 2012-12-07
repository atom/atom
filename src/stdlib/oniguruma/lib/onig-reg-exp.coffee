{ OnigScanner } = require "../build/Release/onig_scanner"

module.exports =
class OnigRegExp
  constructor: (@source) ->
    @scanner = new OnigScanner([@source])

  search: (string, startPosition=0) ->
    return null unless result = @scanner.findNextMatch(string, startPosition)
    { captureIndices } = result
    captures = []
    captures.index = captureIndices[1]
    captures.indices = []
    while captureIndices.length
      index = captureIndices.shift()
      start = captureIndices.shift()
      end = captureIndices.shift()
      captures.push(string[start...end])
      captures.indices.push(start)
    captures

  test: (string) ->
    @search(string)?