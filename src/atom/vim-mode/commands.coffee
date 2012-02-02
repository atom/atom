class Command
  constructor: (@editor) ->
  isComplete: -> true

class DeleteRight extends Command
  execute: ->
    @editor.deleteRight()

module.exports = { DeleteRight }

