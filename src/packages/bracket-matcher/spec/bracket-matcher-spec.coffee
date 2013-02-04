RootView = require 'root-view'

describe "bracket matching", ->
  [rootView, editor] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    atom.loadPackage('bracket-matcher')
    rootView.attachToDom()
    editor = rootView.getActiveEditor()

  afterEach ->
    rootView.deactivate()

  describe "when the cursor is before a starting pair", ->
    it "highlights the starting pair and ending pair", ->
      editor.moveCursorToEndOfLine()
      editor.moveCursorLeft()
      expect(editor.underlayer.find('.bracket-matcher').length).toBe 2
      expect(editor.underlayer.find('.bracket-matcher:first').position()).toEqual editor.pixelPositionForBufferPosition([0,28])
      expect(editor.underlayer.find('.bracket-matcher:last').position()).toEqual editor.pixelPositionForBufferPosition([12,0])

  describe "when the cursor is after a starting pair", ->
    it "highlights the starting pair and ending pair", ->
      editor.moveCursorToEndOfLine()
      expect(editor.underlayer.find('.bracket-matcher').length).toBe 2
      expect(editor.underlayer.find('.bracket-matcher:first').position()).toEqual editor.pixelPositionForBufferPosition([0,28])
      expect(editor.underlayer.find('.bracket-matcher:last').position()).toEqual editor.pixelPositionForBufferPosition([12,0])

  describe "when the cursor is before an ending pair", ->
    it "highlights the starting pair and ending pair", ->
      editor.moveCursorToBottom()
      editor.moveCursorLeft()
      editor.moveCursorLeft()
      expect(editor.underlayer.find('.bracket-matcher').length).toBe 2
      expect(editor.underlayer.find('.bracket-matcher:first').position()).toEqual editor.pixelPositionForBufferPosition([12,0])
      expect(editor.underlayer.find('.bracket-matcher:last').position()).toEqual editor.pixelPositionForBufferPosition([0,28])

  describe "when the cursor is after an ending pair", ->
    it "highlights the starting pair and ending pair", ->
      editor.moveCursorToBottom()
      editor.moveCursorLeft()
      expect(editor.underlayer.find('.bracket-matcher').length).toBe 2
      expect(editor.underlayer.find('.bracket-matcher:first').position()).toEqual editor.pixelPositionForBufferPosition([12,0])
      expect(editor.underlayer.find('.bracket-matcher:last').position()).toEqual editor.pixelPositionForBufferPosition([0,28])

  describe "when the cursor is moved off a pair", ->
    it "removes the starting pair and ending pair highlights", ->
      editor.moveCursorToEndOfLine()
      expect(editor.underlayer.find('.bracket-matcher').length).toBe 2
      editor.moveCursorToBeginningOfLine()
      expect(editor.underlayer.find('.bracket-matcher').length).toBe 0

  describe "pair balancing", ->
    describe "when a second starting pair preceeds the first ending pair", ->
      it "advances to the second ending pair", ->
        editor.setCursorBufferPosition([8,42])
        expect(editor.underlayer.find('.bracket-matcher').length).toBe 2
        expect(editor.underlayer.find('.bracket-matcher:first').position()).toEqual editor.pixelPositionForBufferPosition([8,42])
        expect(editor.underlayer.find('.bracket-matcher:last').position()).toEqual editor.pixelPositionForBufferPosition([8,54])
