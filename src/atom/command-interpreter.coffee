fs = require 'fs'
PEG = require 'pegjs'

module.exports =
class CommandInterpreter
  constructor: ->
    @parser = PEG.buildParser(fs.read(require.resolve 'commands.pegjs'))

  eval: (editor, command) ->
    operations = @parser.parse(command)
    operation.execute(editor) for operation in operations

