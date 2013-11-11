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
  commandsByKeystroke: null
  parser: null
  name: null

  constructor: (selector, commandsByKeystroke, @index, @name) ->
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

  commandForKeystroke: (keystrokeToMatch) ->
    keyStrokeRegex = new RegExp("^" + _.escapeRegExp(keystrokeToMatch) + "( |$)")
    for keystroke, command of @commandsByKeystroke
      if keyStrokeRegex.test(keystroke)
        partialMatch = keystrokeToMatch isnt keystroke
        return {command, partialMatch}
    null

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
