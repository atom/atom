Editor = require 'editor'
$ = require 'jquery'
ck = require 'coffeekup'
fs = require 'fs'

describe "Editor", ->
  mainDiv = null; editor = null
  filePath = null; tempFilePath = null

  beforeEach ->
    filePath = require.resolve 'fixtures/sample.txt'
    tempFilePath = '/tmp/temp.txt'
    mainDiv = $("<div id='main'>")
    $("#jasmine-content").append(mainDiv)
    editor = new Editor filePath

  afterEach ->
    fs.remove tempFilePath
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


  describe "on key down", ->
    describe "meta+s", ->
      tempEditor = null

      beforeEach ->
        tempEditor = new Editor tempFilePath

      afterEach ->
        tempEditor.destroy()

      describe "when the current buffer has a url", ->
        it "saves the current buffer to disk", ->
          tempEditor.buffer.setText 'Edited buffer!'
          expect(fs.exists(tempFilePath)).toBeFalsy()

          $(document).trigger(keydown 'meta+s')

          expect(fs.exists(tempFilePath)).toBeTruthy()
          expect(fs.read(tempFilePath)).toBe 'Edited buffer!'

      describe "when the current buffer has no url", ->
        it "presents a save as dialog", ->

        describe "when a url is chosen", ->

        describe "when dialog is cancelled", ->

