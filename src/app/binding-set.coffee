$ = require 'jquery'
_ = require 'underscore'
Specificity = require 'specificity'
fs = require 'fs'

PEG = require 'pegjs'

module.exports =
class BindingSet
  selector: null
  commandForEvent: null
  keystrokePatternParser: null

  constructor: (@selector, mapOrFunction) ->
    @parser = PEG.buildParser(fs.read(require.resolve 'keystroke-pattern.pegjs'))
    @specificity = Specificity(@selector)
    @commandForEvent = @buildEventHandler(mapOrFunction)

  buildEventHandler: (mapOrFunction) ->
    if _.isFunction(mapOrFunction)
      mapOrFunction
    else
      mapOrFunction = @normalizeKeystrokePatterns(mapOrFunction)
      (event) =>
        for pattern, command of mapOrFunction
          return command if event.keystroke == pattern
        null

  normalizeKeystrokePatterns: (map) ->
    normalizedMap = {}
    for pattern, event of map
      normalizedMap[@normalizeKeystrokePattern(pattern)] = event
    normalizedMap

  normalizeKeystrokePattern: (pattern) ->
    keys = @parser.parse(pattern)
    modifiers = keys[0...-1]
    modifiers.sort()
    [modifiers..., _.last(keys)].join('-')

