_ = require 'underscore-plus'
spacePen = require 'space-pen'
ConfigObserver = require './config-observer'
{Subscriber} = require 'emissary'

_.extend spacePen.View.prototype, ConfigObserver
Subscriber.includeInto(spacePen.View)

jQuery = spacePen.jQuery
originalCleanData = jQuery.cleanData
jQuery.cleanData = (elements) ->
  for element in elements
    if view = jQuery(element).view()
      view.unobserveConfig()
      view.unsubscribe()
  originalCleanData(elements)

tooltipDefaults =
  delay:
    show: 500
    hide: 100
  container: 'body'
  html: true

modifiers =
  cmd: '⌘'
  option: '⌥'
  ctrl: '⌃'
  shift: '⇧'
  left: '←'
  right: '→'
  up: '↑'
  down: '↓'

replaceKey = (key) ->
  if modifiers[key]
    modifiers[key]
  else if key.length == 1 and key == key.toUpperCase() and key.toUpperCase() != key.toLowerCase()
    [modifiers.shift, key.toUpperCase()]
  else if key.length == 1
    key.toUpperCase()
  else
    key

replaceModifiersInSingleKeystroke = (keystroke) ->
  keys = keystroke.split('-')
  keys = _.flatten(replaceKey(key) for key in keys)
  keys.join('')

replaceModifiers = (keystroke) ->
  keystrokes = keystroke.split(' ')
  keystrokes = (replaceModifiersInSingleKeystroke(stroke) for stroke in keystrokes)
  keystrokes.join(' ')

getKeystroke = (bindings) ->
  if bindings?.length
    "<span class=\"keystroke\">#{replaceModifiers(bindings[0].keystroke)}</span>"
  else
    ''

jQuery.fn.setTooltip = (title, {command, commandElement}={}) ->
  atom.requireWithGlobals('bootstrap/js/tooltip', {jQuery})

  bindings = if commandElement
    atom.keymap.keyBindingsForCommandMatchingElement(command, commandElement)
  else
    atom.keymap.keyBindingsForCommand(command)

  this.tooltip(jQuery.extend(tooltipDefaults, {title: "#{title} #{getKeystroke(bindings)}"}))

jQuery.fn.setTooltip.getKeystroke = getKeystroke
jQuery.fn.setTooltip.replaceModifiers = replaceModifiers

module.exports = spacePen
