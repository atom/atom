fs = require 'fs'
PEG = require 'pegjs'

module.exports =
class CommandInterpreter
  constructor: (@editor) ->
    @parser = PEG.buildParser(fs.read(require.resolve 'commands.pegjs'))

  eval: (command) ->
    operation = @parser.parse(command)
    operation.perform(@editor)

