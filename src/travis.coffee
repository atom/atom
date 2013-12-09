path = require 'path'

optimist = require 'optimist'

Command = require './command'
fs = require './fs'

module.exports =
class Travis extends Command
  @commandNames: ['ci', 'travis']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm travis

      Configure the package in the current directory to build on Travis CI.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  showHelp: (argv) -> @parseOptions(argv).showHelp()

  copyTravisYml: ->
    process.stdout.write "Creating .travis.yml "
    templateTravisPath = path.resolve(__dirname, '..', 'templates', '.travis.yml')
    fs.writeFileSync('.travis.yml', fs.readFileSync(templateTravisPath))
    process.stdout.write '\u2713\n'.green

  setupTravis: (callback) ->
    process.stdout.write "Setting up Travis "
    setupScriptPath = path.resolve(__dirname, '..', 'script', 'setup-travis')
    @spawn setupScriptPath, [], (code, stderr='', stdout='') ->
      if code is 0
        process.stdout.write '\u2713\n'.green
        callback()
      else
        process.stdout.write '\u2717\n'.red
        callback("#{stdout}\n#{stderr}")

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    @copyTravisYml()
    @setupTravis(callback)
