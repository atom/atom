_ = require 'underscore'
{Range} = require 'telepath'

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

    # recursive helper function; mutates vars above
    extractTabStops = (bodyTree) ->
      for segment in bodyTree
        if segment.index?
          { index, content } = segment
          index = Infinity if index == 0
          start = [row, column]
          extractTabStops(content)
          tabStopsByIndex[index] = new Range(start, [row, column])
        else if _.isString(segment)
          bodyText.push(segment)
          segmentLines = segment.split('\n')
          column += segmentLines.shift().length
          while (nextLine = segmentLines.shift())?
            row += 1
            column = nextLine.length

    extractTabStops(bodyTree)
    @lineCount = row + 1
    @tabStops = []
    for index in _.keys(tabStopsByIndex).sort()
      @tabStops.push tabStopsByIndex[index]

    bodyText.join('')
