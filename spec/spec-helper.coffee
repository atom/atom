require 'jasmine-jquery'
$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'
path = require 'path'
Keymap = require 'app/keymap'
Point = require 'app/point'
Project = require 'app/project'
Directory = require 'app/directory'
File = require 'app/file'
RootView = require 'app/root-view'
Editor = require 'app/editor'
TextMateBundle = require 'app/text-mate-bundle'
TextMateTheme = require 'app/text-mate-theme'
TokenizedBuffer = require 'app/tokenized-buffer'

beforeEach ->
  global.fixturesProject = new Project(path.resolveOnLoadPath('fixtures'))
  resetTimeouts()

  # make editor display updates synchronous
  spyOn(Editor.prototype, 'requestDisplayUpdate').andCallFake -> @updateDisplay()
  spyOn(RootView.prototype, 'updateWindowTitle').andCallFake ->
  spyOn(global, "setTimeout").andCallFake fakeSetTimeout
  spyOn(global, "clearTimeout").andCallFake fakeClearTimeout
  spyOn(File.prototype, "detectResurrectionAfterDelay").andCallFake -> @detectResurrection()

  # make tokenization synchronous
  TokenizedBuffer.prototype.chunkSize = Infinity
  spyOn(TokenizedBuffer.prototype, "tokenizeInBackground").andCallFake -> @tokenizeNextChunk()

afterEach ->
  delete window.rootView if window.rootView
  $('#jasmine-content').empty()
  fixturesProject.destroy()
  ensureNoPathSubscriptions()
  waits(0) # yield to ui thread to make screen update more frequently

window.keymap.bindKeys '*', 'meta-w': 'close'
$(document).on 'close', -> window.close()
$('html,body').css('overflow', 'auto')

# Don't load user configuration in specs, because it's variable
RootView.prototype.loadUserConfiguration = ->

ensureNoPathSubscriptions = ->
#   watchedPaths = $native.getWatchedPaths()
#   $native.unwatchAllPaths()
#   if watchedPaths.length > 0
#     throw new Error("Leaking subscriptions for paths: " + watchedPaths.join(", "))

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

jasmine.getEnv().defaultTimeoutInterval = 200

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

global.resetTimeouts = ->
  window.now = 0
  window.timeoutCount = 0
  window.timeouts = []

global.fakeSetTimeout = (callback, ms) ->
  id = ++window.timeoutCount
  window.timeouts.push([id, window.now + ms, callback])
  id

global.fakeClearTimeout = (idToClear) ->
  window.timeouts = window.timeouts.filter ([id]) -> id != idToClear

global.advanceClock = (delta=1) ->
  window.now += delta
  callbacks = []

  window.timeouts = window.timeouts.filter ([id, strikeTime, callback]) ->
    if strikeTime <= window.now
      callbacks.push(callback)
      false
    else
      true

  callback() for callback in callbacks

global.pagePixelPositionForPoint = (editor, point) ->
  point = Point.fromObject point
  top = editor.renderedLines.offset().top + point.row * editor.lineHeight
  left = editor.renderedLines.offset().left + point.column * editor.charWidth - editor.renderedLines.scrollLeft()
  { top, left }

global.tokensText = (tokens) ->
  _.pluck(tokens, 'value').join('')

global.setEditorWidthInChars = (editor, widthInChars, charWidth=editor.charWidth) ->
  editor.width(charWidth * widthInChars + editor.gutter.outerWidth())
  $(window).trigger 'resize' # update width of editor's on-screen lines

global.setEditorHeightInLines = (editor, heightInChars, charHeight=editor.lineHeight) ->
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

# FIXME
# unless fs.md5ForPath(require.resolve('fixtures/sample.js')) == "dd38087d0d7e3e4802a6d3f9b9745f2b"
#   throw "Sample.js is modified"
