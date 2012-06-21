_ = require 'underscore'

module.exports =
class Snippet
  constructor: ({@bodyPosition, @prefix, @description, body}) ->
    @body = @extractTabStops(body)

  extractTabStops: (body) ->
    tabStopsByIndex = {}
    bodyText = []
    for element in body
      if element.index
        tabStopsByIndex[element.index] = element.position.subtract(@bodyPosition)
      else
        bodyText.push(element)

    @tabStops = []
    for index in _.keys(tabStopsByIndex).sort()
      @tabStops.push tabStopsByIndex[index]

    bodyText.join('')
