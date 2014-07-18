path = require 'path'

optimist = require 'optimist'
temp = require 'temp'

Command = require './command'
fs = require './fs'

module.exports =
class Test extends Command
  @commandNames: ['test']

  parseOptions: (argv) ->
    options = optimist(argv)

    options.usage """
      Usage:
        apm test

      Runs the package's tests contained within the spec directory (relative
      to the current working directory).
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('p', 'path').string('path').describe('path', 'Path to atom command')

  showHelp: (argv) -> @parseOptions(argv).showHelp()

  getChocolateyAtomPath: ->
    if process.env.CHOCOLATEYINSTALL
      atomCommand = path.join(process.env.CHOCOLATEYINSTALL, 'bin', 'atom.exe')
      return atomCommand if fs.existsSync(atomCommand)

    if process.env.ALLUSERSPROFILE
      atomCommand = path.join(process.env.ALLUSERSPROFILE, 'chocolatey', 'bin', 'atom.exe')
      return atomCommand if fs.existsSync(atomCommand)

    null

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    {env} = process

    if options.argv.path
      atomCommand = options.argv.path
    else if process.platform is 'win32'
      atomCommand = @getChocolateyAtomPath()
    atomCommand = 'atom' unless fs.existsSync(atomCommand)

    packagePath = process.cwd()
    testArgs = ['--dev', '--test', "--spec-directory=#{path.join(packagePath, 'spec')}"]

    if process.platform is 'win32'
      testArgs.unshift('--shimgen-waitforexit')
      logFile = temp.openSync(suffix: '.log', prefix: "#{path.basename(packagePath)}-")
      fs.closeSync(logFile.fd)
      logFilePath = logFile.path

      # Quote all arguments and escapes inner quotes
      testArgs.push("--log-file=#{logFilePath}")
      cmdArgs = testArgs.map (arg) -> "\"#{arg.replace(/"/g, '\\"')}\""
      cmdArgs.unshift("\"#{atomCommand}\"")
      cmdArgs = ['/s', '/c', "\"#{cmdArgs.join(' ')}\""]

      cmdOptions =
        env: env
        windowsVerbatimArguments: true
      cmd = process.env.comspec or 'cmd.exe'

      @spawn cmd, cmdArgs, cmdOptions, (code) ->
        try
          loggedOutput = fs.readFileSync(logFilePath, 'utf8')
          process.stdout.write("#{loggedOutput}\n") if loggedOutput

        if code is 0
          process.stdout.write 'Tests passed\n'.green
          callback()
        else
          callback('Tests failed')
    else
      @spawn atomCommand, testArgs, {env, streaming: true}, (code) ->
        if code is 0
          process.stdout.write 'Tests passed\n'.green
          callback()
        else
          callback('Tests failed')
