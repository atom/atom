fs = require 'fs'
PEG = require 'pegjs'

module.exports =
class CommandInterpreter
  constructor: (@project) ->
    @parser = PEG.buildParser(fs.read(require.resolve 'command-panel/commands.pegjs'))

  eval: (string, activeEditSession) ->
    compositeCommand = @parser.parse(string)
    @lastRelativeAddress = compositeCommand if compositeCommand.isRelativeAddress()
    compositeCommand.execute(@project, activeEditSession)

  repeatRelativeAddress: (activeEditSession) ->
    @lastRelativeAddress?.execute(@project, activeEditSession)

  repeatRelativeAddressInReverse: (activeEditSession) ->
    @lastRelativeAddress?.reverse().execute(@project, activeEditSession)
