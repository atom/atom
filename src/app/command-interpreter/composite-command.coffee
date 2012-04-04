_ = require 'underscore'

module.exports =
class CompositeCommand
  constructor: (@subcommands) ->

  execute: (editor) ->
    for command in @subcommands
      ranges = editor.getSelectionsOrderedByBufferPosition().map (selection) -> selection.getBufferRange()
      for range in ranges
        command.execute(editor, range)

  isRelativeAddress: ->
    _.all(@subcommands, (command) -> command.isAddress() and command.isRelative())

