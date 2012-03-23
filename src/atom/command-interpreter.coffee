fs = require 'fs'
PEG = require 'pegjs'

module.exports =
class CommandInterpreter
  constructor: ->
    @parser = PEG.buildParser(fs.read(require.resolve 'commands.pegjs'))

  eval: (editor, string) ->
    command = @parser.parse(string)
    @lastRelativeAddress = command if command.isRelativeAddress()
    command.execute(editor)

  repeatLastRelativeAddress: (editor) ->
    @lastRelativeAddress.execute(editor)

