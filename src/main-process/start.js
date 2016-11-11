const {app} = require('electron')
const fs = require('fs-plus')
const nslog = require('nslog')
const path = require('path')
const temp = require('temp')
const parseCommandLine = require('./parse-command-line')
const startCrashReporter = require('../crash-reporter-start')

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
  setupAtomHome(args)
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

function setupAtomHome ({setPortable}) {
  if (process.env.ATOM_HOME) {
    return
  }

  let atomHome = path.join(app.getPath('home'), '.atom')
  const AtomPortable = require('./atom-portable')

  if (setPortable && !AtomPortable.isPortableInstall(process.platform, process.env.ATOM_HOME, atomHome)) {
    try {
      AtomPortable.setPortable(atomHome)
    } catch (error) {
      console.log(`Failed copying portable directory '${atomHome}' to '${AtomPortable.getPortableAtomHomePath()}'`)
      console.log(`${error.message} ${error.stack}`)
    }
  }

  if (AtomPortable.isPortableInstall(process.platform, process.env.ATOM_HOME, atomHome)) {
    atomHome = AtomPortable.getPortableAtomHomePath()
  }

  try {
    atomHome = fs.realpathSync(atomHome)
  } catch (e) {
    // Don't throw an error if atomHome doesn't exist.
  }

  process.env.ATOM_HOME = atomHome
}

function setupCompileCache () {
  const CompileCache = require('../compile-cache')
  CompileCache.setAtomHomeDirectory(process.env.ATOM_HOME)
}
