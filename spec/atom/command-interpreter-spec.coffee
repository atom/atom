CommandInterpreter = require 'command-interpreter'
Buffer = require 'buffer'
Editor = require 'editor'

describe "CommandInterpreter", ->
  [interpreter, editor, buffer] = []

  beforeEach ->
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    editor = new Editor({buffer})
    interpreter = new CommandInterpreter(editor)

  describe "substitution", ->
    it "performs the substitution within the current dot", ->
      editor.selection.setBufferRange([[6, 0], [6, 44]])
      interpreter.eval('s/current/foo/')
      expect(buffer.lineForRow(6)).toBe '      foo < pivot ? left.push(current) : right.push(current);'

