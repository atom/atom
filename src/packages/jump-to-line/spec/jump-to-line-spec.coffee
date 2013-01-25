RootView = require 'root-view'

describe 'JumpToLine', ->
  [rootView, jumpToLine, editor] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    rootView.enableKeymap()
    jumpToLine = atom.loadPackage("jump-to-line").getInstance()
    editor = rootView.getActiveEditor()
    editor.setCursorBufferPosition([1,0])

  afterEach ->
    rootView.remove()

  describe "when editor:jump-to-line is triggered", ->
    it "attaches to the root view", ->
      expect(jumpToLine.hasParent()).toBeFalsy()
      editor.trigger 'editor:jump-to-line'
      expect(jumpToLine.hasParent()).toBeTruthy()

  describe "when entering a line number", ->
    it "only allows 0-9 to be entered in the mini editor", ->
      expect(jumpToLine.miniEditor.getText()).toBe ''
      jumpToLine.miniEditor.textInput 'a'
      expect(jumpToLine.miniEditor.getText()).toBe ''
      jumpToLine.miniEditor.textInput '40'
      expect(jumpToLine.miniEditor.getText()).toBe '40'

  describe "when core:confirm is triggered", ->
    describe "when a line number has been entered", ->
      it "moves the cursor to the first character of the line", ->
        jumpToLine.miniEditor.textInput '3'
        jumpToLine.miniEditor.trigger 'core:confirm'
        expect(editor.getCursorBufferPosition()).toEqual [2, 4]

    describe "when no line number has been entered", ->
      it "closes the view and does not update the cursor position", ->
        jumpToLine.miniEditor.trigger 'core:confirm'
        expect(jumpToLine.hasParent()).toBeFalsy()
        expect(editor.getCursorBufferPosition()).toEqual [1, 0]

  describe "when core:cancel is triggered", ->
    it "closes the view and does not update the cursor position", ->
      jumpToLine.miniEditor.trigger 'core:cancel'
      expect(jumpToLine.hasParent()).toBeFalsy()
      expect(editor.getCursorBufferPosition()).toEqual [1, 0]
