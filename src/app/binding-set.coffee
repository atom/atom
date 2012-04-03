$ = require 'jquery'
_ = require 'underscore'
Specificity = require 'specificity'

module.exports =
class BindingSet
  selector: null
  commandForEvent: null

  constructor: (@selector, mapOrFunction) ->
    @specificity = Specificity(@selector)
    @commandForEvent = @buildEventHandler(mapOrFunction)

  buildEventHandler: (mapOrFunction) ->
    if _.isFunction(mapOrFunction)
      mapOrFunction
    else
      mapOrFunction = @normalizeKeystrokePatterns(mapOrFunction)
      (event) =>
        for pattern, command of mapOrFunction
          return command if @eventMatchesPattern(event, pattern)
        null

  eventMatchesPattern: (event, pattern) ->
    pattern = pattern.replace(/^<|>$/g, '')
    event.keystroke == pattern

  normalizeKeystrokePatterns: (map) ->
    normalizedMap = {}
    for pattern, event of map
      normalizedMap[@normalizeKeystrokePattern(pattern)] = event
    normalizedMap

  normalizeKeystrokePattern: (pattern) ->
    keys = pattern.split('-')
    modifiers = keys[0...-1]
    modifiers.sort()
    [modifiers..., _.last(keys)].join('-')

