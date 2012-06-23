_ = require 'underscore'
Point = require 'point'

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
        if _.isNumber(segment)
          tabStopsByIndex[segment] = new Point(row, column)
        else
          lineText.push(segment)
          column += segment.length
      bodyText.push(lineText.join(''))
      row++; column = 0
    @lineCount = row + 1

    @tabStops = []
    for index in _.keys(tabStopsByIndex).sort()
      @tabStops.push tabStopsByIndex[index]

    bodyText.join('\n')
