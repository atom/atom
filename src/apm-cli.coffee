fs = require 'fs'
optimist = require 'optimist'
Installer = require './installer'
Uninstaller = require './uninstaller'
Lister = require './lister'
Publisher = require './publisher'
Fetcher = require './fetcher'

parseOptions = (args=[]) ->
  options = optimist(args)
  options.usage """

    Usage: apm <command>

    where <command> is one of:
        available, help, install, list, publish, uninstall
  """
  options.alias('v', 'version').describe('v', 'Print the apm version')
  options.alias('h', 'help').describe('h', 'Print this usage message')
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
    if args.v
      console.log require('../package.json').version
    else if args.h
      options.showHelp()
    else if command
      switch command
        when 'help' then options.showHelp()
        when 'install' then new Installer().run(options)
        when 'uninstall' then new Uninstaller().run(options)
        when 'list', 'ls' then new Lister().run(options)
        when 'publish' then new Publisher().run(options)
        when 'available' then new Fetcher().run(options)
        else
          options.callback("Unrecognized command: #{command}")
    else
      options.showHelp()
