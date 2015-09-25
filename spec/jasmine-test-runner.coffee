fs = require 'fs'
_ = require 'underscore-plus'
fs = require 'fs-plus'
path = require 'path'

module.exports = ({logFile, headless, testPaths}) ->
  window[key] = value for key, value of require '../vendor/jasmine'
  require 'jasmine-tagged'

  require './spec-helper'
  disableFocusMethods() if process.env.JANKY_SHA1 or process.env.CI
  requireSpecs(testPath) for testPath in testPaths

  setSpecType('user')

  jasmineEnv = jasmine.getEnv()
  jasmineEnv.addReporter(buildReporter({logFile, headless}))
  TimeReporter = require './time-reporter'
  jasmineEnv.addReporter(new TimeReporter())
  jasmineEnv.setIncludedTags([process.platform])

  jasmineContent = document.createElement('div')
  jasmineContent.setAttribute('id', 'jasmine-content')
  document.body.appendChild(jasmineContent)

  jasmineEnv.execute()

disableFocusMethods = ->
  ['fdescribe', 'ffdescribe', 'fffdescribe', 'fit', 'ffit', 'fffit'].forEach (methodName) ->
    focusMethod = window[methodName]
    window[methodName] = (description) ->
      error = new Error('Focused spec is running on CI')
      focusMethod description, -> throw error

requireSpecs = (specDirectory, specType) ->
  for specFilePath in fs.listTreeSync(specDirectory) when /-spec\.(coffee|js)$/.test specFilePath
    require specFilePath
    # Set spec directory on spec for setting up the project in spec-helper
    setSpecDirectory(specDirectory)

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

buildReporter = ({logFile, headless}) ->
  if headless
    buildTerminalReporter(logFile)
  else
    AtomReporter = require './atom-reporter'
    reporter = new AtomReporter()

buildTerminalReporter = (logFile) ->
  logStream = fs.openSync(logFile, 'w') if logFile?
  log = (str) ->
    if logStream?
      fs.writeSync(logStream, str)
    else
      process.stderr.write(str)

  {TerminalReporter} = require 'jasmine-tagged'
  new TerminalReporter
    print: (str) ->
      log(str)
    onComplete: (runner) ->
      fs.closeSync(logStream) if logStream?
      if process.env.JANKY_SHA1
        grim = require 'grim'

        if grim.getDeprecationsLength() > 0
          grim.logDeprecations()
          return atom.exit(1)

      if runner.results().failedCount > 0
        atom.exit(1)
      else
        atom.exit(0)
