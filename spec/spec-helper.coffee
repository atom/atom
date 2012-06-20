nakedLoad 'jasmine-jquery'
$ = require 'jquery'
_ = require 'underscore'
Keymap = require 'keymap'
Point = require 'point'
Project = require 'project'
Directory = require 'directory'
RootView = require 'root-view'
require 'window'
window.showConsole()

requireStylesheet "jasmine.css"

defaultTitle = document.title
directoriesWithSubscriptions = null

beforeEach ->
  window.fixturesProject = new Project(require.resolve('fixtures'))
  window.resetTimeouts()
  directoriesWithSubscriptions = []

afterEach ->
  delete window.rootView if window.rootView
  $('#jasmine-content').empty()
  document.title = defaultTitle
  ensureNoDirectorySubscriptions()

window.keymap.bindKeys '*', 'meta-w': 'close'
$(document).on 'close', -> window.close()

# Don't load user configuration in specs, because it's variable
RootView.prototype.loadUserConfiguration = ->

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

window.keyIdentifierForKey = (key) ->
  if key.length > 1 # named key
    key
  else
    charCode = key.toUpperCase().charCodeAt(0)
    "U+00" + charCode.toString(16)

window.keydownEvent = (key, properties={}) ->
  event = $.Event "keydown", _.extend({originalEvent: { keyIdentifier: keyIdentifierForKey(key) }}, properties)
  # event.keystroke = (new Keymap).keystrokeStringForEvent(event)
  event

window.mouseEvent = (type, properties) ->
  if properties.point
    {point, editor} = properties
    {top, left} = @pagePixelPositionForPoint(editor, point)
    properties.pageX = left + 1
    properties.pageY = top + 1
  properties.originalEvent ?= {detail: 1}
  $.Event type, properties

window.clickEvent = (properties={}) ->
  window.mouseEvent("click", properties)

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
  top = editor.renderedLines.offset().top + point.row * editor.lineHeight
  left = editor.renderedLines.offset().left + point.column * editor.charWidth - editor.renderedLines.scrollLeft()
  { top, left }

window.tokensText = (tokens) ->
  _.pluck(tokens, 'value').join('')

window.setEditorWidthInChars = (editor, widthInChars, charWidth=editor.charWidth) ->
  editor.width(charWidth * widthInChars + editor.renderedLines.position().left)

window.setEditorHeightInLines = (editor, heightInChars, charHeight=editor.lineHeight) ->
  editor.height(charHeight * heightInChars + editor.renderedLines.position().top)
  $(window).trigger 'resize' # update editor's on-screen lines

$.fn.resultOfTrigger = (type) ->
  event = $.Event(type)
  this.trigger(event)
  event.result

$.fn.enableKeymap = ->
  @on 'keydown', (e) => window.keymap.handleKeyEvent(e)

$.fn.attachToDom = ->
  $('#jasmine-content').append(this)

$.fn.simulateDomAttachment = ->
  $('<html>').append(this)

$.fn.textInput = (data) ->
  this.each ->
    event = document.createEvent('TextEvent')
    event.initTextEvent('textInput', true, true, window, data)
    event = jQuery.event.fix(event)
    $(this).trigger(event)

$.fn.simulateDomAttachment = ->
  $('<html>').append(this)
