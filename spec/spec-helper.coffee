require 'window'
window.setUpEnvironment('spec')
window.restoreDimensions()

nakedLoad 'jasmine-jquery'
$ = jQuery = require 'jquery'
_ = require 'underscore'
Keymap = require 'keymap'
Config = require 'config'
Point = require 'point'
Project = require 'project'
Directory = require 'directory'
File = require 'file'
Editor = require 'editor'
TokenizedBuffer = require 'tokenized-buffer'
fsUtils = require 'fs-utils'
pathwatcher = require 'pathwatcher'
RootView = require 'root-view'
Git = require 'git'
clipboard = require 'clipboard'
requireStylesheet "jasmine"
fixturePackagesPath = fsUtils.resolveOnLoadPath('fixtures/packages')
config.packageDirPaths.unshift(fixturePackagesPath)
keymap.loadBundledKeymaps()
[bindingSetsToRestore, bindingSetsByFirstKeystrokeToRestore] = []

$(window).on 'core:close', -> window.close()
$(window).on 'unload', ->
  atom.windowMode = 'spec'
  atom.saveWindowState()
$('html,body').css('overflow', 'auto')

jasmine.getEnv().addEqualityTester(_.isEqual) # Use underscore's definition of equality for toEqual assertions
jasmine.getEnv().defaultTimeoutInterval = 5000

beforeEach ->
  jQuery.fx.off = true
  window.project = new Project(fsUtils.resolveOnLoadPath('fixtures'))
  window.git = Git.open(project.getPath())
  window.project.on 'path-changed', ->
    window.git?.destroy()
    window.git = Git.open(window.project.getPath())

  window.resetTimeouts()
  atom.windowMode = 'editor'
  atom.packageStates = {}
  spyOn(atom, 'saveWindowState')
  syntax.clearGrammarOverrides()
  syntax.clearProperties()

  # used to reset keymap after each spec
  bindingSetsToRestore = _.clone(keymap.bindingSets)
  bindingSetsByFirstKeystrokeToRestore = _.clone(keymap.bindingSetsByFirstKeystroke)

  # reset config before each spec; don't load or save from/to `config.json`
  window.config = new Config()
  spyOn(config, 'load')
  spyOn(config, 'save')
  config.set "editor.fontFamily", "Courier"
  config.set "editor.fontSize", 16
  config.set "editor.autoIndent", false
  config.set "core.disabledPackages", ["package-that-throws-an-exception"]
  config.save.reset()

  # make editor display updates synchronous
  spyOn(Editor.prototype, 'requestDisplayUpdate').andCallFake -> @updateDisplay()
  spyOn(RootView.prototype, 'setTitle').andCallFake (@title) ->
  spyOn(window, "setTimeout").andCallFake window.fakeSetTimeout
  spyOn(window, "clearTimeout").andCallFake window.fakeClearTimeout
  spyOn(File.prototype, "detectResurrectionAfterDelay").andCallFake -> @detectResurrection()

  # make tokenization synchronous
  TokenizedBuffer.prototype.chunkSize = Infinity
  spyOn(TokenizedBuffer.prototype, "tokenizeInBackground").andCallFake -> @tokenizeNextChunk()

  pasteboardContent = 'initial pasteboard content'
  spyOn(clipboard, 'writeText').andCallFake (text) -> pasteboardContent = text
  spyOn(clipboard, 'readText').andCallFake -> pasteboardContent

  addCustomMatchers(this)

afterEach ->
  keymap.bindingSets = bindingSetsToRestore
  keymap.bindingSetsByFirstKeystrokeToRestore = bindingSetsByFirstKeystrokeToRestore
  atom.deactivatePackages()
  if rootView?
    rootView.remove?()
    window.rootView = null
  if project?
    project.destroy()
    window.project = null
  if git?
    git.destroy()
    window.git = null
  $('#jasmine-content').empty() unless window.debugContent
  delete atom.windowState
  jasmine.unspy(atom, 'saveWindowState')
  ensureNoPathSubscriptions()
  syntax.off()
  waits(0) # yield to ui thread to make screen update more frequently

ensureNoPathSubscriptions = ->
  watchedPaths = pathwatcher.getWatchedPaths()
  pathwatcher.closeAllWatchers()
  if watchedPaths.length > 0
    throw new Error("Leaking subscriptions for paths: " + watchedPaths.join(", "))

emitObject = jasmine.StringPrettyPrinter.prototype.emitObject
jasmine.StringPrettyPrinter.prototype.emitObject = (obj) ->
  if obj.inspect
    @append obj.inspect()
  else
    emitObject.call(this, obj)

jasmine.unspy = (object, methodName) ->
  throw new Error("Not a spy") unless object[methodName].originalValue?
  object[methodName] = object[methodName].originalValue

addCustomMatchers = (spec) ->
  spec.addMatchers
    toBeInstanceOf: (expected) ->
      notText = if @isNot then " not" else ""
      this.message = => "Expected #{jasmine.pp(@actual)} to#{notText} be instance of #{expected.name} class"
      @actual instanceof expected

    toHaveLength: (expected) ->
      notText = if @isNot then " not" else ""
      this.message = => "Expected object with length #{@actual.length} to#{notText} have length #{expected}"
      @actual.length == expected

    toExistOnDisk: (expected) ->
      notText = this.isNot and " not" or ""
      @message = -> return "Expected path '" + @actual + "'" + notText + " to exist."
      fsUtils.exists(@actual)

window.keyIdentifierForKey = (key) ->
  if key.length > 1 # named key
    key
  else
    charCode = key.toUpperCase().charCodeAt(0)
    "U+00" + charCode.toString(16)

window.keydownEvent = (key, properties={}) ->
  properties = $.extend({originalEvent: { keyIdentifier: keyIdentifierForKey(key) }}, properties)
  $.Event("keydown", properties)

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
  @appendTo($('#jasmine-content'))

$.fn.simulateDomAttachment = ->
  $('<html>').append(this)

$.fn.textInput = (data) ->
  this.each ->
    event = document.createEvent('TextEvent')
    event.initTextEvent('textInput', true, true, window, data)
    event = jQuery.event.fix(event)
    $(this).trigger(event)

unless fsUtils.md5ForPath(require.resolve('fixtures/sample.js')) == "dd38087d0d7e3e4802a6d3f9b9745f2b"
  throw new Error("Sample.js is modified")
