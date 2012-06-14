fs = require 'fs'
PEG = require 'pegjs'

module.exports =
class CommandInterpreter
  constructor: ->
    @parser = PEG.buildParser(fs.read(require.resolve 'command-interpreter/commands.pegjs'))

  eval: (editor, string) ->
    compositeCommand = @parser.parse(string)
    @lastRelativeAddress = compositeCommand if compositeCommand.isRelativeAddress()
    compositeCommand.execute(editor)

  repeatRelativeAddress: (editor) ->
    @lastRelativeAddress?.execute(editor)

