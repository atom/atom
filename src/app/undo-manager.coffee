_ = require 'underscore'

module.exports =

class UndoManager
  undoHistory: null
  redoHistory: null
  currentBatch: null
  startBatchCallCount: null

  constructor: (@buffer) ->
    @startBatchCallCount = 0
    @undoHistory = []
    @redoHistory = []

  perform: (operation) ->
    if @currentBatch
      @currentBatch.push(operation)
    else
      @undoHistory.push([operation])
    @redoHistory = []
    operation.do()

  undo: ->
    if batch = @undoHistory.pop()
      opsInReverse = new Array(batch...)
      opsInReverse.reverse()
      op.undo() for op in opsInReverse
      @redoHistory.push batch
      batch.oldSelectionRanges

  redo: ->
    if batch = @redoHistory.pop()
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
