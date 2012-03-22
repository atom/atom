CommandInterpreter = require 'command-interpreter'
Buffer = require 'buffer'
Editor = require 'editor'

describe "CommandInterpreter", ->
  [interpreter, editor, buffer] = []

  beforeEach ->
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    editor = new Editor({buffer})
    interpreter = new CommandInterpreter()

  describe "addresses", ->
    describe "a line address", ->
      it "selects the specified line", ->
        interpreter.eval(editor, '4')
        expect(editor.selection.getBufferRange()).toEqual [[3, 0], [4, 0]]

    describe "0", ->
      it "selects the zero-length string at the start of the file", ->
        interpreter.eval(editor, '0')
        expect(editor.selection.getBufferRange()).toEqual [[0,0], [0,0]]

        interpreter.eval(editor, '0,1')
        expect(editor.selection.getBufferRange()).toEqual [[0,0], [1,0]]

    describe "$", ->
      it "selects EOF", ->
        interpreter.eval(editor, '$')
        expect(editor.selection.getBufferRange()).toEqual [[12,2], [12,2]]

        interpreter.eval(editor, '1,$')
        expect(editor.selection.getBufferRange()).toEqual [[0,0], [12,2]]

    describe "address range", ->
      describe "when two addresses are specified", ->
        it "selects from the begining of the left address to the end of the right address", ->
          interpreter.eval(editor, '4,7')
          expect(editor.selection.getBufferRange()).toEqual [[3, 0], [7, 0]]

      describe "when the left address is unspecified", ->
        it "selects from the begining of buffer to the end of the right address", ->
          interpreter.eval(editor, ',7')
          expect(editor.selection.getBufferRange()).toEqual [[0, 0], [7, 0]]

      describe "when the right address is unspecified", ->
        it "selects from the begining of left address to the end file", ->
          interpreter.eval(editor, '4,')
          expect(editor.selection.getBufferRange()).toEqual [[3, 0], [12, 2]]

      describe "when the neither address is specified", ->
        it "selects the entire file", ->
          interpreter.eval(editor, ',')
          expect(editor.selection.getBufferRange()).toEqual [[0, 0], [12, 2]]


  describe "substitution", ->
    it "does nothing if there are no matches", ->
      editor.selection.setBufferRange([[6, 0], [6, 44]])
      interpreter.eval(editor, 's/not-in-text/foo/')
      expect(buffer.lineForRow(6)).toBe '      current < pivot ? left.push(current) : right.push(current);'

    it "performs a single substitution within the current dot", ->
      editor.selection.setBufferRange([[6, 0], [6, 44]])
      interpreter.eval(editor, 's/current/foo/')
      expect(buffer.lineForRow(6)).toBe '      foo < pivot ? left.push(current) : right.push(current);'

    describe "when suffixed with a g", ->
      it "performs a multiple substitutions within the current dot", ->
        editor.selection.setBufferRange([[6, 0], [6, 44]])
        interpreter.eval(editor, 's/current/foo/g')
        expect(buffer.lineForRow(6)).toBe '      foo < pivot ? left.push(foo) : right.push(current);'

      describe "when prefixed with an address", ->
        it "only makes substitutions within given lines", ->
          interpreter.eval(editor, '4,6s/ /!/g')
          expect(buffer.lineForRow(2)).toBe '    if (items.length <= 1) return items;'
          expect(buffer.lineForRow(3)).toBe '!!!!var!pivot!=!items.shift(),!current,!left!=![],!right!=![];'
          expect(buffer.lineForRow(4)).toBe '!!!!while(items.length!>!0)!{'
          expect(buffer.lineForRow(5)).toBe '!!!!!!current!=!items.shift();'
          expect(buffer.lineForRow(6)).toBe '      current < pivot ? left.push(current) : right.push(current);'
