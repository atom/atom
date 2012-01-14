class Command
  constructor: (@editor) ->
  isComplete: -> true

class DeleteChar extends Command
  execute: ->
    @editor.deleteChar()

module.exports = { DeleteChar }

