yargs = require 'yargs'
open = require 'open'

View = require './view'
config = require './apm'

module.exports =
class Docs extends View
  @commandNames: ['docs', 'home', 'open']

  parseOptions: (argv) ->
    options = yargs(argv).wrap(100)
    options.usage """

      Usage: apm docs [options] <package_name>

      Open a package's homepage in the default browser.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.boolean('p').alias('p', 'print').describe('print', 'Print the URL instead of opening it')

  openRepositoryUrl: (repositoryUrl) ->
    open(repositoryUrl)

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    [packageName] = options.argv._

    unless packageName
      callback("Missing required package name")
      return

    @getPackage packageName, options, (error, pack) =>
      return callback(error) if error?

      if repository = @getRepository(pack)
        if options.argv.print
          console.log repository
        else
          @openRepositoryUrl(repository)
        callback()
      else
        callback("Package \"#{packageName}\" does not contain a repository URL")
