fs = require 'fs'

optimist = require 'optimist'

Cleaner = require './cleaner'
Developer = require './developer'
Installer = require './installer'
Uninstaller = require './uninstaller'
Lister = require './lister'
LinkLister = require './link-lister'
Publisher = require './publisher'
Fetcher = require './fetcher'
Linker = require './linker'
Unlinker = require './unlinker'
Rebuilder = require './rebuilder'
Updater = require './updater'

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
      switch command
        when 'available' then new Fetcher().run(options)
        when 'clean' then new Cleaner().run(options)
        when 'develop', 'dev' then new Developer().run(options)
        when 'help' then options.showHelp()
        when 'install' then new Installer().run(options)
        when 'link' then new Linker().run(options)
        when 'linked', 'links' then new LinkLister().run(options)
        when 'list', 'ls' then new Lister().run(options)
        when 'publish' then new Publisher().run(options)
        when 'rebuild' then new Rebuilder().run(options)
        when 'uninstall' then new Uninstaller().run(options)
        when 'unlink' then new Unlinker().run(options)
        when 'update' then new Updater().run(options)
        else
          options.callback("Unrecognized command: #{command}")
    else
      options.showHelp()
