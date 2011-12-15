Editor = require 'editor'
$ = require 'jquery'
ck = require 'coffeekup'

describe "Editor", ->
  mainDiv = null; editor = null; filePath = null

  beforeEach ->
    filePath = require.resolve 'fixtures/sample.txt'
    mainDiv = $("<div id='main'>")
    $("#jasmine-content").append(mainDiv)
    editor = new Editor filePath

  afterEach ->
    editor.destroy()

  describe "constructor", ->
    it "attaches itself to the #main element and opens a buffer with the given url", ->
      expect(editor.buffer.url).toEqual filePath
      expect(mainDiv.children('.editor').html()).not.toBe ''

    it "populates the editor with the contents of the buffer", ->
      expect(editor.aceEditor.getSession().getValue()).toBe editor.buffer.getText()

  describe 'destroy', ->
    it 'destroys the ace editor and removes #editor from the dom.', ->
      spyOn editor.aceEditor, 'destroy'

      editor.destroy()
      expect(editor.aceEditor.destroy).toHaveBeenCalled()
      expect(mainDiv.children('.editor').length).toBe 0

  describe "when the text is changed via the ace editor", ->
    it "updates the buffer text", ->
      expect(editor.buffer.getText()).not.toMatch /^.ooo/
      editor.aceEditor.getSession().insert {row: 0, column: 1}, 'ooo'
      expect(editor.buffer.getText()).toMatch /^.ooo/
