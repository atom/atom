global.shellStartTime = Date.now()

process.on 'uncaughtException', (error={}) ->
  console.log(error.message) if error.message?
  console.log(error.stack) if error.stack?

crashReporter = require 'crash-reporter'
app = require 'app'
fs = require 'fs-plus'
path = require 'path'
yargs = require 'yargs'
console.log = require 'nslog'

start = ->
  setupAtomHome()
  setupCompileCache()
  return if handleStartupEventWithSquirrel()

    # NB: This prevents Win10 from showing dupe items in the taskbar
    app.setAppUserModelId('com.squirrel.atom.atom')

  args = parseCommandLine()

  addPathToOpen = (event, pathToOpen) ->
    event.preventDefault()
    args.pathsToOpen.push(pathToOpen)

  addUrlToOpen = (event, urlToOpen) ->
    event.preventDefault()
    args.urlsToOpen.push(urlToOpen)

  app.on 'open-file', addPathToOpen
  app.on 'open-url', addUrlToOpen
  app.on 'will-finish-launching', setupCrashReporter

  app.on 'ready', ->
    app.removeListener 'open-file', addPathToOpen
    app.removeListener 'open-url', addUrlToOpen

    AtomApplication = require path.join(args.resourcePath, 'src', 'browser', 'atom-application')
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
  crashReporter.start(productName: 'Atom', companyName: 'GitHub')

setupAtomHome = ->
  return if process.env.ATOM_HOME
  atomHome = path.join(app.getHomeDir(), '.atom')
  try
    atomHome = fs.realpathSync(atomHome)
  process.env.ATOM_HOME = atomHome

setupCompileCache = ->
  compileCache = require('../compile-cache')
  compileCache.setAtomHomeDirectory(process.env.ATOM_HOME)

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
  options.alias('f', 'foreground').boolean('f').describe('f', 'Keep the browser process in the foreground.')
  options.alias('h', 'help').boolean('h').describe('h', 'Print this usage message.')
  options.alias('l', 'log-file').string('l').describe('l', 'Log all output to file.')
  options.alias('n', 'new-window').boolean('n').describe('n', 'Open a new window.')
  options.boolean('profile-startup').describe('profile-startup', 'Create a profile of the startup execution time.')
  options.alias('r', 'resource-path').string('r').describe('r', 'Set the path to the Atom source directory and enable dev-mode.')
  options.alias('s', 'spec-directory').string('s').describe('s', 'Set the directory from which to run package specs (default: Atom\'s spec directory).')
  options.boolean('safe').describe('safe', 'Do not load packages from ~/.atom/packages or ~/.atom/dev/packages.')
  options.alias('t', 'test').boolean('t').describe('t', 'Run the specified specs and exit with error code on failures.')
  options.alias('v', 'version').boolean('v').describe('v', 'Print the version.')
  options.alias('w', 'wait').boolean('w').describe('w', 'Wait for window to be closed before returning.')
  options.string('socket-path')

  args = options.argv

  if args.help
    process.stdout.write(options.help())
    process.exit(0)

  if args.version
    process.stdout.write("#{version}\n")
    process.exit(0)

  executedFrom = args['executed-from']?.toString() ? process.cwd()
  devMode = args['dev']
  safeMode = args['safe']
  pathsToOpen = args._
  test = args['test']
  specDirectory = args['spec-directory']
  newWindow = args['new-window']
  pidToKillWhenClosed = args['pid'] if args['wait']
  logFile = args['log-file']
  socketPath = args['socket-path']
  profileStartup = args['profile-startup']
  urlsToOpen = []
  devResourcePath = process.env.ATOM_DEV_RESOURCE_PATH ? path.join(app.getHomeDir(), 'github', 'atom')

  if args['resource-path']
    devMode = true
    resourcePath = args['resource-path']
  else
    # Set resourcePath based on the specDirectory if running specs on atom core
    if specDirectory?
      packageDirectoryPath = path.join(specDirectory, '..')
      packageManifestPath = path.join(packageDirectoryPath, 'package.json')
      if fs.statSyncNoException(packageManifestPath)
        try
          packageManifest = JSON.parse(fs.readFileSync(packageManifestPath))
          resourcePath = packageDirectoryPath if packageManifest.name is 'atom'

    if devMode
      resourcePath ?= devResourcePath

  unless fs.statSyncNoException(resourcePath)
    resourcePath = path.dirname(path.dirname(__dirname))

  # On Yosemite the $PATH is not inherited by the "open" command, so we have to
  # explicitly pass it by command line, see http://git.io/YC8_Ew.
  process.env.PATH = args['path-environment'] if args['path-environment']

  resourcePath = normalizeDriveLetterName(resourcePath)
  devResourcePath = normalizeDriveLetterName(devResourcePath)

  {resourcePath, devResourcePath, pathsToOpen, urlsToOpen, executedFrom, test,
   version, pidToKillWhenClosed, devMode, safeMode, newWindow, specDirectory,
   logFile, socketPath, profileStartup}

start()
