global.shellStartTime = Date.now()

process.on 'uncaughtException', (error={}) ->
  console.log(error.message) if error.message?
  console.log(error.stack) if error.stack?

{crashReporter, app} = require 'electron'
fs = require 'fs-plus'
path = require 'path'
temp = require 'temp'
yargs = require 'yargs'
previousConsoleLog = console.log
console.log = require 'nslog'

start = ->
  args = parseCommandLine()
  args.env = Object.assign({}, process.env)
  setupAtomHome(args)
  setupNodePath(args)
  setupCompileCache()
  if handleStartupEventWithSquirrel()
    return
  else if args.test and args.mainProcess
    console.log = previousConsoleLog
    testRunner = require(path.join(args.resourcePath, 'spec/main-process/mocha-test-runner'))
    app.on 'ready', -> testRunner(args.pathsToOpen)
    return

  # NB: This prevents Win10 from showing dupe items in the taskbar
  app.setAppUserModelId('com.squirrel.atom.atom')

  addPathToOpen = (event, pathToOpen) ->
    event.preventDefault()
    args.pathsToOpen.push(pathToOpen)

  addUrlToOpen = (event, urlToOpen) ->
    event.preventDefault()
    args.urlsToOpen.push(urlToOpen)

  app.on 'open-file', addPathToOpen
  app.on 'open-url', addUrlToOpen
  app.on 'will-finish-launching', setupCrashReporter

  if args.userDataDir?
    app.setPath('userData', args.userDataDir)
  else if args.test
    app.setPath('userData', temp.mkdirSync('atom-test-data'))

  app.on 'ready', ->
    app.removeListener 'open-file', addPathToOpen
    app.removeListener 'open-url', addUrlToOpen

    AtomApplication = require path.join(args.resourcePath, 'src', 'main-process', 'atom-application')
    AtomApplication.open(args)

    console.log("App load time: #{Date.now() - global.shellStartTime}ms") unless args.test

normalizeDriveLetterName = (filePath) ->
  if process.platform is 'win32'
    filePath.replace /^([a-z]):/, ([driveLetter]) -> driveLetter.toUpperCase() + ":"
  else
    filePath

handleStartupEventWithSquirrel = ->
  return false unless process.platform is 'win32'
  SquirrelUpdate = require './squirrel-update'
  squirrelCommand = process.argv[1]
  SquirrelUpdate.handleStartupEvent(app, squirrelCommand)

setupCrashReporter = ->
  crashReporter.start(productName: 'Atom', companyName: 'GitHub', submitURL: 'http://54.249.141.255:1127/post')

setupAtomHome = ({env, setPortable}) ->
  return if process.env.ATOM_HOME

  atomHome = path.join(app.getPath('home'), '.atom')
  AtomPortable = require './atom-portable'

  if setPortable and not AtomPortable.isPortableInstall(process.platform, process.env.ATOM_HOME, atomHome)
    try
      AtomPortable.setPortable(atomHome)
    catch error
      console.log("Failed copying portable directory '#{atomHome}' to '#{AtomPortable.getPortableAtomHomePath()}'")
      console.log("#{error.message} #{error.stack}")

  if AtomPortable.isPortableInstall(process.platform, process.env.ATOM_HOME, atomHome)
    atomHome = AtomPortable.getPortableAtomHomePath()

  try
    atomHome = fs.realpathSync(atomHome)

  process.env.ATOM_HOME = env.ATOM_HOME = atomHome

setupNodePath = ({env, resourcePath}) ->
  # Add application-specific exports to module search path.
  exportsPath = path.join(resourcePath, 'exports')
  env.NODE_PATH = exportsPath

setupCompileCache = ->
  compileCache = require('../compile-cache')
  compileCache.setAtomHomeDirectory(process.env.ATOM_HOME)

writeFullVersion = ->
  process.stdout.write """
    Atom    : #{app.getVersion()}
    Electron: #{process.versions.electron}
    Chrome  : #{process.versions.chrome}
    Node    : #{process.versions.node}

  """

parseCommandLine = ->
  version = app.getVersion()
  options = yargs(process.argv[1..]).wrap(100)
  options.usage """
    Atom Editor v#{version}

    Usage: atom [options] [path ...]

    One or more paths to files or folders may be specified. If there is an
    existing Atom window that contains all of the given folders, the paths
    will be opened in that window. Otherwise, they will be opened in a new
    window.

    Environment Variables:

      ATOM_DEV_RESOURCE_PATH  The path from which Atom loads source code in dev mode.
                              Defaults to `~/github/atom`.

      ATOM_HOME               The root path for all configuration files and folders.
                              Defaults to `~/.atom`.
  """
  # Deprecated 1.0 API preview flag
  options.alias('1', 'one').boolean('1').describe('1', 'This option is no longer supported.')
  options.boolean('include-deprecated-apis').describe('include-deprecated-apis', 'This option is not currently supported.')
  options.alias('d', 'dev').boolean('d').describe('d', 'Run in development mode.')
  options.alias('f', 'foreground').boolean('f').describe('f', 'Keep the main process in the foreground.')
  options.alias('h', 'help').boolean('h').describe('h', 'Print this usage message.')
  options.alias('l', 'log-file').string('l').describe('l', 'Log all output to file.')
  options.alias('n', 'new-window').boolean('n').describe('n', 'Open a new window.')
  options.boolean('profile-startup').describe('profile-startup', 'Create a profile of the startup execution time.')
  options.alias('r', 'resource-path').string('r').describe('r', 'Set the path to the Atom source directory and enable dev-mode.')
  options.boolean('safe').describe('safe', 'Do not load packages from ~/.atom/packages or ~/.atom/dev/packages.')
  options.boolean('portable').describe('portable', 'Set portable mode. Copies the ~/.atom folder to be a sibling of the installed Atom location if a .atom folder is not already there.')
  options.alias('t', 'test').boolean('t').describe('t', 'Run the specified specs and exit with error code on failures.')
  options.alias('m', 'main-process').boolean('m').describe('m', 'Run the specified specs in the main process.')
  options.string('timeout').describe('timeout', 'When in test mode, waits until the specified time (in minutes) and kills the process (exit code: 130).')
  options.alias('v', 'version').boolean('v').describe('v', 'Print the version information.')
  options.alias('w', 'wait').boolean('w').describe('w', 'Wait for window to be closed before returning.')
  options.alias('a', 'add').boolean('a').describe('add', 'Open path as a new project in last used window.')
  options.string('socket-path')
  options.string('user-data-dir')
  options.boolean('clear-window-state').describe('clear-window-state', 'Delete all Atom environment state.')

  args = options.argv

  if args.help
    process.stdout.write(options.help())
    process.exit(0)

  if args.version
    writeFullVersion()
    process.exit(0)

  addToLastWindow = args['add']
  executedFrom = args['executed-from']?.toString() ? process.cwd()
  devMode = args['dev']
  safeMode = args['safe']
  pathsToOpen = args._
  test = args['test']
  mainProcess = args['main-process']
  timeout = args['timeout']
  newWindow = args['new-window']
  pidToKillWhenClosed = args['pid'] if args['wait']
  logFile = args['log-file']
  socketPath = args['socket-path']
  userDataDir = args['user-data-dir']
  profileStartup = args['profile-startup']
  clearWindowState = args['clear-window-state']
  urlsToOpen = []
  devResourcePath = process.env.ATOM_DEV_RESOURCE_PATH ? path.join(app.getPath('home'), 'github', 'atom')
  setPortable = args.portable

  if args['resource-path']
    devMode = true
    resourcePath = args['resource-path']

  devMode = true if test
  resourcePath ?= devResourcePath if devMode

  unless fs.statSyncNoException(resourcePath)
    resourcePath = path.dirname(path.dirname(__dirname))

  # On Yosemite the $PATH is not inherited by the "open" command, so we have to
  # explicitly pass it by command line, see http://git.io/YC8_Ew.
  process.env.PATH = args['path-environment'] if args['path-environment']

  resourcePath = normalizeDriveLetterName(resourcePath)
  devResourcePath = normalizeDriveLetterName(devResourcePath)

  {resourcePath, devResourcePath, pathsToOpen, urlsToOpen, executedFrom, test,
   version, pidToKillWhenClosed, devMode, safeMode, newWindow,
   logFile, socketPath, userDataDir, profileStartup, timeout, setPortable,
   clearWindowState, addToLastWindow, mainProcess}

start()
