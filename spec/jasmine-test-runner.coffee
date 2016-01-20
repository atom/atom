_ = require 'underscore-plus'
fs = require 'fs-plus'
path = require 'path'
ipc = require 'ipc'

module.exports = ({logFile, headless, testPaths, buildAtomEnvironment}) ->
  window[key] = value for key, value of require '../vendor/jasmine'
  require 'jasmine-tagged'

  # Allow document.title to be assigned in specs without screwing up spec window title
  documentTitle = null
  Object.defineProperty document, 'title',
    get: -> documentTitle
    set: (title) -> documentTitle = title

  ApplicationDelegate = require '../src/application-delegate'
  applicationDelegate = new ApplicationDelegate()
  applicationDelegate.setRepresentedFilename = ->
  applicationDelegate.setWindowDocumentEdited = ->
  window.atom = buildAtomEnvironment({
    applicationDelegate, window, document,
    configDirPath: process.env.ATOM_HOME
    enablePersistence: false
  })

  require './spec-helper'
  disableFocusMethods() if process.env.JANKY_SHA1 or process.env.CI
  requireSpecs(testPath) for testPath in testPaths

  setSpecType('user')

  resolveWithExitCode = null
  promise = new Promise (resolve, reject) -> resolveWithExitCode = resolve
  jasmineEnv = jasmine.getEnv()
  jasmineEnv.addReporter(buildReporter({logFile, headless, resolveWithExitCode}))
  TimeReporter = require './time-reporter'
  jasmineEnv.addReporter(new TimeReporter())
  jasmineEnv.setIncludedTags([process.platform])

  jasmineContent = document.createElement('div')
  jasmineContent.setAttribute('id', 'jasmine-content')

  document.body.appendChild(jasmineContent)

  jasmineEnv.execute()
  promise

disableFocusMethods = ->
  ['fdescribe', 'ffdescribe', 'fffdescribe', 'fit', 'ffit', 'fffit'].forEach (methodName) ->
    focusMethod = window[methodName]
    window[methodName] = (description) ->
      error = new Error('Focused spec is running on CI')
      focusMethod description, -> throw error

requireSpecs = (testPath, specType) ->
  if fs.isDirectorySync(testPath)
    for testFilePath in fs.listTreeSync(testPath) when /-spec\.(coffee|js)$/.test testFilePath
      require(testFilePath)
      # Set spec directory on spec for setting up the project in spec-helper
      setSpecDirectory(testPath)
  else
    require(testPath)
    setSpecDirectory(path.dirname(testPath))

setSpecField = (name, value) ->
  specs = jasmine.getEnv().currentRunner().specs()
  return if specs.length is 0
  for index in [specs.length-1..0]
    break if specs[index][name]?
    specs[index][name] = value

setSpecType = (specType) ->
  setSpecField('specType', specType)

setSpecDirectory = (specDirectory) ->
  setSpecField('specDirectory', specDirectory)

buildReporter = ({logFile, headless, resolveWithExitCode}) ->
  if headless
    buildTerminalReporter(logFile, resolveWithExitCode)
  else
    AtomReporter = require './atom-reporter'
    reporter = new AtomReporter()

buildTerminalReporter = (logFile, resolveWithExitCode) ->
  logStream = fs.openSync(logFile, 'w') if logFile?
  log = (str) ->
    if logStream?
      fs.writeSync(logStream, str)
    else
      ipc.send 'write-to-stderr', str

  {TerminalReporter} = require 'jasmine-tagged'
  new TerminalReporter
    print: (str) ->
      log(str)
    onComplete: (runner) ->
      fs.closeSync(logStream) if logStream?
      if process.env.JANKY_SHA1 or process.env.CI
        grim = require 'grim'

        if grim.getDeprecationsLength() > 0
          grim.logDeprecations()
          resolveWithExitCode(1)
          return

      if runner.results().failedCount > 0
        resolveWithExitCode(1)
      else
        resolveWithExitCode(0)
