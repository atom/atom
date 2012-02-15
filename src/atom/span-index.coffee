_ = require 'underscore'

module.exports =
class SpanIndex
  constructor: ->
    @entries = []

  insert: (index, spans, values) ->
    @entries[index..index] = @buildIndexEntries(spans, values)

  replace: (index, span, value) ->
    @splice(index, index, span, [value])

  splice: (start, end, spans, values) ->
    @entries[start..end] = @buildIndexEntries(spans, values)

  updateSpans: (start, end, span) ->
    for i in [start..end]
      @entries[i].span = span

  at: (index) ->
    @entries[index].value

  last: ->
    _.last(@entries).value

  clear: ->
    @entries = []

  lengthBySpan: ->
    length = 0
    for entry in @entries
      length += entry.span
    length

  sliceBySpan: (start, end) ->
    currentSpan = 0
    values = []

    for entry in @entries
      continue if entry.span is 0
      nextSpan = currentSpan + entry.span
      if nextSpan > start
        startOffset = start - currentSpan if currentSpan <= start
        if currentSpan <= end
          values.push entry.value
          endOffset = end - currentSpan if nextSpan >= end
        else
          break
      currentSpan = nextSpan

    { values, startOffset, endOffset }


  indexForSpan: (targetSpan) ->
    currentSpan = 0
    index = 0
    offset = 0
    for entry in @entries
      nextSpan = currentSpan + entry.span
      if nextSpan > targetSpan
        offset = targetSpan - currentSpan
        return { index, offset}
      currentSpan = nextSpan
      index++

  spanForIndex: (index) ->
    span = 0
    for i in [0...index]
      span += @entries[i].span
    span

  buildIndexEntries: (spans, values) ->
    if _.isArray(spans)
      _.zip(spans, values).map ([span, value]) -> new SpanIndexEntry(span, value)
    else
      values.map (value) -> new SpanIndexEntry(spans, value)

class SpanIndexEntry
  constructor: (@span, @value) ->

