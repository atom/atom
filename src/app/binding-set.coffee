$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'

Specificity = require 'specificity'
PEG = require 'pegjs'

module.exports =
class BindingSet
  selector: null
  commandsByKeystrokes: null
  commandForEvent: null
  parser: null

  constructor: (@selector, mapOrFunction) ->
    @parser = PEG.buildParser(fs.read(require.resolve 'keystroke-pattern.pegjs'))
    @specificity = Specificity(@selector)
    @commandsByKeystrokes = {}

    if _.isFunction(mapOrFunction)
      @commandForEvent = mapOrFunction
    else
      @commandsByKeystrokes = @normalizeCommandsByKeystrokes(mapOrFunction)
      @commandForEvent = (event) =>
        for keystrokes, command of @commandsByKeystrokes
          return command if event.keystrokes == keystrokes
        null

  matchesKeystrokePrefix: (event) ->
    eventKeystrokes = event.keystrokes.split(' ')
    for keystrokes, command of @commandsByKeystrokes
      bindingKeystrokes = keystrokes.split(' ')
      continue unless eventKeystrokes.length < bindingKeystrokes.length
      return true if _.isEqual(eventKeystrokes, bindingKeystrokes[0...eventKeystrokes.length])
    false

  normalizeCommandsByKeystrokes: (commandsByKeystrokes) ->
    normalizedCommandsByKeystrokes = {}
    for keystrokes, command of commandsByKeystrokes
      normalizedCommandsByKeystrokes[@normalizeKeystrokes(keystrokes)] = command
    normalizedCommandsByKeystrokes

  normalizeKeystrokes: (keystrokes) ->
    normalizedKeystrokes = keystrokes.split(/\s+/).map (keystroke) =>
      @normalizeKeystroke(keystroke)
    normalizedKeystrokes.join(' ')

  normalizeKeystroke: (keystroke) ->
    keys = @parser.parse(keystroke)
    modifiers = keys[0...-1]
    modifiers.sort()
    [modifiers..., _.last(keys)].join('-')
