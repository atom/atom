global.shellStartTime = Date.now()

crashReporter = require 'crash-reporter'
app = require 'app'
fs = require 'fs'
module = require 'module'
path = require 'path'
optimist = require 'optimist'
nslog = require 'nslog'
dialog = require 'dialog'

console.log = nslog

process.on 'uncaughtException', (error={}) ->
  nslog(error.message) if error.message?
  nslog(error.stack) if error.stack?

start = ->
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

  app.on 'finish-launching', ->
    app.removeListener 'open-file', addPathToOpen
    app.removeListener 'open-url', addUrlToOpen

    args.pathsToOpen = args.pathsToOpen.map (pathToOpen) ->
      path.resolve(args.executedFrom ? process.cwd(), pathToOpen.toString())

    require('coffee-script').register()
    if args.devMode
      require(path.join(args.resourcePath, 'src', 'coffee-cache')).register()
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

parseCommandLine = ->
  version = app.getVersion()
  options = optimist(process.argv[1..])
  options.usage """
    Atom Editor v#{version}

    Usage: atom [options] [path ...]

    One or more paths to files or folders to open may be specified.

    File paths will open in the current window.

    Folder paths will open in an existing window if that folder has already been
    opened or a new window if it hasn't.
  """
  options.alias('d', 'dev').boolean('d').describe('d', 'Run in development mode.')
  options.alias('f', 'foreground').boolean('f').describe('f', 'Keep the browser process in the foreground.')
  options.alias('h', 'help').boolean('h').describe('h', 'Print this usage message.')
  options.alias('l', 'log-file').string('l').describe('l', 'Log all output to file.')
  options.alias('n', 'new-window').boolean('n').describe('n', 'Open a new window.')
  options.alias('s', 'spec-directory').string('s').describe('s', 'Set the spec directory (default: Atom\'s spec directory).')
  options.boolean('safe').describe('safe', 'Do not load packages from ~/.atom/packages or ~/.atom/dev/packages.')
  options.alias('t', 'test').boolean('t').describe('t', 'Run the specified specs and exit with error code on failures.')
  options.alias('v', 'version').boolean('v').describe('v', 'Print the version.')
  options.alias('w', 'wait').boolean('w').describe('w', 'Wait for window to be closed before returning.')
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
  pathsToOpen = [executedFrom] if executedFrom and pathsToOpen.length is 0
  test = args['test']
  specDirectory = args['spec-directory']
  newWindow = args['new-window']
  pidToKillWhenClosed = args['pid'] if args['wait']
  logFile = args['log-file']

  if args['resource-path']
    devMode = true
    resourcePath = args['resource-path']
  else if devMode
    resourcePath = global.devResourcePath

  try
    fs.statSync resourcePath
  catch
    resourcePath = path.dirname(path.dirname(__dirname))

  {resourcePath, pathsToOpen, executedFrom, test, version, pidToKillWhenClosed, devMode, safeMode, newWindow, specDirectory, logFile}

start()
