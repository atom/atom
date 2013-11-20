{$} = require './space-pen-extensions'
_ = require 'underscore-plus'
fs = require 'fs-plus'
{specificity} = require 'clear-cut'
PEG = require 'pegjs'

### Internal ###

module.exports =
class KeyBinding
  @parser: null
  @currentIndex: 1

  @normalizeKeystroke: (keystroke) ->
    normalizedKeystroke = keystroke.split(/\s+/).map (keystroke) =>
      keys = @getParser().parse(keystroke)
      modifiers = keys[0...-1]
      modifiers.sort()
      [modifiers..., _.last(keys)].join('-')
    normalizedKeystroke.join(' ')

  @getParser: ->
    if not KeyBinding.parser
      keystrokePattern = fs.readFileSync(require.resolve('./keystroke-pattern.pegjs'), 'utf8')
      KeyBinding.parser = PEG.buildParser(keystrokePattern)

    KeyBinding.parser

  constructor: (source, command, keystroke, selector) ->
    @source = source
    @command = command
    @keystroke = KeyBinding.normalizeKeystroke(keystroke)
    @selector = selector.replace(/!important/g, '')
    @specificity = specificity(selector)
    @index = KeyBinding.currentIndex++

  matches: (keystroke) ->
    multiKeystroke = /\s/.test keystroke
    if multiKeystroke
      keystroke == @keystroke
    else
      keystroke.split(' ')[0] == @keystroke.split(' ')[0]

  compare: (keyBinding) ->
    if keyBinding.specificity == @specificity
      keyBinding.index - @index
    else
      keyBinding.specificity - @specificity
