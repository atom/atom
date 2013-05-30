delegate = require 'atom-delegate'
app = require 'app'
fs = require 'fs'
path = require 'path'
optimist = require 'optimist'
nslog = require 'nslog'
AtomApplication = require './atom-application'

console.log = (args...) ->
  nslog(args.map((arg) -> JSON.stringify(arg)).join(" "))

require 'coffee-script'

delegate.browserMainParts.preMainMessageLoopRun = ->
  commandLineArgs = parseCommandLine()

  addPathToOpen = (event, filePath) ->
    event.preventDefault()
    commandLineArgs.pathsToOpen ?= []
    commandLineArgs.pathsToOpen.push(filePath)

  app.on 'open-file', addPathToOpen
  app.on 'finish-launching', ->
    app.removeListener 'open-file', addPathToOpen
    AtomApplication.open(commandLineArgs)

getHomeDir = ->
  process.env[if process.platform is 'win32' then 'USERPROFILE' else 'HOME']

parseCommandLine = ->
  version = fs.readFileSync(path.join(__dirname, '..', '..', 'version'), 'utf8')

  options = optimist(process.argv[1..])
  options.usage """
    Atom #{version}

    Usage: atom [options] [file ..]
  """
  options.alias('d', 'dev').boolean('d').describe('d', 'Run in development mode.')
  options.alias('h', 'help').boolean('h').describe('h', 'Print this usage message.')
  options.alias('t', 'test').boolean('t').describe('t', 'Run the Atom specs and exit with error code on failures.')
  options.alias('w', 'wait').boolean('w').describe('w', 'Wait for window to be closed before returning.')
  args = options.argv
  if args.h
    options.showHelp()
    process.exit(0)

  executedFrom = args['executed-from']
  pathsToOpen = if args._.length > 0 then args._ else null
  pathsToOpen ?= [executedFrom] if executedFrom
  pathsToOpen = pathsToOpen?.map (pathToOpen) ->
    path.resolve(executedFrom ? process.cwd(), pathToOpen)
  test = args['test']
  pidToKillWhenClosed = args['pid'] if args['wait']

  if args['resource-path']
    resourcePath = args['resource-path']
  else if args['dev']
    resourcePath = path.join(getHomeDir(), 'github', 'atom')

  try
    fs.statSync resourcePath
  catch e
    resourcePath = path.dirname(__dirname)

  {resourcePath, pathsToOpen, test, version, pidToKillWhenClosed}
