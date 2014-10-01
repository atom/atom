optimist = require 'optimist'
Command = require './command'

module.exports =
class DedupePackageModules extends Command
  @commandNames: ['dedupe-package-modules']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm dedupe-package-modules

      Reduce module duplication in packages installed to ~/.atom/packages by
      pulling up common dependencies to ~/.atom/package/node_modules

      This command is experimental.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  run: ->
    # Move packages to ~/.atom/packages/node_modules
    # Build package.json with packages as dependencies to ~/.atom/packages/package.json
    # Find all module dependencies
    # Dedupe ~/.atom/packages with list of all module dependencies minus package names
    # Move packages back to ~/.atom/packages
    # Deduped modules will now be in ~/.atom/packages/node_modules
    # Delete ~/.atom/packages/package.json
