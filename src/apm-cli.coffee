{spawn} = require 'child_process'
path = require 'path'

_ = require 'underscore-plus'
colors = require 'colors'
npm = require 'npm'
optimist = require 'optimist'
wordwrap = require 'wordwrap'

config = require './config'
fs = require './fs'

setupTempDirectory = ->
  temp = require 'temp'
  tempDirectory = require('os').tmpdir()
  # Resolve ~ in tmp dir atom/atom#2271
  tempDirectory = path.resolve(fs.absolute(tempDirectory))
  temp.dir = tempDirectory
  try
    fs.makeTreeSync(temp.dir)

setupTempDirectory()

commandClasses = [
  require './clean'
  require './dedupe'
  require './develop'
  require './docs'
  require './featured'
  require './init'
  require './install'
  require './links'
  require './link'
  require './list'
  require './login'
  require './publish'
  require './rebuild'
  require './search'
  require './star'
  require './stars'
  require './test'
  require './uninstall'
  require './unlink'
  require './unpublish'
  require './unstar'
  require './update'
  require './upgrade'
  require './view'
]

commands = {}
for commandClass in commandClasses
  for name in commandClass.commandNames ? []
    commands[name] = commandClass

parseOptions = (args=[]) ->
  options = optimist(args)
  options.usage """

    apm - Atom Package Manager powered by https://atom.io

    Usage: apm <command>

    where <command> is one of:
    #{wordwrap(4, 80)(Object.keys(commands).sort().join(', '))}.

    Run `apm help <command>` to see the more details about a specific command.
  """
  options.alias('v', 'version').describe('version', 'Print the apm version')
  options.alias('h', 'help').describe('help', 'Print this usage message')
  options.boolean('color').default('color', true).describe('color', 'Enable colored output')
  options.command = options.argv._[0]
  for arg, index in args when arg is options.command
    options.commandArgs = args[index+1..]
    break
  options

printVersions = (args, callback) ->
  apmVersion =  require('../package.json').version ? ''
  npmVersion = require('npm/package.json').version ? ''
  nodeVersion = process.versions.node ? ''

  getPythonVersion (pythonVersion) ->
    getGitVersion (gitVersion) ->
      if args.json
        versions =
          apm: apmVersion
          npm: npmVersion
          node: nodeVersion
          python: pythonVersion
          git: gitVersion
        if config.isWin32()
          versions.visualStudio = config.getInstalledVisualStudioFlag()
        console.log JSON.stringify(versions)
      else
        pythonVersion ?= ''
        gitVersion ?= ''
        versions =  """
          #{'apm'.red}  #{apmVersion.red}
          #{'npm'.green}  #{npmVersion.green}
          #{'node'.blue} #{nodeVersion.blue}
          #{'python'.yellow} #{pythonVersion.yellow}
          #{'git'.magenta} #{gitVersion.magenta}
        """

        if config.isWin32()
          visualStudioVersion = config.getInstalledVisualStudioFlag() ? ''
          versions += "\n#{'visual studio'.cyan} #{visualStudioVersion.cyan}"

        console.log versions
      callback()

getPythonVersion = (callback) ->
  npmOptions =
    userconfig: config.getUserConfigPath()
    globalconfig: config.getGlobalConfigPath()
  npm.load npmOptions, ->
    python = npm.config.get('python') ? process.env.PYTHON
    if config.isWin32() and not python
      rootDir = process.env.SystemDrive ? 'C:\\'
      rootDir += '\\' unless rootDir[rootDir.length - 1] is '\\'
      pythonExe = path.resolve(rootDir, 'Python27', 'python.exe')
      python = pythonExe if fs.isFileSync(pythonExe)

    python ?= 'python'

    spawned = spawn(python, ['--version'])
    outputChunks = []
    spawned.stderr.on 'data', (chunk) -> outputChunks.push(chunk)
    spawned.stdout.on 'data', (chunk) -> outputChunks.push(chunk)
    spawned.on 'error', ->
    spawned.on 'close', (code) ->
      if code is 0
        [name, version] = Buffer.concat(outputChunks).toString().split(' ')
        version = version?.trim()
      callback(version)

getGitVersion = (callback) ->
  npmOptions =
    userconfig: config.getUserConfigPath()
    globalconfig: config.getGlobalConfigPath()
  npm.load npmOptions, ->
    git = npm.config.get('git') ? 'git'
    spawned = spawn(git, ['--version'])
    outputChunks = []
    spawned.stderr.on 'data', (chunk) -> outputChunks.push(chunk)
    spawned.stdout.on 'data', (chunk) -> outputChunks.push(chunk)
    spawned.on 'error', ->
    spawned.on 'close', (code) ->
      if code is 0
        [gitName, versionName, version] = Buffer.concat(outputChunks).toString().split(' ')
        version = version?.trim()
      callback(version)

module.exports =
  run: (args, callback) ->
    options = parseOptions(args)

    unless options.argv.color
      colors.setTheme
        blue: 'stripColors'
        cyan: 'stripColors'
        green: 'stripColors'
        magenta: 'stripColors'
        red: 'stripColors'
        yellow: 'stripColors'
        rainbow: 'stripColors'

    callbackCalled = false
    options.callback = (error) ->
      return if callbackCalled
      callbackCalled = true
      if error?
        if _.isString(error)
          message = error
        else
          message = error.message ? error

        if message is 'canceled'
          # A prompt was canceled so just log an empty line
          console.log()
        else if message
          console.error(message.red)
      callback?(error)

    args = options.argv
    command = options.command
    if args.version
      printVersions(args, options.callback)
    else if args.help
      if Command = commands[options.command]
        new Command().showHelp(options.command)
      else
        options.showHelp()
    else if command
      if command is 'help'
        if Command = commands[options.commandArgs]
          new Command().showHelp(options.commandArgs)
        else
          options.showHelp()
      else if Command = commands[command]
        new Command().run(options)
      else
        options.callback("Unrecognized command: #{command}")
    else
      options.showHelp()
