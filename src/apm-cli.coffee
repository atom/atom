fs = require 'fs'

optimist = require 'optimist'
wordwrap = require 'wordwrap'

commandClasses = [
  require './cleaner'
  require './developer'
  require './fetcher'
  require './installer'
  require './link-lister'
  require './linker'
  require './lister'
  require './publisher'
  require './rebuilder'
  require './uninstaller'
  require './unlinker'
  require './updater'
]

commands = {}
for commandClass in commandClasses
  for name in commandClass.commandNames ? []
    commands[name] = commandClass

parseOptions = (args=[]) ->
  options = optimist(args)
  usage = """

    Usage: apm <command>

    where <command> is one of:\n
  """
  usage += wordwrap(4, 80)(Object.keys(commands).sort().join(', '))
  usage += ".\n\nRun apm help <command> to see the more details about a specific command."
  options.usage(usage)
  options.alias('v', 'version').describe('version', 'Print the apm version')
  options.alias('h', 'help').describe('help', 'Print this usage message')
  options.alias('a', 'all').boolean('all')
  options.boolean('hard')
  options.boolean('force')
  options.string('tag')
  options.command = options.argv._[0]
  for arg, index in args when arg is options.command
    options.commandArgs = args[index+1..]
    break
  options

module.exports =
  run: (args, callback) ->
    options = parseOptions(args)
    callbackCalled = false
    options.callback = (error) ->
      return if callbackCalled
      callbackCalled = true
      if error?
        callback?(error)
        console.error(error)
        process.exit(1)
      else
        callback?()

    args = options.argv
    command = options.command
    if args.version
      console.log require('../package.json').version
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
