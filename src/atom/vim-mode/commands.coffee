class Command
  constructor: (@editor) ->
  isComplete: -> true

class DeleteRight extends Command
  execute: ->
    @editor.delete() unless @editor.getCurrentLine().length == 0

module.exports = { DeleteRight }

