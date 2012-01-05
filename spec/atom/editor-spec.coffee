Buffer = require 'buffer'
Editor = require 'editor'
$ = require 'jquery'
ck = require 'coffeekup'
fs = require 'fs'

describe "Editor", ->
  mainDiv = null
  editor = null
  filePath = null
  tempFilePath = null

  beforeEach ->
    filePath = require.resolve 'fixtures/sample.txt'
    tempFilePath = '/tmp/temp.txt'
    editor = Editor.build()

  afterEach ->
    fs.remove tempFilePath
    editor.destroy()

  describe "initialize", ->
    it "has a buffer", ->
      expect(editor.buffer).toBeDefined()

  describe 'destroy', ->
    it 'destroys the ace editor', ->
      spyOn(editor.aceEditor, 'destroy').andCallThrough()
      editor.destroy()
      expect(editor.aceEditor.destroy).toHaveBeenCalled()

  describe "setBuffer(buffer)", ->
    it "sets the document on the aceSession", ->
      buffer = new Buffer filePath
      editor.setBuffer buffer

      fileContents = fs.read(filePath)
      expect(editor.getAceSession().getValue()).toBe fileContents

    it "sets the language mode based on the file extension", ->
      buffer = new Buffer "something.js"
      editor.setBuffer buffer

      expect(editor.getAceSession().getMode().name).toBe 'javascript'

  describe "when the text is changed via the ace editor", ->
    it "updates the buffer text", ->
      buffer = new Buffer(filePath)
      editor.setBuffer(buffer)
      expect(buffer.getText()).not.toMatch /^.ooo/
      editor.getAceSession().insert {row: 0, column: 1}, 'ooo'
      expect(buffer.getText()).toMatch /^.ooo/

  describe "save", ->
    describe "when the current buffer has a url", ->
      beforeEach ->
        buffer = new Buffer(tempFilePath)
        editor.setBuffer(buffer)

      it "saves the current buffer to disk", ->
        editor.buffer.setText 'Edited buffer!'
        expect(fs.exists(tempFilePath)).toBeFalsy()

        editor.save()

        expect(fs.exists(tempFilePath)).toBeTruthy()
        expect(fs.read(tempFilePath)).toBe 'Edited buffer!'

    describe "when the current buffer has no url", ->
      selectedFilePath = null
      beforeEach ->
        expect(editor.buffer.url).toBeUndefined()
        editor.buffer.setText 'Save me to a new url'
        spyOn(atom.native, 'savePanel').andCallFake -> selectedFilePath

      it "presents a 'save as' dialog", ->
        editor.save()
        expect(atom.native.savePanel).toHaveBeenCalled()

      describe "when a url is chosen", ->
        it "saves the buffer to the chosen url", ->
          selectedFilePath = '/tmp/temp.txt'

          editor.save()

          expect(fs.exists(selectedFilePath)).toBeTruthy()
          expect(fs.read(selectedFilePath)).toBe 'Save me to a new url'

      describe "when dialog is cancelled", ->
        it "does not save the buffer", ->
          selectedFilePath = null

          editor.save()

          expect(fs.exists(selectedFilePath)).toBeFalsy()

