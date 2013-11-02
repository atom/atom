{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
fs = require 'fs-plus'
{specificity} = require 'clear-cut'
PEG = require 'pegjs'

### Internal ###

module.exports =
class BindingSet

  @parser: null

  selector: null
  commandsByKeystrokes: null
  parser: null
  name: null

  constructor: (selector, commandsByKeystrokes, @index, @name) ->
    keystrokePattern = fs.readFileSync(require.resolve('./keystroke-pattern.pegjs'), 'utf8')
    BindingSet.parser ?= PEG.buildParser(keystrokePattern)
    @specificity = specificity(selector)
    @selector = selector.replace(/!important/g, '')
    @commandsByKeystrokes = @normalizeCommandsByKeystrokes(commandsByKeystrokes)

  # Private:
  getName: ->
    @name

  # Private:
  getSelector: ->
    @selector

  # Private:
  getCommandsByKeystrokes: ->
    @commandsByKeystrokes

  commandForEvent: (event) ->
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
    keys = BindingSet.parser.parse(keystroke)
    modifiers = keys[0...-1]
    modifiers.sort()
    [modifiers..., _.last(keys)].join('-')
