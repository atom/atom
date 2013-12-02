startTime = Date.now()

autoUpdater = require 'auto-updater'
crashReporter = require 'crash-reporter'
delegate = require 'atom-delegate'
app = require 'app'
fs = require 'fs'
module = require 'module'
path = require 'path'
optimist = require 'optimist'
# TODO: NSLog is missing .lib on windows
nslog = require 'nslog' unless process.platform is 'win32'
dialog = require 'dialog'

console.log = (args...) ->
  # TODO: Make NSLog work as expected
  output = args.map((arg) -> JSON.stringify(arg)).join(" ")
  if process.platform == 'darwin'
    nslog(output)
  else
    fs.writeFileSync('debug.log', output, flag: 'a')

process.on 'uncaughtException', (error={}) ->
  nslog(error.message) if error.message?
  nslog(error.stack) if error.stack?

delegate.browserMainParts.preMainMessageLoopRun = ->
  args = parseCommandLine()

  addPathToOpen = (event, pathToOpen) ->
    event.preventDefault()
    args.pathsToOpen.push(pathToOpen)

  args.urlsToOpen = []
  addUrlToOpen = (event, urlToOpen) ->
    event.preventDefault()
    args.urlsToOpen.push(urlToOpen)

  app.on 'open-url', (event, urlToOpen) ->
    event.preventDefault()
    args.urlsToOpen.push(urlToOpen)

  app.on 'open-file', addPathToOpen
  app.on 'open-url', addUrlToOpen

  app.on 'will-finish-launching', ->
    setupCrashReporter()
    setupAutoUpdater()

  app.on 'finish-launching', ->
    app.removeListener 'open-file', addPathToOpen
    app.removeListener 'open-url', addUrlToOpen

    args.pathsToOpen = args.pathsToOpen.map (pathToOpen) ->
      path.resolve(args.executedFrom ? process.cwd(), pathToOpen)

    require('coffee-script')
    if args.devMode
      require(path.join(args.resourcePath, 'src', 'coffee-cache')).register()
      AtomApplication = require path.join(args.resourcePath, 'src', 'browser', 'atom-application')
    else
      AtomApplication = require './atom-application'

    AtomApplication.open(args)
    console.log("App load time: #{Date.now() - startTime}ms") unless args.test

global.devResourcePath = path.join(app.getHomeDir(), 'github', 'atom')

setupCrashReporter = ->
  crashReporter.setCompanyName 'GitHub'
  crashReporter.setSubmissionUrl 'https://speakeasy.githubapp.com/submit_crash_log'
  crashReporter.setAutoSubmit true

setupAutoUpdater = ->
  autoUpdater.setFeedUrl 'https://speakeasy.githubapp.com/apps/27/appcast.xml'

parseCommandLine = ->
  version = app.getVersion()
  options = optimist(process.argv[1..])
  options.usage """
    Atom #{version}

    Usage: atom [options] [file ...]
  """
  options.alias('d', 'dev').boolean('d').describe('d', 'Run in development mode.')
  options.alias('f', 'foreground').boolean('f').describe('f', 'Keep the browser process in the foreground.')
  options.alias('h', 'help').boolean('h').describe('h', 'Print this usage message.')
  options.alias('n', 'new-window').boolean('n').describe('n', 'Open a new window.')
  options.alias('s', 'spec-directory').string('s').describe('s', 'Set the directory from which specs are loaded (default: Atom\'s spec directory).')
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
  pathsToOpen = args._
  pathsToOpen = [executedFrom] if executedFrom and pathsToOpen.length is 0
  test = args['test']
  specDirectory = args['spec-directory']
  newWindow = args['new-window']
  pidToKillWhenClosed = args['pid'] if args['wait']

  if args['resource-path']
    devMode = true
    resourcePath = args['resource-path']
  else if devMode
    resourcePath = global.devResourcePath

  try
    fs.statSync resourcePath
  catch e
    devMode = false
    resourcePath = path.dirname(path.dirname(__dirname))

  {resourcePath, pathsToOpen, executedFrom, test, version, pidToKillWhenClosed, devMode, newWindow, specDirectory}
