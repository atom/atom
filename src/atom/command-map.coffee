_ = require 'underscore'
KeyBinder = require 'key-binder'

module.exports =
class CommandMap
  delegate: null
  mappings: null
  bufferedEvents: null
  namedKeys:
    backspace: 8, tab: 9, clear: 12,
    enter: 13, 'return': 13,
    esc: 27, escape: 27, space: 32,
    left: 37, up: 38,
    right: 39, down: 40,
    del: 46, 'delete': 46,
    home: 36, end: 35,
    pageup: 33, pagedown: 34,
    ',': 188, '.': 190, '/': 191,
    '`': 192, '-': 189, '=': 187,
    ';': 186, '\'': 222,
    '[': 219, ']': 221, '\\': 220

  inputTimeout: 200

  constructor: (@delegate) ->
    @mappings = {}
    @bufferedEvents = []

  mapKey: (pattern, action) ->
    @mappings[pattern] = action

  handleKeyEvent: (event) ->
    window.clearTimeout(@inputTimeoutHandle) if @inputTimeoutHandle
    @bufferedEvents.push(event)

    candidatePatterns =
      (pattern for pattern of @mappings when @keyEventsMatchPatternPrefix(@bufferedEvents, pattern))

    if candidatePatterns.length > 1
      @inputTimeoutHandle = _.delay (=> @triggerActionForBufferedKeyEvents()), @inputTimeout
    else if candidatePatterns.length == 1
      @triggerActionForBufferedKeyEvents()
    else
      @clearBufferedEvents()

  triggerActionForBufferedKeyEvents: ->
    for pattern, action of @mappings
      if @keyEventsMatchPattern(@bufferedEvents, pattern)
        @delegate[action](event)
        @clearBufferedEvents()

  keyEventsMatchPattern: (events, pattern) ->
    patternKeys = @parseKeyPattern(pattern)
    return false unless events.length == patternKeys.length
    _.all(_.zip(events, patternKeys), ([event, pattern]) -> 
      event.which == pattern.which)

  keyEventsMatchPatternPrefix: (events, pattern) ->
    patternKeys = @parseKeyPattern(pattern)
    return false if events.length > patternKeys.length
    _.all(_.zip(events, patternKeys[0...events.length]), ([event, pattern]) -> 
      event.which == pattern.which)

  parseKeyPattern: (pattern) ->
    for char in pattern
      { which: char.toUpperCase().charCodeAt(0) }

  clearBufferedEvents: ->
    @bufferedEvents = []

