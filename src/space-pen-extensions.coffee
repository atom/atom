_ = require 'underscore-plus'
SpacePen = require 'space-pen'
{Subscriber} = require 'emissary'

Subscriber.includeInto(SpacePen.View)

jQuery = SpacePen.jQuery
JQueryCleanData = jQuery.cleanData
jQuery.cleanData = (elements) ->
  jQuery(element).view()?.unsubscribe?() for element in elements
  JQueryCleanData(elements)

SpacePenCallRemoveHooks = SpacePen.callRemoveHooks
SpacePen.callRemoveHooks = (element) ->
  view.unsubscribe?() for view in SpacePen.viewsForElement(element)
  SpacePenCallRemoveHooks(element)

NativeEventNames = new Set
NativeEventNames.add(nativeEvent) for nativeEvent in ["blur", "focus", "focusin",
"focusout", "load", "resize", "scroll", "unload", "click", "dblclick", "mousedown",
"mouseup", "mousemove", "mouseover", "mouseout", "mouseenter", "mouseleave", "change",
"select", "submit", "keydown", "keypress", "keyup", "error", "contextmenu", "textInput",
"textinput", "beforeunload"]

JQueryTrigger = jQuery.fn.trigger
jQuery.fn.trigger = (eventName, data) ->
  if NativeEventNames.has(eventName) or typeof eventName is 'object'
    JQueryTrigger.call(this, eventName, data)
  else
    data ?= {}
    data.jQueryTrigger = true

    for element in this
      atom.commands.dispatch(element, eventName, data)
    this

HandlersByOriginalHandler = new WeakMap
CommandDisposablesByElement = new WeakMap

AddEventListener = (element, type, listener) ->
  if NativeEventNames.has(type)
    element.addEventListener(type, listener)
  else
    disposable = atom.commands.add(element, type, listener)

    unless disposablesByType = CommandDisposablesByElement.get(element)
      disposablesByType = {}
      CommandDisposablesByElement.set(element, disposablesByType)

    unless disposablesByListener = disposablesByType[type]
      disposablesByListener = new WeakMap
      disposablesByType[type] = disposablesByListener

    disposablesByListener.set(listener, disposable)

RemoveEventListener = (element, type, listener) ->
  if NativeEventNames.has(type)
    element.removeEventListener(type, listener)
  else
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

JQueryContains = jQuery.contains

jQuery.contains = (a, b) ->
  shadowRoot = null
  currentNode = b
  while currentNode
    if currentNode instanceof ShadowRoot and a.contains(currentNode.host)
      return true
    currentNode = currentNode.parentNode

  JQueryContains.call(this, a, b)

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
