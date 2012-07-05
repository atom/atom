_ = require 'underscore'

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
    @buffer.on 'change', (event) =>
      unless @preserveHistory
        op = new BufferChangeOperation(_.extend({ @buffer }, event))
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
        op.undo() for op in opsInReverse
        @redoHistory.push batch
      batch.oldSelectionRanges

  redo: ->
    if batch = @redoHistory.pop()
      @preservingHistory =>
        op.do() for op in batch
        @undoHistory.push(batch)
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

class BufferChangeOperation
  constructor: ({@buffer, @oldRange, @newRange, @oldText, @newText}) ->

  do: ->
    @buffer.change @oldRange, @newText

  undo: ->
    @buffer.change @newRange, @oldText
