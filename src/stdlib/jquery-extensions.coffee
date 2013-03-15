$ = require 'jquery'
_ = require 'underscore'

$.fn.scrollBottom = (newValue) ->
  if newValue?
    @scrollTop(newValue - @height())
  else
    @scrollTop() + @height()

$.fn.scrollDown = ->
  @scrollTop(@scrollTop() + $(window).height() / 20)

$.fn.scrollUp = ->
  @scrollTop(@scrollTop() - $(window).height() / 20)

$.fn.scrollToTop = ->
  @scrollTop(0)

$.fn.scrollToBottom = ->
  @scrollTop(@prop('scrollHeight'))

$.fn.scrollRight = (newValue) ->
  if newValue?
    @scrollLeft(newValue - @width())
  else
    @scrollLeft() + @width()

$.fn.pageUp = ->
  @scrollTop(@scrollTop() - @height())

$.fn.pageDown = ->
  @scrollTop(@scrollTop() + @height())

$.fn.isOnDom = ->
  @closest(document.body).length is 1

$.fn.containsElement = (element) ->
  (element[0].compareDocumentPosition(this[0]) & 8) == 8

$.fn.preempt = (eventName, handler) ->
  @on eventName, (e, args...) ->
    if handler(e, args...) == false then e.stopImmediatePropagation()

  eventNameWithoutNamespace = eventName.split('.')[0]
  handlers = @data('events')[eventNameWithoutNamespace]
  handlers.unshift(handlers.pop())

$.fn.hasParent = ->
  @parent()[0]?

$.fn.flashError = ->
  @addClass 'error'
  removeErrorClass = => @removeClass 'error'
  window.setTimeout(removeErrorClass, 300)

$.fn.trueHeight = ->
  this[0].getBoundingClientRect().height

$.fn.trueWidth = ->
  this[0].getBoundingClientRect().width

$.fn.document = (eventName, docString) ->
  eventDescriptions = {}
  eventDescriptions[eventName] = docString
  @data('documentation', {}) unless @data('documentation')
  _.extend(@data('documentation'), eventDescriptions)

$.fn.events = ->
  documentation = @data('documentation') ? {}
  events = {}

  for eventName of @data('events') ? {}
    events[eventName] = documentation[eventName] ? null

  if @hasParent()
    _.extend(@parent().events(), events)
  else
    events

$.fn.command = (eventName, selector, options, handler) ->
  if not options?
    handler  = selector
    selector = null
  else if not handler?
    handler = options
    options = null

  if selector? and typeof(selector) is 'object'
    options  = selector
    selector = null

  @document(eventName, _.humanizeEventName(eventName, options?["doc"]))
  @on(eventName, selector, options?['data'], handler)

$.fn.iconSize = (size) ->
  @width(size).height(size).css('font-size', size)

$.Event.prototype.abortKeyBinding = ->
$.Event.prototype.currentTargetView = -> $(this.currentTarget).view()
$.Event.prototype.targetView = -> $(this.target).view()
