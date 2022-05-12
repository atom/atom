require 'jasmine-json'
require '../src/window'
require '../vendor/jasmine-jquery'
path = require 'path'
_ = require 'underscore-plus'
fs = require 'fs-plus'
Grim = require 'grim'
pathwatcher = require 'pathwatcher'
FindParentDir = require 'find-parent-dir'
{CompositeDisposable} = require 'event-kit'

TextEditor = require '../src/text-editor'
TextEditorElement = require '../src/text-editor-element'
TextMateLanguageMode = require '../src/text-mate-language-mode'
TreeSitterLanguageMode = require '../src/tree-sitter-language-mode'
{clipboard} = require 'electron'

jasmineStyle = document.createElement('style')
jasmineStyle.textContent = atom.themes.loadStylesheet(atom.themes.resolveStylesheet('../static/jasmine'))
document.head.appendChild(jasmineStyle)

fixturePackagesPath = path.resolve(__dirname, './fixtures/packages')
atom.packages.packageDirPaths.unshift(fixturePackagesPath)

document.querySelector('html').style.overflow = 'auto'
document.body.style.overflow = 'auto'

Set.prototype.jasmineToString = ->
  result = "Set {"
  first = true
  @forEach (element) ->
    result += ", " unless first
    result += element.toString()
  first = false
  result + "}"

Set.prototype.isEqual = (other) ->
  if other instanceof Set
    return false if @size isnt other.size
    values = @values()
    until (next = values.next()).done
      return false unless other.has(next.value)
    true
  else
    false

jasmine.getEnv().addEqualityTester (a, b) ->
  # Match jasmine.any's equality matching logic
  return a.jasmineMatches(b) if a?.jasmineMatches?
  return b.jasmineMatches(a) if b?.jasmineMatches?

  # Use underscore's definition of equality for toEqual assertions
  _.isEqual(a, b)

if process.env.CI
  jasmine.getEnv().defaultTimeoutInterval = 120000
else
  jasmine.getEnv().defaultTimeoutInterval = 5000

{testPaths} = atom.getLoadSettings()

if specPackagePath = FindParentDir.sync(testPaths[0], 'package.json')
  packageMetadata = require(path.join(specPackagePath, 'package.json'))
  specPackageName = packageMetadata.name

if specDirectory = FindParentDir.sync(testPaths[0], 'fixtures')
  specProjectPath = path.join(specDirectory, 'fixtures')
else
  specProjectPath = require('os').tmpdir()

beforeEach ->
  # Do not clobber recent project history
  spyOn(Object.getPrototypeOf(atom.history), 'saveState').andReturn(Promise.resolve())

  atom.project.setPaths([specProjectPath])

  window.resetTimeouts()
  spyOn(_._, "now").andCallFake -> window.now
  spyOn(Date, 'now').andCallFake(-> window.now)
  spyOn(window, "setTimeout").andCallFake window.fakeSetTimeout
  spyOn(window, "clearTimeout").andCallFake window.fakeClearTimeout

  spy = spyOn(atom.packages, 'resolvePackagePath').andCallFake (packageName) ->
    if specPackageName and packageName is specPackageName
      resolvePackagePath(specPackagePath)
    else
      resolvePackagePath(packageName)
  resolvePackagePath = _.bind(spy.originalValue, atom.packages)

  # prevent specs from modifying Atom's menus
  spyOn(atom.menu, 'sendToBrowserProcess')

  # reset config before each spec
  atom.config.set "core.destroyEmptyPanes", false
  atom.config.set "editor.fontFamily", "Courier"
  atom.config.set "editor.fontSize", 16
  atom.config.set "editor.autoIndent", false
  atom.config.set "core.disabledPackages", ["package-that-throws-an-exception",
    "package-with-broken-package-json", "package-with-broken-keymap"]
  advanceClock(1000)
  window.setTimeout.reset()

  # make editor display updates synchronous
  TextEditorElement::setUpdatedSynchronously(true)

  spyOn(pathwatcher.File.prototype, "detectResurrectionAfterDelay").andCallFake -> @detectResurrection()
  spyOn(TextEditor.prototype, "shouldPromptToSave").andReturn false

  # make tokenization synchronous
  TextMateLanguageMode.prototype.chunkSize = Infinity
  TreeSitterLanguageMode.prototype.syncTimeoutMicros = Infinity
  spyOn(TextMateLanguageMode.prototype, "tokenizeInBackground").andCallFake -> @tokenizeNextChunk()

  # Without this spy, TextEditor.onDidTokenize callbacks would not be called
  # after the buffer's language mode changed, because by the time the editor
  # called its new language mode's onDidTokenize method, the language mode
  # would already be fully tokenized.
  spyOn(TextEditor.prototype, "onDidTokenize").andCallFake (callback) ->
    new CompositeDisposable(
      @emitter.on("did-tokenize", callback),
      @onDidChangeGrammar =>
        languageMode = @buffer.getLanguageMode()
        if languageMode.tokenizeInBackground?.originalValue
          callback()
    )

  clipboardContent = 'initial clipboard content'
  spyOn(clipboard, 'writeText').andCallFake (text) -> clipboardContent = text
  spyOn(clipboard, 'readText').andCallFake -> clipboardContent

  addCustomMatchers(this)

afterEach ->
  ensureNoDeprecatedFunctionCalls()
  ensureNoDeprecatedStylesheets()

  waitsForPromise ->
    atom.reset()

  runs ->
    document.getElementById('jasmine-content').innerHTML = '' unless window.debugContent
    warnIfLeakingPathSubscriptions()
    waits(0) # yield to ui thread to make screen update more frequently

warnIfLeakingPathSubscriptions = ->
  watchedPaths = pathwatcher.getWatchedPaths()
  if watchedPaths.length > 0
    console.error("WARNING: Leaking subscriptions for paths: " + watchedPaths.join(", "))
  pathwatcher.closeAllWatchers()

ensureNoDeprecatedFunctionCalls = ->
  deprecations = _.clone(Grim.getDeprecations())
  Grim.clearDeprecations()
  if deprecations.length > 0
    originalPrepareStackTrace = Error.prepareStackTrace
    Error.prepareStackTrace = (error, stack) ->
      output = []
      for deprecation in deprecations
        output.push "#{deprecation.originName} is deprecated. #{deprecation.message}"
        output.push _.multiplyString("-", output[output.length - 1].length)
        for stack in deprecation.getStacks()
          for {functionName, location} in stack
            output.push "#{functionName} -- #{location}"
        output.push ""
      output.join("\n")

    error = new Error("Deprecated function(s) #{deprecations.map(({originName}) -> originName).join ', '}) were called.")
    error.stack
    Error.prepareStackTrace = originalPrepareStackTrace
    throw error

ensureNoDeprecatedStylesheets = ->
  deprecations = _.clone(atom.styles.getDeprecations())
  atom.styles.clearDeprecations()
  for sourcePath, deprecation of deprecations
    title =
      if sourcePath isnt 'undefined'
        "Deprecated stylesheet at '#{sourcePath}':"
      else
        "Deprecated stylesheet:"
    throw new Error("#{title}\n#{deprecation.message}")

emitObject = jasmine.StringPrettyPrinter.prototype.emitObject
jasmine.StringPrettyPrinter.prototype.emitObject = (obj) ->
  if obj.inspect
    @append obj.inspect()
  else
    emitObject.call(this, obj)

jasmine.unspy = (object, methodName) ->
  throw new Error("Not a spy") unless object[methodName].hasOwnProperty('originalValue')
  object[methodName] = object[methodName].originalValue

jasmine.attachToDOM = (element) ->
  jasmineContent = document.querySelector('#jasmine-content')
  jasmineContent.appendChild(element) unless jasmineContent.contains(element)

grimDeprecationsSnapshot = null
stylesDeprecationsSnapshot = null
jasmine.snapshotDeprecations = ->
  grimDeprecationsSnapshot = _.clone(Grim.deprecations)
  stylesDeprecationsSnapshot = _.clone(atom.styles.deprecationsBySourcePath)

jasmine.restoreDeprecationsSnapshot = ->
  Grim.deprecations = grimDeprecationsSnapshot
  atom.styles.deprecationsBySourcePath = stylesDeprecationsSnapshot

jasmine.useRealClock = ->
  jasmine.unspy(window, 'setTimeout')
  jasmine.unspy(window, 'clearTimeout')
  jasmine.unspy(_._, 'now')
  jasmine.unspy(Date, 'now')

# The clock is halfway mocked now in a sad and terrible way... only setTimeout
# and clearTimeout are included. This method will also include setInterval. We
# would do this everywhere if didn't cause us to break a bunch of package tests.
jasmine.useMockClock = ->
  spyOn(window, 'setInterval').andCallFake(fakeSetInterval)
  spyOn(window, 'clearInterval').andCallFake(fakeClearInterval)

addCustomMatchers = (spec) ->
  spec.addMatchers
    toBeInstanceOf: (expected) ->
      beOrNotBe = if @isNot then "not be" else "be"
      this.message = => "Expected #{jasmine.pp(@actual)} to #{beOrNotBe} instance of #{expected.name} class"
      @actual instanceof expected

    toHaveLength: (expected) ->
      if not @actual?
        this.message = => "Expected object #{@actual} has no length method"
        false
      else
        haveOrNotHave = if @isNot then "not have" else "have"
        this.message = => "Expected object with length #{@actual.length} to #{haveOrNotHave} length #{expected}"
        @actual.length is expected

    toExistOnDisk: (expected) ->
      toOrNotTo = this.isNot and "not to" or "to"
      @message = -> return "Expected path '#{@actual}' #{toOrNotTo} exist."
      fs.existsSync(@actual)

    toHaveFocus: ->
      toOrNotTo = this.isNot and "not to" or "to"
      if not document.hasFocus()
        console.error "Specs will fail because the Dev Tools have focus. To fix this close the Dev Tools or click the spec runner."

      @message = -> return "Expected element '#{@actual}' or its descendants #{toOrNotTo} have focus."
      element = @actual
      element = element.get(0) if element.jquery
      element is document.activeElement or element.contains(document.activeElement)

    toShow: ->
      toOrNotTo = this.isNot and "not to" or "to"
      element = @actual
      element = element.get(0) if element.jquery
      @message = -> return "Expected element '#{element}' or its descendants #{toOrNotTo} show."
      computedStyle = getComputedStyle(element)
      computedStyle.display isnt 'none' and computedStyle.visibility is 'visible' and not element.hidden

    toEqualPath: (expected) ->
      actualPath = path.normalize(@actual)
      expectedPath = path.normalize(expected)
      @message = -> return "Expected path '#{actualPath}' to be equal to '#{expectedPath}'."
      actualPath is expectedPath

    toBeNear: (expected, acceptedError = 1, actual) ->
      return (typeof expected is 'number') and (typeof acceptedError is 'number') and (typeof @actual is 'number') and (expected - acceptedError <= @actual) and (@actual <= expected + acceptedError)

    toHaveNearPixels: (expected, acceptedError = 1, actual) ->
      expectedNumber =  parseFloat(expected)
      actualNumber =  parseFloat(@actual)
      return (typeof expected is 'string') and (typeof acceptedError is 'number') and (typeof @actual is 'string') and (expected.indexOf('px') >= 1) and (@actual.indexOf('px') >= 1) and (expectedNumber - acceptedError <= actualNumber) and (actualNumber <= expectedNumber + acceptedError)

window.waitsForPromise = (args...) ->
  label = null
  if args.length > 1
    {shouldReject, timeout, label} = args[0]
  else
    shouldReject = false
  label ?= 'promise to be resolved or rejected'
  fn = _.last(args)

  window.waitsFor label, timeout, (moveOn) ->
    promise = fn()
    if shouldReject
      promise.catch.call(promise, moveOn)
      promise.then ->
        jasmine.getEnv().currentSpec.fail("Expected promise to be rejected, but it was resolved")
        moveOn()
    else
      promise.then(moveOn)
      promise.catch.call promise, (error) ->
        jasmine.getEnv().currentSpec.fail("Expected promise to be resolved, but it was rejected with: #{error?.message} #{jasmine.pp(error)}")
        moveOn()

window.resetTimeouts = ->
  window.now = 0
  window.timeoutCount = 0
  window.intervalCount = 0
  window.timeouts = []
  window.intervalTimeouts = {}

window.fakeSetTimeout = (callback, ms=0) ->
  id = ++window.timeoutCount
  window.timeouts.push([id, window.now + ms, callback])
  id

window.fakeClearTimeout = (idToClear) ->
  window.timeouts = window.timeouts.filter ([id]) -> id isnt idToClear

window.fakeSetInterval = (callback, ms) ->
  id = ++window.intervalCount
  action = ->
    callback()
    window.intervalTimeouts[id] = window.fakeSetTimeout(action, ms)
  window.intervalTimeouts[id] = window.fakeSetTimeout(action, ms)
  id

window.fakeClearInterval = (idToClear) ->
  window.fakeClearTimeout(@intervalTimeouts[idToClear])

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

exports.mockLocalStorage = ->
  items = {}
  spyOn(global.localStorage, 'setItem').andCallFake (key, item) -> items[key] = item.toString(); undefined
  spyOn(global.localStorage, 'getItem').andCallFake (key) -> items[key] ? null
  spyOn(global.localStorage, 'removeItem').andCallFake (key) -> delete items[key]; undefined
