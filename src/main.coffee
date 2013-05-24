fs = require 'fs'
path = require 'path'
delegate = require 'atom_delegate'
optimist = require 'optimist'
coffeeScript = require 'coffee-script'

atomApplication = null

delegate.browserMainParts.preMainMessageLoopRun = ->
  commandLineArgs = parseCommandLine()
  require('module').globalPaths.push(path.join(commandLineArgs.resourcePath, "src"))
  AtomApplication = require('atom-application')
  atomApplication = new AtomApplication(commandLineArgs)

getHomeDir = ->
  process.env[if process.platform is 'win32' then 'USERPROFILE' else 'HOME']

parseCommandLine = ->
  args = optimist(process.argv[1..]).argv
  executedFrom = args['executed-from'] ? process.cwd()
  pathsToOpen = args._
  pathsToOpen = [executedFrom] if pathsToOpen.length is 0 and args['executed-from']
  testMode = true if args['test']
  version = String fs.readFileSync(path.join(__dirname, '..', '..', 'version'))

  if args['resource-path']
    resourcePath = args['resource-path']
  else if args['dev']
    resourcePath = path.join(getHomeDir(), 'github/atom')

  try
    fs.statSync resourcePath
  catch e
    resourcePath = path.dirname(__dirname)

  {resourcePath, executedFrom, pathsToOpen, testMode}
