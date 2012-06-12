Buffer = require 'buffer'
Editor = require 'editor'
$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'

describe "Cursor", ->
  [buffer, editor, cursorView, cursor] = []

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    editor = new Editor
    editor.enableKeymap()
    editor.setBuffer(buffer)
    editor.attachToDom()
    cursor = editor.getCursor()
    cursorView = editor.getCursorView()

  describe "adding and removing of the idle class", ->
    it "removes the idle class while moving, then adds it back when it stops", ->
      advanceClock(200)

      expect(cursorView).toHaveClass 'idle'
      cursor.setScreenPosition([1, 2])
      expect(cursorView).not.toHaveClass 'idle'

      window.advanceClock(200)
      expect(cursorView).toHaveClass 'idle'

      cursor.setScreenPosition([1, 3])
      advanceClock(100)

      cursor.setScreenPosition([1, 4])
      advanceClock(100)
      expect(cursorView).not.toHaveClass 'idle'

      advanceClock(100)
      expect(cursorView).toHaveClass 'idle'
