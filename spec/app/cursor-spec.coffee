Buffer = require 'buffer'
Editor = require 'editor'
$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'

describe "Cursor", ->
  [buffer, editor, cursor] = []

  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    editor = new Editor
    editor.enableKeymap()
    editor.setBuffer(buffer)
    cursor = editor.getCursors()[0]

  describe "adding and removing of the idle class", ->
    it "removes the idle class while moving, then adds it back when it stops", ->
      advanceClock(200)

      expect(cursor).toHaveClass 'idle'
      cursor.setScreenPosition([1, 2])
      expect(cursor).not.toHaveClass 'idle'

      window.advanceClock(200)
      expect(cursor).toHaveClass 'idle'

      cursor.setScreenPosition([1, 3])
      advanceClock(100)

      cursor.setScreenPosition([1, 4])
      advanceClock(100)
      expect(cursor).not.toHaveClass 'idle'

      advanceClock(100)
      expect(cursor).toHaveClass 'idle'

  describe ".isOnEOL()", ->
    it "only returns true when cursor is on the end of a line", ->
      cursor.setScreenPosition([1,29])
      expect(cursor.isOnEOL()).toBeFalsy()

      cursor.setScreenPosition([1,30])
      expect(cursor.isOnEOL()).toBeTruthy()

  describe "vertical auto scroll", ->
    beforeEach ->
      editor.attachToDom()
      editor.focus()
      editor.vScrollMargin = 2

    it "only attempts to scroll when a cursor is visible", ->
      setEditorWidthInChars(editor, 20)
      setEditorHeightInChars(editor, 10)
      editor.setCursorBufferPosition([11,0])
      editor.addCursorAtBufferPosition([0,0])
      editor.addCursorAtBufferPosition([6,50])
      window.advanceClock()

      offscreenScrollHandler = spyOn(editor.getCursors()[0], 'autoScrollVertically')
      onscreenScrollHandler = spyOn(editor.getCursors()[1], 'autoScrollVertically')
      anotherOffscreenScrollHandler = spyOn(editor.getCursors()[2], 'autoScrollVertically')

      editor.moveCursorRight()
      window.advanceClock()
      expect(offscreenScrollHandler).not.toHaveBeenCalled()
      expect(onscreenScrollHandler).toHaveBeenCalled()
      expect(anotherOffscreenScrollHandler).not.toHaveBeenCalled()

    it "only attempts to scroll once when multiple cursors are visible", ->
      setEditorWidthInChars(editor, 20)
      setEditorHeightInChars(editor, 10)
      editor.setCursorBufferPosition([11,0])
      editor.addCursorAtBufferPosition([0,0])
      editor.addCursorAtBufferPosition([6,0])
      window.advanceClock()

      offscreenScrollHandler = spyOn(editor.getCursors()[0], 'autoScrollVertically')
      onscreenScrollHandler = spyOn(editor.getCursors()[1], 'autoScrollVertically')
      anotherOnscreenScrollHandler = spyOn(editor.getCursors()[2], 'autoScrollVertically')

      editor.moveCursorRight()
      window.advanceClock()
      expect(offscreenScrollHandler).not.toHaveBeenCalled()
      expect(onscreenScrollHandler).toHaveBeenCalled()
      expect(anotherOnscreenScrollHandler).not.toHaveBeenCalled()

