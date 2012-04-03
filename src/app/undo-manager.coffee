module.exports =
class UndoManager
  undoHistory: null
  redoHistory: null
  preserveHistory: false

  constructor: (@buffer) ->
    @undoHistory = []
    @redoHistory = []
    @buffer.on 'change', (op) =>
      unless @preserveHistory
        @undoHistory.push(op)
        @redoHistory = []

  undo: ->
    if op = @undoHistory.pop()
      @preservingHistory =>
        @buffer.change op.newRange, op.oldText
        @redoHistory.push op

  redo: ->
    if op = @redoHistory.pop()
      @preservingHistory =>
        @buffer.change op.oldRange, op.newText
        @undoHistory.push op

  preservingHistory: (fn) ->
    @preserveHistory = true
    fn()
    @preserveHistory = false
