UndoManager = require 'undo-manager'
Buffer = require 'buffer'
Range = require 'range'

describe "UndoManager", ->
  [buffer, undoManager] = []

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    undoManager = new UndoManager(buffer)

  describe ".undo()", ->
    it "undoes the last change", ->
      buffer.change(new Range([0, 5], [0, 9]), '')
      buffer.insert([0, 6], 'h')
      buffer.insert([0, 10], 'y')
      expect(buffer.getLine(0)).toContain 'qshorty'

      undoManager.undo()
      expect(buffer.getLine(0)).toContain 'qshort'
      expect(buffer.getLine(0)).not.toContain 'qshorty'

      undoManager.undo()
      expect(buffer.getLine(0)).toContain 'qsort'

      undoManager.undo()
      expect(buffer.getLine(0)).toContain 'quicksort'

    it "does not throw an exception when there is no last change", ->
      undoManager.undo()
