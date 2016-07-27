global.shellStartTime = Date.now()

process.on('uncaughtException', function (error = {}) {
  if (error.message != null) {
    console.log(error.message)
  }

  if (error.stack != null) {
    console.log(error.stack)
  }
})

const {app} = require('electron')
const fs = require('fs-plus')
const path = require('path')
const temp = require('temp')
const yargs = require('yargs')
const dedent = require('dedent')
const previousConsoleLog = console.log
console.log = require('nslog')

function start () {
  const args = parseCommandLine()
  args.env = process.env
  setupAtomHome(args)
  setupCompileCache()

  if (handleStartupEventWithSquirrel()) {
    return
  } else if (args.test && args.mainProcess) {
    console.log = previousConsoleLog
    app.on('ready', function () {
      const testRunner = require(path.join(args.resourcePath, 'spec/main-process/mocha-test-runner'))
      testRunner(args.pathsToOpen)
    })
    return
  }

  app.setAppUserModelId('com.squirrel.atom.atom')

  const startCrashReporter = require('../crash-reporter-start')
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
  } else if (args.test) {
    app.setPath('userData', temp.mkdirSync('atom-test-data'))
  }

  app.on('ready', function () {
    app.removeListener('open-file', addPathToOpen)
    app.removeListener('open-url', addUrlToOpen)
    const AtomApplication = require(path.join(args.resourcePath, 'src', 'main-process', 'atom-application'))
    AtomApplication.open(args)

    if (!args.test) {
      console.log(`App load time: ${Date.now() - global.shellStartTime}ms`)
    }
  })
}

function normalizeDriveLetterName (filePath) {
  if (process.platform === 'win32') {
    return filePath.replace(/^([a-z]):/, ([driveLetter]) => driveLetter.toUpperCase() + ':')
  } else {
    return filePath
  }
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
  } finally {
    process.env.ATOM_HOME = atomHome
  }
}

function setupCompileCache () {
  const CompileCache = require('../compile-cache')
  CompileCache.setAtomHomeDirectory(process.env.ATOM_HOME)
}

function writeFullVersion () {
  process.stdout.write(
    `Atom    : ${app.getVersion()}\n` +
    `Electron: ${process.versions.electron}\n` +
    `Chrome  : ${process.versions.chrome}\n` +
    `Node    : ${process.versions.node}\n`
  )
}

function parseCommandLine () {
  const options = yargs(process.argv.slice(1)).wrap(100)
  const version = app.getVersion()
  options.usage(
    dedent`Atom Editor v${version}

    Usage: atom [options] [path ...]

    One or more paths to files or folders may be specified. If there is an
    existing Atom window that contains all of the given folders, the paths
    will be opened in that window. Otherwise, they will be opened in a new
    window.

    Environment Variables:

      ATOM_DEV_RESOURCE_PATH  The path from which Atom loads source code in dev mode.
                              Defaults to \`~/github/atom\`.

      ATOM_HOME               The root path for all configuration files and folders.
                              Defaults to \`~/.atom\`.`
  )
  options.alias('1', 'one').boolean('1').describe('1', 'This option is no longer supported.')
  options.boolean('include-deprecated-apis').describe('include-deprecated-apis', 'This option is not currently supported.')
  options.alias('d', 'dev').boolean('d').describe('d', 'Run in development mode.')
  options.alias('f', 'foreground').boolean('f').describe('f', 'Keep the main process in the foreground.')
  options.alias('h', 'help').boolean('h').describe('h', 'Print this usage message.')
  options.alias('l', 'log-file').string('l').describe('l', 'Log all output to file.')
  options.alias('n', 'new-window').boolean('n').describe('n', 'Open a new window.')
  options.boolean('profile-startup').describe('profile-startup', 'Create a profile of the startup execution time.')
  options.alias('r', 'resource-path').string('r').describe('r', 'Set the path to the Atom source directory and enable dev-mode.')
  options.boolean('safe').describe(
    'safe',
    'Do not load packages from ~/.atom/packages or ~/.atom/dev/packages.'
  )
  options.boolean('portable').describe(
    'portable',
    'Set portable mode. Copies the ~/.atom folder to be a sibling of the installed Atom location if a .atom folder is not already there.'
  )
  options.alias('t', 'test').boolean('t').describe('t', 'Run the specified specs and exit with error code on failures.')
  options.alias('m', 'main-process').boolean('m').describe('m', 'Run the specified specs in the main process.')
  options.string('timeout').describe(
    'timeout',
    'When in test mode, waits until the specified time (in minutes) and kills the process (exit code: 130).'
  )
  options.alias('v', 'version').boolean('v').describe('v', 'Print the version information.')
  options.alias('w', 'wait').boolean('w').describe('w', 'Wait for window to be closed before returning.')
  options.alias('a', 'add').boolean('a').describe('add', 'Open path as a new project in last used window.')
  options.string('socket-path')
  options.string('user-data-dir')
  options.boolean('clear-window-state').describe('clear-window-state', 'Delete all Atom environment state.')

  const args = options.argv

  if (args.help) {
    process.stdout.write(options.help())
    process.exit(0)
  }

  if (args.version) {
    writeFullVersion()
    process.exit(0)
  }

  const addToLastWindow = args['add']
  let devMode = args['dev']
  const safeMode = args['safe']
  const pathsToOpen = args._
  const test = args['test']
  const mainProcess = args['main-process']
  const timeout = args['timeout']
  const newWindow = args['new-window']
  let executedFrom = null
  if (args['executed-from'] && args['executed-from'].toString()) {
    executedFrom = args['executed-from'].toString()
  } else {
    executedFrom = process.cwd()
  }

  let pidToKillWhenClosed = null
  if (args['wait']) {
    pidToKillWhenClosed = args['pid']
  }

  const logFile = args['log-file']
  const socketPath = args['socket-path']
  const userDataDir = args['user-data-dir']
  const profileStartup = args['profile-startup']
  const clearWindowState = args['clear-window-state']
  const urlsToOpen = []
  const setPortable = args.portable
  let devResourcePath = process.env.ATOM_DEV_RESOURCE_PATH || path.join(app.getPath('home'), 'github', 'atom')
  let resourcePath = null

  if (args['resource-path']) {
    devMode = true
    resourcePath = args['resource-path']
  }

  if (test) {
    devMode = true
  }

  if (devMode && !resourcePath) {
    resourcePath = devResourcePath
  }

  if (!fs.statSyncNoException(resourcePath)) {
    resourcePath = path.dirname(path.dirname(__dirname))
  }

  if (args['path-environment']) {
    process.env.PATH = args['path-environment']
  }

  resourcePath = normalizeDriveLetterName(resourcePath)
  devResourcePath = normalizeDriveLetterName(devResourcePath)

  return {
    resourcePath, devResourcePath, pathsToOpen, urlsToOpen, executedFrom, test,
    version, pidToKillWhenClosed, devMode, safeMode, newWindow, logFile, socketPath,
    userDataDir, profileStartup, timeout, setPortable, clearWindowState,
    addToLastWindow, mainProcess
  }
}

start()
