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
    for bodyLine, i in bodyTree
      lineText = []
      for segment in bodyLine
        if segment.index
          { index, placeholderText } = segment
          tabStopsByIndex[index] = new Range([row, column], [row, column + placeholderText.length])
          lineText.push(placeholderText)
        else
          lineText.push(segment)
          column += segment.length
      bodyText.push(lineText.join(''))
      row++; column = 0
    @lineCount = row

    @tabStops = []
    for index in _.keys(tabStopsByIndex).sort()
      @tabStops.push tabStopsByIndex[index]

    bodyText.join('\n')
