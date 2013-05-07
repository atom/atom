fs = require 'fs'
optimist = require 'optimist'

{argv} = optimist.usage('Usage: apm <command>')
                 .alias('v', 'version')
                 .describe('v', 'Print the apm version')
                 .alias('h', 'help')
                 .describe('h', 'Print this usage message')

module.exports =
  run: ->
    if argv.v
      console.log JSON.parse(fs.readFileSync('package.json')).version
    else if argv.h
      optimist.showHelp(console.log)
    else
      optimist.showHelp(console.log)
