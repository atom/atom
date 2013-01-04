_ = require 'underscore'

module.exports =

class UndoManager
  undoHistory: null
  redoHistory: null
  currentTransaction: null

  constructor: ->
    @clear()

  clear: ->
    @currentTransaction = null
    @undoHistory = []
    @redoHistory = []

  pushOperation: (operation, editSession) ->
    if @currentTransaction
      @currentTransaction.push(operation)
    else
      @undoHistory.push([operation])
    @redoHistory = []

    try
      operation.do?(editSession)
    catch e
      console.error e.stack
      @clear()

  transact: (fn) ->
    isNewTransaction = not @currentTransaction?
    @currentTransaction ?= []
    if fn
      try
        fn()
      finally
        @commit() if isNewTransaction
    isNewTransaction

  commit: ->
    @undoHistory.push(@currentTransaction) if @currentTransaction?.length
    @currentTransaction = null

  abort: ->
    @commit()
    @undo()
    @redoHistory.pop()

  undo: (editSession) ->
    try
      if batch = @undoHistory.pop()
        opsInReverse = new Array(batch...)
        opsInReverse.reverse()
        op.undo?(editSession) for op in opsInReverse

        @redoHistory.push batch
        batch.oldSelectionRanges
    catch e
      console.error e.stack
      @clear()

  redo: (editSession) ->
    try
      if batch = @redoHistory.pop()
        for op in batch
          op.do?(editSession)
          op.redo?(editSession)

        @undoHistory.push(batch)
        batch.newSelectionRanges
    catch e
      console.error e.stack
      @clear()
