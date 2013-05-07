fs = require 'fs'
optimist = require 'optimist'

{argv} = optimist.usage('Usage: apm <command>')
                 .alias('v', 'version')
                 .describe('v', 'Print the apm version')

module.exports =
  run: ->
    if argv.v
      console.log JSON.parse(fs.readFileSync('package.json')).version
    else
      optimist.showHelp(console.log)
