class Command
  constructor: (@editor) ->
  isComplete: -> true

class DeleteRight extends Command
  execute: ->
    @editor.delete()
    isOnLastCharachter = @editor.getCursorColumn() == @editor.getCurrentLine().length
    if isOnLastCharachter
      @editor.setCursorColumn(@editor.getCursorColumn() - 1)

module.exports = { DeleteRight }

