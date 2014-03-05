_ = require 'underscore-plus'
fs = require 'fs-plus'
{specificity} = require 'clear-cut'

module.exports =
class KeyBinding
  @parser: null
  @currentIndex: 1
  @specificities: null

  @calculateSpecificity: (selector) ->
    @specificities ?= {}
    value = @specificities[selector]
    unless value?
      value = specificity(selector)
      @specificities[selector] = value
    value

  @normalizeKeystroke: (keystroke) ->
    normalizedKeystroke = keystroke.split(/\s+/).map (keystroke) =>
      keys = @parseKeystroke(keystroke)
      modifiers = keys[0...-1]
      modifiers.sort()
      key = _.last(keys)

      # Add the shift modifier if the key is an uppercased alpha char
      if /^[A-Z]$/.test(key) or 'shift' in modifiers
        modifiers.push 'shift' unless 'shift' in modifiers
        key = key.toUpperCase()
      [modifiers..., key].join('-')

    normalizedKeystroke.join(' ')

  @parseKeystroke: (keystroke) ->
    unless @parser?
      try
        @parser = require './keystroke-pattern'
      catch
        keystrokePattern = fs.readFileSync(require.resolve('./keystroke-pattern.pegjs'), 'utf8')
        PEG = require 'pegjs'
        @parser = PEG.buildParser(keystrokePattern)

    @parser.parse(keystroke)

  constructor: (source, command, keystroke, selector) ->
    @source = source
    @command = command
    @keystroke = KeyBinding.normalizeKeystroke(keystroke)
    @selector = selector.replace(/!important/g, '')
    @specificity = KeyBinding.calculateSpecificity(selector)
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
