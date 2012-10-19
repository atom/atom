$ = require 'jquery'
_ = require 'underscore'

$.fn.scrollBottom = (newValue) ->
  if newValue?
    @scrollTop(newValue - @height())
  else
    @scrollTop() + @height()

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
  window.setTimeout(removeErrorClass, 200)

$.fn.trueHeight = ->
  this[0].getBoundingClientRect().height

$.fn.trueWidth = ->
  this[0].getBoundingClientRect().width

$.fn.document = (eventDescriptions) ->
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

$.fn.command = (args...) ->
  eventName = args[0]
  documentation = {}
  documentation[eventName] = _.humanizeEventName(eventName)
  @document(documentation)
  @on(args...)

$.Event.prototype.abortKeyBinding = ->
