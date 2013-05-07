fs = require 'fs'
optimist = require 'optimist'

parseOptions = (args=[]) ->
  optimist(args)
    .usage('Usage: apm <command>')
    .alias('v', 'version').describe('v', 'Print the apm version')
    .alias('h', 'help').describe('h', 'Print this usage message')

module.exports =
  run: (args) ->
    options = parseOptions(args)
    args = options.argv
    if args.v
      console.log JSON.parse(fs.readFileSync('package.json')).version
    else if args.h
      options.showHelp()
    else
      options.showHelp()
