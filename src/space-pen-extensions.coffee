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
    show: 1000
    hide: 100
  container: 'body'
  html: true
  placement: 'auto top'
  viewportPadding: 2

humanizeKeystrokes = (keystroke) ->
  keystrokes = keystroke.split(' ')
  keystrokes = (_.humanizeKeystroke(stroke) for stroke in keystrokes)
  keystrokes.join(' ')

getKeystroke = (bindings) ->
  if bindings?.length
    "<span class=\"keystroke\">#{humanizeKeystrokes(bindings[0].keystroke)}</span>"
  else
    ''
# options from http://getbootstrap.com/javascript/#tooltips
jQuery.fn.setTooltip = (tooltipOptions, {command, commandElement}={}) ->
  atom.requireWithGlobals('bootstrap/js/tooltip', {jQuery})

  tooltipOptions = {title: tooltipOptions} if _.isString(tooltipOptions)

  bindings = if commandElement
    atom.keymap.keyBindingsForCommandMatchingElement(command, commandElement)
  else
    atom.keymap.keyBindingsForCommand(command)

  tooltipOptions.title = "#{tooltipOptions.title} #{getKeystroke(bindings)}"

  @tooltip(jQuery.extend({}, tooltipDefaults, tooltipOptions))

jQuery.fn.hideTooltip = ->
  tip = @data('bs.tooltip')
  if tip
    tip.leave(currentTarget: this)
    tip.hide()

jQuery.fn.destroyTooltip = ->
  @hideTooltip()
  @tooltip('destroy')

jQuery.fn.setTooltip.getKeystroke = getKeystroke
jQuery.fn.setTooltip.humanizeKeystrokes = humanizeKeystrokes

module.exports = spacePen
