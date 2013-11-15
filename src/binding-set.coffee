{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
fs = require 'fs-plus'
{specificity} = require 'clear-cut'
PEG = require 'pegjs'

nextBindingSetIndex = 0

### Internal ###

module.exports =
class BindingSet
  @parser: null

  selector: null
  commandsByKeystroke: null
  parser: null
  name: null

  constructor: (selector, commandsByKeystroke, @name) ->
    @index = nextBindingSetIndex++
    keystrokePattern = fs.readFileSync(require.resolve('./keystroke-pattern.pegjs'), 'utf8')
    BindingSet.parser ?= PEG.buildParser(keystrokePattern)
    @specificity = specificity(selector)
    @selector = selector.replace(/!important/g, '')
    @commandsByKeystroke = @normalizeCommandsByKeystroke(commandsByKeystroke)

  # Private:
  getName: ->
    @name

  # Private:
  getSelector: ->
    @selector

  # Private:
  getCommandsByKeystroke: ->
    @commandsByKeystroke

  normalizeCommandsByKeystroke: (commandsByKeystroke) ->
    normalizedCommandsByKeystroke = {}
    for keystroke, command of commandsByKeystroke
      normalizedCommandsByKeystroke[@normalizeKeystroke(keystroke)] = command
    normalizedCommandsByKeystroke

  normalizeKeystroke: (keystroke) ->
    normalizedKeystroke = keystroke.split(/\s+/).map (keystroke) =>
      keys = BindingSet.parser.parse(keystroke)
      modifiers = keys[0...-1]
      modifiers.sort()
      [modifiers..., _.last(keys)].join('-')
    normalizedKeystroke.join(' ')
