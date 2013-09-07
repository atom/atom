fs = require 'fs'

optimist = require 'optimist'

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
  options.usage """

    Usage: apm <command>

    where <command> is one of:
        available, develop, help, install, link, links, list,
        publish, rebuild, uninstall, unlink
  """
  options.alias('v', 'version').describe('version', 'Print the apm version')
  options.alias('h', 'help').describe('help', 'Print this usage message')
  options.alias('d', 'dev').boolean('dev')
  options.alias('a', 'all').boolean('all')
  options.boolean('hard')
  options.boolean('force')
  options.string('tag')
  remainingArguments = options.argv._
  options.command = remainingArguments.shift()
  options.commandArgs = remainingArguments
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
      options.showHelp()
    else if command
      if Command = commands[command]
        new Command().run(options)
      else
        options.callback("Unrecognized command: #{command}")
    else
      options.showHelp()
