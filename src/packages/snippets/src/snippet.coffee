_ = require 'underscore'
Range = require 'range'

module.exports =
class Snippet
  name: null
  prefix: null
  body: null
  lineCount: null
  tabStops: null

  constructor: ({@name, @prefix, bodyTree}) ->
    @body = @extractTabStops(bodyTree)

  extractTabStops: (bodyTree) ->
    tabStopsByIndex = {}
    bodyText = []

    [row, column] = [0, 0]
    for segment in bodyTree
      if segment.index
        { index, placeholderText } = segment
        tabStopsByIndex[index] = new Range([row, column], [row, column + placeholderText.length])
        bodyText.push(placeholderText)
        column += placeholderText.length
      else
        bodyText.push(segment)
        segmentLines = segment.split('\n')
        column += segmentLines.shift().length
        while nextLine = segmentLines.shift()
          row += 1
          column = nextLine.length

    @lineCount = row + 1
    @tabStops = []
    for index in _.keys(tabStopsByIndex).sort()
      @tabStops.push tabStopsByIndex[index]

    bodyText.join('')
