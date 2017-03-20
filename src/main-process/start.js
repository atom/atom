const {app} = require('electron')
const nslog = require('nslog')
const path = require('path')
const temp = require('temp')
const parseCommandLine = require('./parse-command-line')
const startCrashReporter = require('../crash-reporter-start')
const atomPaths = require('../atom-paths')

module.exports = function start (resourcePath, startTime) {
  global.shellStartTime = startTime

  process.on('uncaughtException', function (error = {}) {
    if (error.message != null) {
      console.log(error.message)
    }

    if (error.stack != null) {
      console.log(error.stack)
    }
  })

  const previousConsoleLog = console.log
  console.log = nslog

  const args = parseCommandLine(process.argv.slice(1))
  atomPaths.setAtomHome(app.getPath('home'))
  atomPaths.setUserData()
  setupCompileCache()

  if (handleStartupEventWithSquirrel()) {
    return
  } else if (args.test && args.mainProcess) {
    app.setPath('userData', temp.mkdirSync('atom-user-data-dir-for-main-process-tests'))
    console.log = previousConsoleLog
    app.on('ready', function () {
      const testRunner = require(path.join(args.resourcePath, 'spec/main-process/mocha-test-runner'))
      testRunner(args.pathsToOpen)
    })
    return
  }

  // NB: This prevents Win10 from showing dupe items in the taskbar
  app.setAppUserModelId('com.squirrel.atom.' + process.arch)

  function addPathToOpen (event, pathToOpen) {
    event.preventDefault()
    args.pathsToOpen.push(pathToOpen)
  }

  function addUrlToOpen (event, urlToOpen) {
    event.preventDefault()
    args.urlsToOpen.push(urlToOpen)
  }

  app.on('open-file', addPathToOpen)
  app.on('open-url', addUrlToOpen)
  app.on('will-finish-launching', startCrashReporter)

  if (args.userDataDir != null) {
    app.setPath('userData', args.userDataDir)
  } else if (args.test || args.benchmark || args.benchmarkTest) {
    app.setPath('userData', temp.mkdirSync('atom-test-data'))
  }

  app.on('ready', function () {
    app.removeListener('open-file', addPathToOpen)
    app.removeListener('open-url', addUrlToOpen)
    const AtomApplication = require(path.join(args.resourcePath, 'src', 'main-process', 'atom-application'))
    AtomApplication.open(args)
  })
}

function handleStartupEventWithSquirrel () {
  if (process.platform !== 'win32') {
    return false
  }

  const SquirrelUpdate = require('./squirrel-update')
  const squirrelCommand = process.argv[1]
  return SquirrelUpdate.handleStartupEvent(app, squirrelCommand)
}

function setupCompileCache () {
  const CompileCache = require('../compile-cache')
  CompileCache.setAtomHomeDirectory(process.env.ATOM_HOME)
  CompileCache.install(process.resourcesPath, require)
}
