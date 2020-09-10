Grim = require 'grim'
fs = require 'fs-plus'
temp = require 'temp'
path = require 'path'
{ipcRenderer} = require 'electron'

temp.track()

module.exports = ({logFile, headless, testPaths, buildAtomEnvironment}) ->
  window[key] = value for key, value of require '../vendor/jasmine'

  require 'jasmine-tagged'

  # Rewrite global jasmine functions to have support for async tests.
  # This way packages can create async specs without having to import these from the
  # async-spec-helpers file.
  global.it = asyncifyJasmineFn global.it, 1
  global.fit = asyncifyJasmineFn global.fit, 1
  global.ffit = asyncifyJasmineFn global.ffit, 1
  global.fffit = asyncifyJasmineFn global.fffit, 1
  global.beforeEach = asyncifyJasmineFn global.beforeEach, 0
  global.afterEach = asyncifyJasmineFn global.afterEach, 0

  # Allow document.title to be assigned in specs without screwing up spec window title
  documentTitle = null
  Object.defineProperty document, 'title',
    get: -> documentTitle
    set: (title) -> documentTitle = title

  userHome = process.env.ATOM_HOME or path.join(fs.getHomeDirectory(), '.atom')
  atomHome = temp.mkdirSync prefix: 'atom-test-home-'
  if process.env.APM_TEST_PACKAGES
    testPackages = process.env.APM_TEST_PACKAGES.split /\s+/
    fs.makeTreeSync path.join(atomHome, 'packages')
    for packName in testPackages
      userPack = path.join(userHome, 'packages', packName)
      loadablePack = path.join(atomHome, 'packages', packName)

      try
        fs.symlinkSync userPack, loadablePack, 'dir'
      catch
        fs.copySync userPack, loadablePack

  ApplicationDelegate = require '../src/application-delegate'
  applicationDelegate = new ApplicationDelegate()
  applicationDelegate.setRepresentedFilename = ->
  applicationDelegate.setWindowDocumentEdited = ->
  window.atom = buildAtomEnvironment({
    applicationDelegate, window, document,
    configDirPath: atomHome
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

  if process.env.TEST_JUNIT_XML_PATH
    {JasmineJUnitReporter} = require './jasmine-junit-reporter'
    process.stdout.write "Outputting JUnit XML to <#{process.env.TEST_JUNIT_XML_PATH}>\n"
    outputDir = path.dirname(process.env.TEST_JUNIT_XML_PATH)
    fileBase = path.basename(process.env.TEST_JUNIT_XML_PATH, '.xml')

    jasmineEnv.addReporter new JasmineJUnitReporter(outputDir, true, false, fileBase, true)

  jasmineEnv.setIncludedTags([process.platform])

  jasmineContent = document.createElement('div')
  jasmineContent.setAttribute('id', 'jasmine-content')

  document.body.appendChild(jasmineContent)

  jasmineEnv.execute()
  promise

asyncifyJasmineFn = (fn, callbackPosition) ->
  (args...) ->
    if typeof args[callbackPosition] is 'function'
      callback = args[callbackPosition]

      args[callbackPosition] = (args...) ->
        result = callback.apply this, args
        if result instanceof Promise
          waitsForPromise(-> result)

    fn.apply this, args

waitsForPromise = (fn) ->
  promise = fn()

  global.waitsFor('spec promise to resolve', (done) ->
    promise.then(done, (error) ->
      jasmine.getEnv().currentSpec.fail error
      done()
    )
  )

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
      ipcRenderer.send 'write-to-stderr', str

  options =
    print: (str) ->
      log(str)
    onComplete: (runner) ->
      fs.closeSync(logStream) if logStream?
      if Grim.getDeprecationsLength() > 0
        Grim.logDeprecations()
        resolveWithExitCode(1)
        return

      if runner.results().failedCount > 0
        resolveWithExitCode(1)
      else
        resolveWithExitCode(0)

  if process.env.ATOM_JASMINE_REPORTER is 'list'
    {JasmineListReporter} = require './jasmine-list-reporter'
    new JasmineListReporter(options)
  else
    {TerminalReporter} = require 'jasmine-tagged'
    new TerminalReporter(options)
