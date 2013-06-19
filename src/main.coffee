AtomApplication = require './atom-application'
autoUpdater = require 'auto-updater'
crashReporter = require 'crash-reporter'
delegate = require 'atom-delegate'
app = require 'app'
fs = require 'fs'
path = require 'path'
optimist = require 'optimist'
nslog = require 'nslog'
_ = require 'underscore'

console.log = (args...) ->
  nslog(args.map((arg) -> JSON.stringify(arg)).join(" "))

require 'coffee-script'

delegate.browserMainParts.preMainMessageLoopRun = ->
  args = parseCommandLine()

  addPathToOpen = (event, filePath) ->
    event.preventDefault()
    args.pathsToOpen.push(filePath)

  app.on 'open-file', addPathToOpen

  app.on 'will-finish-launching', ->
    setupCrashReporter()
    setupAutoUpdater()

  app.on 'finish-launching', ->
    app.removeListener 'open-file', addPathToOpen

    args.pathsToOpen = args.pathsToOpen.map (pathToOpen) ->
      path.resolve(args.executedFrom ? process.cwd(), pathToOpen)

    AtomApplication.open(args)

setupCrashReporter = ->
  crashReporter.setCompanyName 'GitHub'
  crashReporter.setSubmissionUrl 'https://speakeasy.githubapp.com/submit_crash_log'
  crashReporter.setAutoSubmit true

setupAutoUpdater = ->
  autoUpdater.setAutomaticallyChecksForUpdates false
  autoUpdater.setAutomaticallyDownloadsUpdates true

parseCommandLine = ->
  version = app.getVersion()
  options = optimist(process.argv[1..])
  options.usage """
    Atom #{version}

    Usage: atom [options] [file ..]
  """
  options.alias('d', 'dev').boolean('d').describe('d', 'Run in development mode.')
  options.alias('h', 'help').boolean('h').describe('h', 'Print this usage message.')
  options.alias('n', 'new-window').boolean('n').describe('n', 'Open a new window.')
  options.alias('t', 'test').boolean('t').describe('t', 'Run the Atom specs and exit with error code on failures.')
  options.alias('v', 'version').boolean('v').describe('v', 'Print the version.')
  options.alias('w', 'wait').boolean('w').describe('w', 'Wait for window to be closed before returning.')
  args = options.argv

  if args.h
    process.stdout.write(options.help())
    process.exit(0)

  if args.v
    process.stdout.write("#{version}\n")
    process.exit(0)

  executedFrom = args['executed-from']
  dev = args['dev']
  pathsToOpen = args._
  pathsToOpen = [executedFrom] if executedFrom and pathsToOpen.length is 0
  test = args['test']
  newWindow = args['new-window']
  pidToKillWhenClosed = args['pid'] if args['wait']

  if args['resource-path']
    dev = true
    resourcePath = args['resource-path']
  else if dev
    resourcePath = path.join(app.getHomeDir(), 'github', 'atom')

  try
    fs.statSync resourcePath
  catch e
    dev = false
    resourcePath = path.dirname(__dirname)

  {resourcePath, pathsToOpen, executedFrom, test, version, pidToKillWhenClosed, dev, newWindow}
