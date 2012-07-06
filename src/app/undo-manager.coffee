_ = require 'underscore'

module.exports =

class UndoManager
  undoHistory: null
  redoHistory: null
  currentTransaction: null

  constructor: (@buffer) ->
    @startBatchCallCount = 0
    @undoHistory = []
    @redoHistory = []

  pushOperation: (operation) ->
    if @currentTransaction
      @currentTransaction.push(operation)
    else
      @undoHistory.push([operation])
    @redoHistory = []
    operation.do?()

  transact: (fn) ->
    if @currentTransaction
      fn()
    else
      @currentTransaction = []
      fn()
      @undoHistory.push(@currentTransaction) if @currentTransaction.length
      @currentTransaction = null

  undo: ->
    if batch = @undoHistory.pop()
      opsInReverse = new Array(batch...)
      opsInReverse.reverse()
      op.undo?() for op in opsInReverse
      @redoHistory.push batch
      batch.oldSelectionRanges

  redo: ->
    if batch = @redoHistory.pop()
      for op in batch
        op.do?()
        op.redo?()
      @undoHistory.push(batch)
      batch.newSelectionRanges
