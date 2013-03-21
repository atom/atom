UndoManager = require 'undo-manager'
Buffer = require 'text-buffer'
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

  describe "transaction methods", ->
    describe "transact([fn])", ->
      describe "when called with a function", ->
        it "causes changes performed within the function's dynamic extent to be undone simultaneously", ->
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

        it "undoes operations that occured prior to an exception when the transaction is undone", ->
          buffer.setText("jumpstreet")

          expect(->
            undoManager.transact ->
              buffer.insert([0,0], "3")
              buffer.insert([0,0], "2")
              throw new Error("problem")
              buffer.insert([0,0], "2")
          ).toThrow('problem')

          expect(buffer.lineForRow(0)).toBe "23jumpstreet"
          undoManager.undo()
          expect(buffer.lineForRow(0)).toBe "jumpstreet"

      describe "when called without a function", ->
        beforeEach ->
          buffer.setText('')

        it "returns a transaction object that can be committed later", ->
          buffer.append('1')
          undoManager.transact()
          buffer.append('2')
          buffer.append('3')
          undoManager.commit()
          buffer.append('4')

          expect(buffer.getText()).toBe '1234'
          undoManager.undo()
          expect(buffer.getText()).toBe '123'
          undoManager.undo()
          expect(buffer.getText()).toBe '1'
          undoManager.redo()
          expect(buffer.getText()).toBe '123'

        it "returns a transaction object that can be aborted later", ->
          buffer.append('1')
          buffer.append('2')

          undoManager.transact()

          buffer.append('3')
          buffer.append('4')
          expect(buffer.getText()).toBe '1234'

          undoManager.abort()
          expect(buffer.getText()).toBe '12'

          undoManager.undo()
          expect(buffer.getText()).toBe '1'

          undoManager.redo()
          expect(buffer.getText()).toBe '12'

          undoManager.redo()
          expect(buffer.getText()).toBe '12'

    describe "commit", ->
      it "throws an exception if there is no current transaction", ->
        expect(-> buffer.commit()).toThrow()

    describe "abort", ->
      it "does not affect the undo stack when the current transaction is empty", ->
        buffer.setText('')
        buffer.append('1')
        buffer.transact()
        buffer.abort()
        expect(buffer.getText()).toBe '1'
        buffer.undo()
        expect(buffer.getText()).toBe ''

      it "throws an exception if there is no current transaction", ->
        expect(-> buffer.abort()).toThrow()

  describe "exception handling", ->
    describe "when a `do` operation throws an exception", ->
      it "clears the stack", ->
        spyOn(console, 'error')
        buffer.setText("word")
        buffer.insert([0,0], "1")
        expect(->
          undoManager.pushOperation(do: -> throw new Error("I'm a bad do operation"))
        ).toThrow("I'm a bad do operation")

        undoManager.undo()
        expect(buffer.lineForRow(0)).toBe "1word"

    describe "when an `undo` operation throws an exception", ->
      it "clears the stack", ->
        spyOn(console, 'error')
        buffer.setText("word")
        buffer.insert([0,0], "1")
        undoManager.pushOperation(undo: -> throw new Error("I'm a bad undo operation"))
        expect(-> undoManager.undo()).toThrow("I'm a bad undo operation")
        expect(buffer.lineForRow(0)).toBe "1word"

    describe "when an `redo` operation throws an exception", ->
      it "clears the stack", ->
        spyOn(console, 'error')
        buffer.setText("word")
        buffer.insert([0,0], "1")
        undoManager.pushOperation(redo: -> throw new Error("I'm a bad redo operation"))
        undoManager.undo()
        expect(-> undoManager.redo()).toThrow("I'm a bad redo operation")
        expect(buffer.lineForRow(0)).toBe "1word"
