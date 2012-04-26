nakedLoad 'jasmine-jquery'
$ = require 'jquery'
_ = require 'underscore'
Keymap = require 'keymap'
Point = require 'point'
Directory = require 'directory'
require 'window'
window.showConsole()

defaultTitle = document.title
directoriesWithSubscriptions = null

beforeEach ->
  window.resetTimeouts()
  directoriesWithSubscriptions = []

afterEach ->
  $('#jasmine-content').empty()
  document.title = defaultTitle
  ensureNoDirectorySubscriptions()


window.keymap.bindKeys '*', 'meta-w': 'close'
$(document).on 'close', -> window.close()

Directory.prototype.originalOn = Directory.prototype.on
Directory.prototype.on = (args...) ->
  directoriesWithSubscriptions.push(this) if @subscriptionCount() == 0
  @originalOn(args...)

ensureNoDirectorySubscriptions = ->
  totalSubscriptionCount = 0
  for directory in directoriesWithSubscriptions
    totalSubscriptionCount += directory.subscriptionCount()
    console.log "Non-zero subscription count on", directory if directory.subscriptionCount() > 0

  if totalSubscriptionCount > 0
    throw new Error("Total directory subscription count was #{totalSubscriptionCount}, when it should have been 0.\nSee console for details.")

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
  event.keystroke = (new Keymap).keystrokeStringForEvent(event)
  event

window.clickEvent = (properties={}) ->
  $.Event "click", properties

window.mouseEvent = (type, properties) ->
  if properties.point
    {point, editor} = properties
    {top, left} = @pagePixelPositionForPoint(editor, point)
    properties.pageX = left + 1
    properties.pageY = top + 1
  properties.originalEvent ?= {detail: 1}
  $.Event type, properties

window.mousedownEvent = (properties={}) ->
  window.mouseEvent('mousedown', properties)

window.mousemoveEvent = (properties={}) ->
  window.mouseEvent('mousemove', properties)

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

window.advanceClock = (delta=1) ->
  window.now += delta
  window.timeouts = window.timeouts.filter ([id, strikeTime, callback]) ->
    if strikeTime <= window.now
      callback()
      false
    else
      true

window.pagePixelPositionForPoint = (editor, point) ->
  point = Point.fromObject point
  top = editor.lines.offset().top + point.row * editor.lineHeight
  left = editor.lines.offset().left + point.column * editor.charWidth - editor.lines.scrollLeft()
  { top, left }

window.tokensText = (tokens) ->
  _.pluck(tokens, 'value').join('')

window.setEditorWidthInChars = (editor, widthInChars, charWidth=editor.charWidth) ->
  editor.width(charWidth * widthInChars + editor.lines.position().left)

window.setEditorHeightInLines = (editor, heightInChars, charHeight=editor.lineHeight) ->
  editor.height(charHeight * heightInChars + editor.lines.position().top)

$.fn.resultOfTrigger = (type) ->
  event = $.Event(type)
  this.trigger(event)
  event.result

$.fn.enableKeymap = ->
  @on 'keydown', (e) => window.keymap.handleKeyEvent(e)

$.fn.attachToDom = ->
  $('#jasmine-content').append(this)

$.fn.textInput = (data) ->
  this.each ->
    event = document.createEvent('TextEvent')
    event.initTextEvent('textInput', true, true, window, data)
    event = jQuery.event.fix(event)
    $(this).trigger(event)

$.fn.simulateDomAttachment = ->
  $('<html>').append(this)
