nakedLoad 'jasmine-jquery'
$ = require 'jquery'
_ = require 'underscore'
Native = require 'native'
GlobalKeymap = require 'global-keymap'
Point = require 'point'

require 'window'
window.showConsole()

beforeEach ->
  window.resetTimeouts()

afterEach ->
  (new Native).resetMainMenu()
  atom.globalKeymap.reset()
  $('#jasmine-content').empty()

# Use underscore's definition of equality for toEqual assertions
jasmine.Env.prototype.equals_ = _.isEqual

emitObject = jasmine.StringPrettyPrinter.prototype.emitObject
jasmine.StringPrettyPrinter.prototype.emitObject = (obj) ->
  if obj.inspect
    @append obj.inspect()
  else
    emitObject.call(this, obj)

window.eventPropertiesForPattern = (pattern) ->
  [modifiers..., key] = pattern.split '-'

  modifiers.push 'shift' if key == key.toUpperCase() and key.toUpperCase() != key.toLowerCase()
  charCode = key.toUpperCase().charCodeAt 0

  isNamedKey = key.length > 1
  if isNamedKey
    keyIdentifier = key
  else
    keyIdentifier = "U+00" + charCode.toString(16)

  ctrlKey: 'ctrl' in modifiers
  altKey: 'alt' in modifiers
  shiftKey: 'shift' in modifiers
  metaKey: 'meta' in modifiers
  which: charCode
  originalEvent:
    keyIdentifier: keyIdentifier

window.keydownEvent = (pattern, properties={}) ->
  event = $.Event "keydown", _.extend(eventPropertiesForPattern(pattern), properties)
  event.keystroke = (new GlobalKeymap).keystrokeStringForEvent(event)
  event

window.clickEvent = (properties={}) ->
  $.Event "click", properties

window.mousedownEvent = (properties={}) ->
  properties.originalEvent ?= {detail: 1}
  $.Event "mousedown", properties

window.mousemoveEvent = (properties={}) ->
  $.Event "mousemove", properties

window.waitsForPromise = (fn) ->
  window.waitsFor (moveOn) ->
    fn().done(moveOn)

window.resetTimeouts = ->
  window.now = 0
  window.timeoutCount = 0
  window.timeouts = []

window.setTimeout = (callback, ms) ->
  id = ++window.timeoutCount
  window.timeouts.push([id, window.now + ms, callback])
  id

window.clearTimeout = (idToClear) ->
  window.timeouts = window.timeouts.filter ([id]) -> id != idToClear

window.advanceClock = (delta) ->
  window.now += delta
  window.timeouts = window.timeouts.filter ([id, strikeTime, callback]) ->
    if strikeTime <= window.now
      callback()
      false
    else
      true

window.pixelPositionForPoint = (editor, point) ->
  point = Point.fromObject point
  pageY = editor.lines.offset().top + point.row * editor.lineHeight + 1 # ensure the pixel is inside the char
  pageX = editor.lines.offset().left + point.column * editor.charWidth + 1 # ensure the pixel is inside the char
  [pageX, pageY]

window.tokensText = (tokens) ->
  _.pluck(tokens, 'value').join('')

$.fn.resultOfTrigger = (type) ->
  event = $.Event(type)
  this.trigger(event)
  event.result

$.fn.enableKeymap = ->
  @on 'keydown', (e) => atom.globalKeymap.handleKeyEvent(e)

$.fn.attachToDom = ->
  $('#jasmine-content').append(this)

$.fn.textInput = (data) ->
  event = document.createEvent 'TextEvent'
  event.initTextEvent('textInput', true, true, window, data)
  this.each -> this.dispatchEvent(event)
