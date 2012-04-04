module.exports =
class UndoManager
  undoHistory: null
  redoHistory: null
  currentBatch: null
  preserveHistory: false

  constructor: (@buffer) ->
    @undoHistory = []
    @redoHistory = []
    @buffer.on 'change', (op) =>
      unless @preserveHistory
        if @currentBatch
          @currentBatch.push(op)
        else
          @undoHistory.push([op])
        @redoHistory = []

  undo: ->
    if ops = @undoHistory.pop()
      @preservingHistory =>
        opsInReverse = new Array(ops...)
        opsInReverse.reverse()
        for op in opsInReverse
          @buffer.change op.newRange, op.oldText
        @redoHistory.push ops

  redo: ->
    if ops = @redoHistory.pop()
      @preservingHistory =>
        for op in ops
          @buffer.change op.oldRange, op.newText
        @undoHistory.push ops

  startUndoBatch: ->
    @currentBatch = []

  endUndoBatch: ->
    @undoHistory.push(@currentBatch)
    @currentBatch = null

  preservingHistory: (fn) ->
    @preserveHistory = true
    fn()
    @preserveHistory = false

