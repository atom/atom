_ = require 'underscore'
Range = require 'range'

module.exports =
class Snippet
  body: null
  lineCount: null
  tabStops: null

  constructor: ({@bodyPosition, @prefix, @description, body}) ->
    @body = @extractTabStops(body)

  extractTabStops: (bodyLines) ->
    tabStopsByIndex = {}
    bodyText = []

    [row, column] = [0, 0]
    for bodyLine, i in bodyLines
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
