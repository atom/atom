fs = require 'fs'
PEG = require 'pegjs'

module.exports =
class CommandInterpreter
  constructor: ->
    @parser = PEG.buildParser(fs.read(require.resolve 'commands.pegjs'))

  eval: (editor, command) ->
    operation = @parser.parse(command)
    operation.execute(editor)

