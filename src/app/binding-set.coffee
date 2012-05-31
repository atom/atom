$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'

Specificity = require 'specificity'
PEG = require 'pegjs'

module.exports =
class BindingSet
  selector: null
  keystrokeMap: null
  commandForEvent: null
  parser: null

  constructor: (@selector, mapOrFunction) ->
    @parser = PEG.buildParser(fs.read(require.resolve 'keystroke-pattern.pegjs'))
    @specificity = Specificity(@selector)
    @keystrokeMap = {}

    if _.isFunction(mapOrFunction)
      @commandForEvent = mapOrFunction
    else
      @keystrokeMap = @normalizeKeystrokeMap(mapOrFunction)
      @commandForEvent = (event) =>
        for keystroke, command of @keystrokeMap
          return command if event.keystroke == keystroke
        null

  normalizeKeystrokeMap: (keystrokeMap) ->
    normalizeKeystrokeMap = {}
    for keystroke, command of keystrokeMap
      normalizeKeystrokeMap[@normalizeKeystroke(keystroke)] = command

    normalizeKeystrokeMap

  normalizeKeystroke: (keystroke) ->
    keys = @parser.parse(keystroke)
    modifiers = keys[0...-1]
    modifiers.sort()
    [modifiers..., _.last(keys)].join('-')
