_ = require 'underscore-plus'
SpacePen = require 'space-pen'
{Subscriber} = require 'emissary'

Subscriber.includeInto(SpacePen.View)

jQuery = SpacePen.jQuery
JQueryCleanData = jQuery.cleanData
jQuery.cleanData = (elements) ->
  jQuery(element).view()?.unsubscribe() for element in elements
  JQueryCleanData(elements)

SpacePenCallRemoveHooks = SpacePen.callRemoveHooks
SpacePen.callRemoveHooks = (element) ->
  view.unsubscribe() for view in SpacePen.viewsForElement(element)
  SpacePenCallRemoveHooks(element)

JQueryTrigger = jQuery.fn.trigger
jQuery.fn.trigger = (event, data) ->
  if typeof event is 'object'
    {type, target, originalEvent} = event
    if originalEvent?
      originalEvent.type ?= type
      event = originalEvent
  else
    type = event

  specialTrigger = jQuery.event.special[event]?.trigger

  # Don't deal with namespaces
  return JQueryTrigger.apply(this, arguments) unless type.indexOf('.') is -1

  if target?
    atom.commands.dispatch(target, event, data)
  else
    for element in this
      continue if specialTrigger?.apply(element) is false
      atom.commands.dispatch(element, event, data)
  this

# Allow command registry integration with focusin and focusout events
# Otherwise jQuery registers these event handlers in a special way for bubbling
# compatibility
delete jQuery.event.special.focusin
delete jQuery.event.special.focusout

HandlersByOriginalHandler = new WeakMap
CommandDisposablesByElement = new WeakMap

AddEventListener = (element, type, listener) ->
  disposable = atom.commands.add(element, type, listener)

  unless disposablesByType = CommandDisposablesByElement.get(element)
    disposablesByType = {}
    CommandDisposablesByElement.set(element, disposablesByType)

  unless disposablesByListener = disposablesByType[type]
    disposablesByListener = new WeakMap
    disposablesByType[type] = disposablesByListener

  disposablesByListener.set(listener, disposable)

RemoveEventListener = (element, type, listener) ->
  CommandDisposablesByElement.get(element)?[type]?.get(listener)?.dispose()

JQueryEventAdd = jQuery.event.add
jQuery.event.add = (elem, types, originalHandler, data, selector) ->
  handler = (event) ->
    if arguments.length is 1 and event.originalEvent?.detail?
      {detail} = event.originalEvent
      if Array.isArray(detail)
        originalHandler.apply(this, [event].concat(detail))
      else
        originalHandler.call(this, event, detail)
    else
      originalHandler.apply(this, arguments)

  HandlersByOriginalHandler.set(originalHandler, handler)

  JQueryEventAdd.call(this, elem, types, handler, data, selector, AddEventListener if atom?.commands?)

JQueryEventRemove = jQuery.event.remove
jQuery.event.remove = (elem, types, originalHandler, selector, mappedTypes) ->
  if originalHandler?
    handler = HandlersByOriginalHandler.get(originalHandler) ? originalHandler
  JQueryEventRemove(elem, types, handler, selector, mappedTypes, RemoveEventListener if atom?.commands?)

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
    "<span class=\"keystroke\">#{humanizeKeystrokes(bindings[0].keystrokes)}</span>"
  else
    ''

requireBootstrapTooltip = _.once ->
  atom.requireWithGlobals('bootstrap/js/tooltip', {jQuery})

# options from http://getbootstrap.com/javascript/#tooltips
jQuery.fn.setTooltip = (tooltipOptions, {command, commandElement}={}) ->
  requireBootstrapTooltip()

  tooltipOptions = {title: tooltipOptions} if _.isString(tooltipOptions)

  if commandElement
    bindings = atom.keymaps.findKeyBindings(command: command, target: commandElement[0])
  else if command
    bindings = atom.keymaps.findKeyBindings(command: command)

  tooltipOptions.title = "#{tooltipOptions.title} #{getKeystroke(bindings)}"

  @tooltip(jQuery.extend({}, tooltipDefaults, tooltipOptions))

jQuery.fn.hideTooltip = ->
  tip = @data('bs.tooltip')
  if tip
    tip.leave(currentTarget: this)
    tip.hide()

jQuery.fn.destroyTooltip = ->
  @hideTooltip()
  requireBootstrapTooltip()
  @tooltip('destroy')

# Hide tooltips when window is resized
jQuery(document.body).on 'show.bs.tooltip', ({target}) ->
  windowHandler = -> jQuery(target).hideTooltip()
  jQuery(window).one('resize', windowHandler)
  jQuery(target).one 'hide.bs.tooltip', ->
    jQuery(window).off('resize', windowHandler)

jQuery.fn.setTooltip.getKeystroke = getKeystroke
jQuery.fn.setTooltip.humanizeKeystrokes = humanizeKeystrokes

Object.defineProperty jQuery.fn, 'element', get: -> @[0]

module.exports = SpacePen
