path = require 'path'

require 'colors'
CSON = require 'season'
optimist = require 'optimist'

config = require './config'
Command = require './command'

module.exports =
class Publisher extends Command
  @commandNames: ['publish']

  constructor: ->
    @userConfigPath = config.getUserConfigPath()
    @atomNpmPath = require.resolve('npm/bin/npm-cli')

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm publish [<newversion> | major | minor | patch | build]

      Publish a new version of the package in the current working directory.

      If a new version or version increment is specified than a new Git tag is
      created and the package.json file is updated with that new version before
      it is published to the apm registry.

      Run `apm available` to see all the currently published packages.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.string('tag').describe('tag', 'Specify a tag to publish under')
    options.boolean('force').describe('force', 'Force publish')

  showHelp: (argv) -> @parseOptions(argv).showHelp()

  versionPackage: (version, callback) ->
    process.stdout.write 'Preparing and tagging a new version '
    versionArgs = ['version', version, '-m', 'Prepare %s release']
    @fork @atomNpmPath, versionArgs, (code, stderr='', stdout='') ->
      if code is 0
        process.stdout.write '\u2713\n'.green
        callback()
      else
        process.stdout.write '\u2717\n'.red
        callback("#{stdout}\n#{stderr}".red)

  publishPackage: (options, callback) ->
    process.stdout.write 'Publishing '
    try
      {name, version} = CSON.readFileSync(CSON.resolve('package')) ? {}
      process.stdout.write "#{name}@#{version} "

    publishArgs = ['--userconfig', @userConfigPath, 'publish']
    if tag = options.argv.tag
      publishArgs.push('--tag', tag)
    if force = options.argv.force
      publishArgs.push('--force')

    @fork @atomNpmPath, publishArgs, (code, stderr='', stdout='') ->
      if code is 0
        process.stdout.write '\u2713\n'.green
        callback()
      else
        process.stdout.write '\u2717\n'.red
        callback("#{stdout}\n#{stderr}".red)

  run: (options) ->
    {callback} = options
    options = @parseOptions(options)

    if version = options.argv._[0]
      @versionPackage version, (error) =>
        if error?
          callback(error)
        else
          @publishPackage(options, callback)
    else
      @publishPackage(options, callback)
