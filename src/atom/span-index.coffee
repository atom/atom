_ = require 'underscore'

module.exports =
class SpanIndex
  constructor: ->
    @entries = []

  insert: (index, spans, values) ->
    @entries[index..index] = @buildIndexEntries(spans, values)

  splice: (start, end, spans, values) ->
    @entries[start..end] = @buildIndexEntries(spans, values)

  clear: ->
    @entries = []

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

  buildIndexEntries: (spans, values) ->
    _.zip(spans, values).map ([span, value]) -> new SpanIndexEntry(span, value)

class SpanIndexEntry
  constructor: (@span, @value) ->

