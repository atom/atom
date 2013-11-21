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

getKeystroke = (bindings) ->
  if bindings and bindings.length
    "<span class=\"keystroke\">#{bindings[0].keystroke}</span>"
  else
    ''

jQuery.fn.setTooltip = (title, {command, commandElement}={}) ->
  atom.requireWithGlobals('bootstrap/js/tooltip', {jQuery : jQuery})

  bindings = if commandElement
    atom.keymap.keyBindingsForCommandMatchingElement(command, commandElement)
  else
    atom.keymap.keyBindingsForCommand(command)

  this.tooltip(jQuery.extend(tooltipDefaults, {title: "#{title} #{getKeystroke(bindings)}"}))

module.exports = spacePen
