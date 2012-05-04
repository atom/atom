module.exports =
class UndoManager
  undoHistory: null
  redoHistory: null
  currentBatch: null
  preserveHistory: false
  startBatchCallCount: null

  constructor: (@buffer) ->
    @startBatchCallCount = 0
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
    if batch = @undoHistory.pop()
      @preservingHistory =>
        opsInReverse = new Array(batch...)
        opsInReverse.reverse()
        for op in opsInReverse
          @buffer.change op.newRange, op.oldText
        @redoHistory.push batch
      batch.oldSelectionRanges

  redo: ->
    if batch = @redoHistory.pop()
      @preservingHistory =>
        for op in batch
          @buffer.change op.oldRange, op.newText
        @undoHistory.push batch
      batch.newSelectionRanges

  startUndoBatch: (ranges) ->
    @startBatchCallCount++
    return if @startBatchCallCount > 1
    @currentBatch = []
    @currentBatch.oldSelectionRanges = ranges

  endUndoBatch: (ranges) ->
    @startBatchCallCount--
    return if @startBatchCallCount > 0
    @currentBatch.newSelectionRanges = ranges
    @undoHistory.push(@currentBatch) if @currentBatch.length > 0
    @currentBatch = null

  preservingHistory: (fn) ->
    @preserveHistory = true
    fn()
    @preserveHistory = false

