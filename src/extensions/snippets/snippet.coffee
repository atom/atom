_ = require 'underscore'
Point = require 'point'

module.exports =
class Snippet
  constructor: ({@bodyPosition, @prefix, @description, body}) ->
    @body = @extractTabStops(body)

  extractTabStops: (bodyLines) ->
    tabStopsByIndex = {}
    bodyText = []

    [row, column] = [0, 0]
    for bodyLine in bodyLines
      for segment in bodyLine
        if _.isNumber(segment)
          tabStopsByIndex[segment] = new Point(row, column)
        else
          bodyText.push(segment)
          column += segment.length
      bodyText.push('\n')
      row++; column = 0

    @tabStops = []
    for index in _.keys(tabStopsByIndex).sort()
      @tabStops.push tabStopsByIndex[index]

    bodyText.join('')
