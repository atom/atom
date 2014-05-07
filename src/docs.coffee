_ = require 'underscore-plus'
optimist = require 'optimist'
request = require 'request'

View = require './view'
config = require './config'
tree = require './tree'

module.exports =
class Docs extends View
  @commandNames: ['docs', 'home', 'open']
  open: require 'open'

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm docs <package_name>

      Opens a package's homepage in the default browser.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.boolean('print').describe('print', 'Just print the URL, do not open it')

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    [packageName] = options.argv._

    unless packageName
      callback("Missing required package name")
      return

    @getPackage packageName, (error, pack) =>
      if error?
        callback(error)
        return

      if repository = @getRepository(pack)
        if options.argv.print
          console.log repository
        else
          @open(repository)

      else
        callback("Package \"#{packageName}\" does not contain a repository URL")
        return
      callback()

