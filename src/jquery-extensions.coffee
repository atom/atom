$ = require '../vendor/jquery'
_ = require './underscore-extensions'

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

$.fn.isVisible = ->
  !@isHidden()

$.fn.isHidden = ->
  # Implementation taken from jQuery's `:hidden` expression code:
  # https://github.com/jquery/jquery/blob/master/src/css/hiddenVisibleSelectors.js
  #
  # We were using a pseudo selector: @is(':hidden'). But jQuery's pseudo
  # selector code checks the element's webkitMatchesSelector, which is always
  # false, and is really really really slow.

  elem = this[0]

  return null unless elem

  elem.offsetWidth <= 0 and elem.offsetHeight <= 0

$.fn.isDisabled = ->
  !!@attr('disabled')

$.fn.enable = ->
  @removeAttr('disabled')

$.fn.disable = ->
  @attr('disabled', 'disabled')

$.fn.insertAt = (index, element) ->
  target = @children(":eq(#{index})")
  if target.length
    $(element).insertBefore(target)
  else
    @append(element)

$.fn.removeAt = (index) ->
  @children(":eq(#{index})").remove()

$.fn.indexOf = (child) ->
  @children().toArray().indexOf($(child)[0])

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

$.fn.intValue = ->
  parseInt(@text())

$.Event.prototype.abortKeyBinding = ->
$.Event.prototype.currentTargetView = -> $(this.currentTarget).view()
$.Event.prototype.targetView = -> $(this.target).view()

module.exports = $
