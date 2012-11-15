UndoManager = require 'undo-manager'
Buffer = require 'buffer'
Range = require 'range'

describe "UndoManager", ->
  [buffer, undoManager] = []

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    undoManager = buffer.undoManager

  afterEach ->
    buffer.destroy()

  describe ".undo()", ->
    it "undoes the last change", ->
      buffer.change(new Range([0, 5], [0, 9]), '')
      buffer.insert([0, 6], 'h')
      buffer.insert([0, 10], 'y')
      expect(buffer.lineForRow(0)).toContain 'qshorty'

      undoManager.undo()
      expect(buffer.lineForRow(0)).toContain 'qshort'
      expect(buffer.lineForRow(0)).not.toContain 'qshorty'

      undoManager.undo()
      expect(buffer.lineForRow(0)).toContain 'qsort'

      undoManager.undo()
      expect(buffer.lineForRow(0)).toContain 'quicksort'

    it "does not throw an exception when there is nothing to undo", ->
      undoManager.undo()

  describe ".redo()", ->
    beforeEach ->
      buffer.change(new Range([0, 5], [0, 9]), '')
      buffer.insert([0, 6], 'h')
      buffer.insert([0, 10], 'y')
      undoManager.undo()
      undoManager.undo()
      expect(buffer.lineForRow(0)).toContain 'qsort'

    it "redoes the last undone change", ->
      undoManager.redo()
      expect(buffer.lineForRow(0)).toContain 'qshort'

      undoManager.redo()
      expect(buffer.lineForRow(0)).toContain 'qshorty'

      undoManager.undo()
      expect(buffer.lineForRow(0)).toContain 'qshort'

    it "does not throw an exception when there is nothing to redo", ->
      undoManager.redo()
      undoManager.redo()
      undoManager.redo()

    it "discards the redo history when there is a new change following an undo", ->
      buffer.insert([0, 6], 'p')
      expect(buffer.getText()).toContain 'qsport'

      undoManager.redo()
      expect(buffer.getText()).toContain 'qsport'

  describe "transact(fn)", ->
    it "causes changes in the transaction to be undone simultaneously", ->
      buffer.insert([0, 0], "foo")

      undoManager.transact ->
        undoManager.transact ->
          buffer.insert([1, 2], "111")
          buffer.insert([1, 9], "222")

      expect(buffer.lineForRow(1)).toBe '  111var 222sort = function(items) {'

      undoManager.undo()
      expect(buffer.lineForRow(1)).toBe '  var sort = function(items) {'
      expect(buffer.lineForRow(0)).toContain 'foo'

      undoManager.undo()

      expect(buffer.lineForRow(0)).not.toContain 'foo'

      undoManager.redo()
      expect(buffer.lineForRow(0)).toContain 'foo'

      undoManager.redo()
      expect(buffer.lineForRow(1)).toBe '  111var 222sort = function(items) {'

      undoManager.undo()
      expect(buffer.lineForRow(1)).toBe '  var sort = function(items) {'

    it "does not record empty transactions", ->
      buffer.insert([0,0], "foo")
      undoManager.transact ->

      undoManager.undo()
      expect(buffer.lineForRow(0)).not.toContain("foo")

    it "records transactions that occur prior to an exception", ->
      spyOn(console, 'error')
      buffer.setText("jumpstreet")
      undoManager.transact ->
        buffer.insert([0,0], "3")
        buffer.insert([0,0], "2")
        throw new Error("problem")
        buffer.insert([0,0], "2")

      expect(console.error).toHaveBeenCalled()
      expect(buffer.lineForRow(0)).toBe "23jumpstreet"
      undoManager.undo()
      expect(buffer.lineForRow(0)).toBe "jumpstreet"

  describe "when a `do` operation throws an exception", ->
    it "clears the stack", ->
      spyOn(console, 'error')
      buffer.setText("word")
      class FailingOperation
        do: -> throw new Error("I'm a bad do operation")

      buffer.insert([0,0], "1")
      undoManager.pushOperation(new FailingOperation())
      expect(console.error).toHaveBeenCalled()
      undoManager.undo()
      expect(buffer.lineForRow(0)).toBe "1word"


  describe "when an `undo` operation throws an exception", ->
    it "clears the stack", ->
      spyOn(console, 'error')
      buffer.setText("word")
      class FailingOperation
        undo: -> throw new Error("I'm a bad undo operation")

      buffer.insert([0,0], "1")
      undoManager.pushOperation(new FailingOperation())
      undoManager.undo()
      expect(console.error).toHaveBeenCalled()
      expect(buffer.lineForRow(0)).toBe "1word"

  describe "when an `redo` operation throws an exception", ->
    it "clears the stack", ->
      spyOn(console, 'error')
      buffer.setText("word")
      class FailingOperation
        redo: -> throw new Error("I'm a bad undo operation")

      buffer.insert([0,0], "1")
      undoManager.pushOperation(new FailingOperation())
      undoManager.undo()
      undoManager.redo()
      expect(console.error).toHaveBeenCalled()
      expect(buffer.lineForRow(0)).toBe "1word"