nakedLoad 'jasmine-jquery'
$ = require 'jquery'
_ = require 'underscore'
Keymap = require 'keymap'
Point = require 'point'
Project = require 'project'
Directory = require 'directory'
File = require 'file'
RootView = require 'root-view'
Editor = require 'editor'
TextMateBundle = require 'text-mate-bundle'
TextMateTheme = require 'text-mate-theme'
fs = require 'fs'
require 'window'

requireStylesheet "jasmine.css"

pathsWithSubscriptions = null

beforeEach ->
  window.fixturesProject = new Project(require.resolve('fixtures'))
  window.resetTimeouts()
  pathsWithSubscriptions = []

  # make editor display updates synchronous
  spyOn(Editor.prototype, 'requestDisplayUpdate').andCallFake -> @updateDisplay()
  spyOn(RootView.prototype, 'updateWindowTitle').andCallFake ->
  spyOn(window, "setTimeout").andCallFake window.fakeSetTimeout
  spyOn(window, "clearTimeout").andCallFake window.fakeClearTimeout
  spyOn(File.prototype, "detectResurrectionAfterDelay").andCallFake -> @detectResurrection()

afterEach ->
  delete window.rootView if window.rootView
  $('#jasmine-content').empty()
  ensureNoPathSubscriptions()
  window.fixturesProject.destroy()

window.keymap.bindKeys '*', 'meta-w': 'close'
$(document).on 'close', -> window.close()
$('html,body').css('overflow', 'auto')

# Don't load user configuration in specs, because it's variable
RootView.prototype.loadUserConfiguration = ->

for klass in [Directory, File]
  klass.prototype.originalOn = klass.prototype.on
  klass.prototype.on = (args...) ->
    pathsWithSubscriptions.push(this) if @subscriptionCount() == 0
    @originalOn(args...)

ensureNoPathSubscriptions = ->
  totalSubscriptionCount = 0
  for path in pathsWithSubscriptions
    totalSubscriptionCount += path.subscriptionCount()
    console.log "Non-zero subscription count on", path if path.subscriptionCount() > 0

  if totalSubscriptionCount > 0
    throw new Error("Total path subscription count was #{totalSubscriptionCount}, when it should have been 0.\nSee console for details.")

# Use underscore's definition of equality for toEqual assertions
jasmine.Env.prototype.equals_ = _.isEqual

emitObject = jasmine.StringPrettyPrinter.prototype.emitObject
jasmine.StringPrettyPrinter.prototype.emitObject = (obj) ->
  if obj.inspect
    @append obj.inspect()
  else
    emitObject.call(this, obj)

jasmine.unspy = (object, methodName) ->
  throw new Error("Not a spy") unless object[methodName].originalValue?
  object[methodName] = object[methodName].originalValue

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

window.waitsForPromise = (args...) ->
  if args.length > 1
    { shouldReject } = args[0]
  else
    shouldReject = false
  fn = _.last(args)

  window.waitsFor (moveOn) ->
    promise = fn()
    if shouldReject
      promise.fail(moveOn)
      promise.done ->
        jasmine.getEnv().currentSpec.fail("Expected promise to be rejected, but it was resolved")
        moveOn()
    else
      promise.done(moveOn)
      promise.fail (error) ->
        jasmine.getEnv().currentSpec.fail("Expected promise to be resolved, but it was rejected with #{jasmine.pp(error)}")
        moveOn()

window.resetTimeouts = ->
  window.now = 0
  window.timeoutCount = 0
  window.timeouts = []

window.fakeSetTimeout = (callback, ms) ->
  id = ++window.timeoutCount
  window.timeouts.push([id, window.now + ms, callback])
  id

window.fakeClearTimeout = (idToClear) ->
  window.timeouts = window.timeouts.filter ([id]) -> id != idToClear

window.advanceClock = (delta=1) ->
  window.now += delta
  callbacks = []

  window.timeouts = window.timeouts.filter ([id, strikeTime, callback]) ->
    if strikeTime <= window.now
      callbacks.push(callback)
      false
    else
      true

  callback() for callback in callbacks

window.pagePixelPositionForPoint = (editor, point) ->
  point = Point.fromObject point
  top = editor.renderedLines.offset().top + point.row * editor.lineHeight
  left = editor.renderedLines.offset().left + point.column * editor.charWidth - editor.renderedLines.scrollLeft()
  { top, left }

window.tokensText = (tokens) ->
  _.pluck(tokens, 'value').join('')

window.setEditorWidthInChars = (editor, widthInChars, charWidth=editor.charWidth) ->
  editor.width(charWidth * widthInChars + editor.gutter.outerWidth())
  $(window).trigger 'resize' # update width of editor's on-screen lines

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

unless fs.md5ForPath(require.resolve('fixtures/sample.js')) == "dd38087d0d7e3e4802a6d3f9b9745f2b"
  throw "Sample.js is modified"
