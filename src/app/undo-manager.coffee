_ = require 'underscore'

module.exports =

class UndoManager
  undoHistory: null
  redoHistory: null
  currentTransaction: null

  constructor: ->
    @startBatchCallCount = 0
    @undoHistory = []
    @redoHistory = []

  pushOperation: (operation, editSession) ->
    if @currentTransaction
      @currentTransaction.push(operation)
    else
      @undoHistory.push([operation])
    @redoHistory = []
    operation.do?(editSession)

  transact: (fn) ->
    if @currentTransaction
      fn()
    else
      @currentTransaction = []
      fn()
      @undoHistory.push(@currentTransaction) if @currentTransaction.length
      @currentTransaction = null

  undo: (editSession) ->
    if batch = @undoHistory.pop()
      opsInReverse = new Array(batch...)
      opsInReverse.reverse()
      op.undo?(editSession) for op in opsInReverse
      @redoHistory.push batch
      batch.oldSelectionRanges

  redo: (editSession) ->
    if batch = @redoHistory.pop()
      for op in batch
        op.do?(editSession)
        op.redo?(editSession)
      @undoHistory.push(batch)
      batch.newSelectionRanges
