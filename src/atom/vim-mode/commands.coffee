class Command
  constructor: (@editor) ->
  isComplete: -> true

class DeleteRight extends Command
  execute: ->
    @editor.delete()
    isOnEOL = @editor.getCursorColumn() == @editor.getCurrentLine().length
    if isOnEOL
      @editor.setCursorColumn(@editor.getCursorColumn() - 1)

module.exports = { DeleteRight }

