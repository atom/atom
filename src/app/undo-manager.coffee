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
    safeFn = ->
      try
        fn()
      catch e
        console.error e.stack

    if @currentTransaction
      safeFn()
    else
      @currentTransaction = []
      safeFn()
      @undoHistory.push(@currentTransaction) if @currentTransaction?.length
      @currentTransaction = null

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
