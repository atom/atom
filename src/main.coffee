startTime = new Date().getTime()

autoUpdater = require 'auto-updater'
crashReporter = require 'crash-reporter'
delegate = require 'atom-delegate'
app = require 'app'
fs = require 'fs'
module = require 'module'
path = require 'path'
optimist = require 'optimist'
nslog = require 'nslog'
dialog = require 'dialog'

console.log = (args...) ->
  nslog(args.map((arg) -> JSON.stringify(arg)).join(" "))

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
      require(path.join(args.resourcePath, 'src', 'coffee-cache'))
      module.globalPaths.push(path.join(args.resourcePath, 'src'))
    else
      appSrcPath = path.resolve(process.argv[0], "../../Resources/app/src")
      module.globalPaths.push(appSrcPath)

    AtomApplication = require 'atom-application'

    AtomApplication.open(args)
    console.log("App load time: #{new Date().getTime() - startTime}ms")

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
  options.alias('h', 'help').boolean('h').describe('h', 'Print this usage message.')
  options.alias('n', 'new-window').boolean('n').describe('n', 'Open a new window.')
  options.alias('t', 'test').boolean('t').describe('t', 'Run the Atom specs and exit with error code on failures.')
  options.alias('v', 'version').boolean('v').describe('v', 'Print the version.')
  options.alias('f', 'foreground').boolean('f').describe('f', 'Keep the browser process in the foreground.')
  options.alias('w', 'wait').boolean('w').describe('w', 'Wait for window to be closed before returning.')
  args = options.argv

  if args.h
    process.stdout.write(options.help())
    process.exit(0)

  if args.v
    process.stdout.write("#{version}\n")
    process.exit(0)

  executedFrom = args['executed-from']
  devMode = args['dev']
  pathsToOpen = args._
  pathsToOpen = [executedFrom] if executedFrom and pathsToOpen.length is 0
  test = args['test']
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
    resourcePath = path.dirname(__dirname)

  {resourcePath, pathsToOpen, executedFrom, test, version, pidToKillWhenClosed, devMode, newWindow}
