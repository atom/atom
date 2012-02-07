module.exports =
class UndoManager
  undoHistory: null
  undoInProgress: null

  constructor: (@buffer) ->
    @undoHistory = []
    @buffer.on 'change', (op) =>
      @undoHistory.push(op) unless @undoInProgress

  undo: ->
    return unless @undoHistory.length
    op = @undoHistory.pop()
    @undoInProgress = true
    @buffer.change op.newRange, op.oldText
    @undoInProgress = false

