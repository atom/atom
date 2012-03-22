CommandInterpreter = require 'command-interpreter'
Buffer = require 'buffer'
Editor = require 'editor'

describe "CommandInterpreter", ->
  [interpreter, editor, buffer] = []

  beforeEach ->
    buffer = new Buffer(require.resolve 'fixtures/sample.js')
    editor = new Editor({buffer})
    interpreter = new CommandInterpreter()

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
          interpreter.eval(editor, '4,7s/ /!/g')
          expect(buffer.lineForRow(2)).toBe '    if (items.length <= 1) return items;'
          expect(buffer.lineForRow(3)).toBe '!!!!var!pivot!=!items.shift(),!current,!left!=![],!right!=![];'
          expect(buffer.lineForRow(4)).toBe '!!!!while(items.length!>!0)!{'
          expect(buffer.lineForRow(5)).toBe '!!!!!!current!=!items.shift();'
          expect(buffer.lineForRow(6)).toBe '      current < pivot ? left.push(current) : right.push(current);'
