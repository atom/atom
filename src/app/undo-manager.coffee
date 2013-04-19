_ = require 'underscore'

# Internal: The object in charge of managing redo and undo operations.
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
      @clear()
      throw e

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
    unless @currentTransaction?
      throw new Error("Trying to commit when there is no current transaction")

    empty = @currentTransaction.length is 0
    @undoHistory.push(@currentTransaction) unless empty
    @currentTransaction = null
    not empty

  abort: ->
    unless @currentTransaction?
      throw new Error("Trying to abort when there is no current transaction")

    if @commit()
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
      @clear()
      throw e

  redo: (editSession) ->
    try
      if batch = @redoHistory.pop()
        for op in batch
          op.do?(editSession)
          op.redo?(editSession)

        @undoHistory.push(batch)
        batch.newSelectionRanges
    catch e
      @clear()
      throw e