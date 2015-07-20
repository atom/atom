global.shellStartTime = Date.now()

crashReporter = require 'crash-reporter'
app = require 'app'
fs = require 'fs-plus'
path = require 'path'
yargs = require 'yargs'
url = require 'url'
nslog = require 'nslog'

console.log = nslog

process.on 'uncaughtException', (error={}) ->
  nslog(error.message) if error.message?
  nslog(error.stack) if error.stack?

start = ->
  setupAtomHome()
  setupCoffeeCache()

  if process.platform is 'win32'
    SquirrelUpdate = require './squirrel-update'
    squirrelCommand = process.argv[1]
    return if SquirrelUpdate.handleStartupEvent(app, squirrelCommand)

  args = parseCommandLine()

  addPathToOpen = (event, pathToOpen) ->
    event.preventDefault()
    args.pathsToOpen.push(pathToOpen)

  args.urlsToOpen = []
  addUrlToOpen = (event, urlToOpen) ->
    event.preventDefault()
    args.urlsToOpen.push(urlToOpen)

  app.on 'open-file', addPathToOpen
  app.on 'open-url', addUrlToOpen

  app.on 'will-finish-launching', ->
    setupCrashReporter()

  app.on 'ready', ->
    app.removeListener 'open-file', addPathToOpen
    app.removeListener 'open-url', addUrlToOpen

    cwd = args.executedFrom?.toString() or process.cwd()
    args.pathsToOpen = args.pathsToOpen.map (pathToOpen) ->
      normalizedPath = fs.normalize(pathToOpen)
      if url.parse(pathToOpen).protocol?
        pathToOpen
      else if cwd
        path.resolve(cwd, normalizedPath)
      else
        path.resolve(pathToOpen)

    if args.devMode
      AtomApplication = require path.join(args.resourcePath, 'src', 'browser', 'atom-application')
    else
      AtomApplication = require './atom-application'

    AtomApplication.open(args)
    console.log("App load time: #{Date.now() - global.shellStartTime}ms") unless args.test

global.devResourcePath = process.env.ATOM_DEV_RESOURCE_PATH ? path.join(app.getHomeDir(), 'github', 'atom')
# Normalize to make sure drive letter case is consistent on Windows
global.devResourcePath = path.normalize(global.devResourcePath) if global.devResourcePath

setupCrashReporter = ->
  crashReporter.start(productName: 'Atom', companyName: 'GitHub')

setupAtomHome = ->
  return if process.env.ATOM_HOME

  atomHome = path.join(app.getHomeDir(), '.atom')
  try
    atomHome = fs.realpathSync(atomHome)
  process.env.ATOM_HOME = atomHome

setupCoffeeCache = ->
  CoffeeCache = require 'coffee-cash'
  cacheDir = path.join(process.env.ATOM_HOME, 'compile-cache')
  # Use separate compile cache when sudo'ing as root to avoid permission issues
  if process.env.USER is 'root' and process.env.SUDO_USER and process.env.SUDO_USER isnt process.env.USER
    cacheDir = path.join(cacheDir, 'root')
  CoffeeCache.setCacheDirectory(path.join(cacheDir, 'coffee'))
  CoffeeCache.register()

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

  executedFrom = args['executed-from']
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
      resourcePath ?= global.devResourcePath

  unless fs.statSyncNoException(resourcePath)
    resourcePath = path.dirname(path.dirname(__dirname))

  # On Yosemite the $PATH is not inherited by the "open" command, so we have to
  # explicitly pass it by command line, see http://git.io/YC8_Ew.
  process.env.PATH = args['path-environment'] if args['path-environment']

  {resourcePath, pathsToOpen, executedFrom, test, version, pidToKillWhenClosed,
   devMode, safeMode, newWindow, specDirectory, logFile, socketPath, profileStartup}

start()
