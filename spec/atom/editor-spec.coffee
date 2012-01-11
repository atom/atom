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

    it "restores the ace edit session for a previously assigned buffer", ->
      buffer = new Buffer filePath
      editor.setBuffer buffer

      aceSession = editor.getAceSession()

      editor.setBuffer new Buffer(tempFilePath)
      expect(editor.getAceSession()).not.toBe(aceSession)

      editor.setBuffer(buffer)
      expect(editor.getAceSession()).toBe aceSession

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

  describe ".save()", ->
    it "is triggered by the 'save' event", ->
      spyOn(editor, 'save')
      editor.trigger('save')
      expect(editor.save).toHaveBeenCalled()

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

  describe "when a keydown event is handled by the ace editor", ->
    returnValue = null
    handler = null
    event = null

    beforeEach ->
      event = keydownEvent 'x'
      spyOn(event, 'stopPropagation')

    describe "when no key event handler has been assigned", ->
      beforeEach ->
        expect(editor.keyEventHandler).toBeNull()

      it "handles the event without crashing", ->
        editor.aceEditor.onCommandKey event, 0, event.which

    describe "when a key event handler has been assigned", ->
      beforeEach ->
        handler = {
          handleKeyEvent: jasmine.createSpy('handleKeyEvent').andCallFake ->
            returnValue
        }
        editor.keyEventHandler = handler

      it "asks the key event handler to handle the event", ->
        editor.aceEditor.onCommandKey event, 0, event.which
        expect(handler.handleKeyEvent).toHaveBeenCalled()

      describe "if the atom key event handler returns false, indicating that it did not handle the event", ->
        beforeEach ->
          returnValue = false

        it "does not stop the propagation of the event, allowing Ace to handle it as normal", ->
          editor.aceEditor.onCommandKey event, 0, event.which
          expect(event.stopPropagation).not.toHaveBeenCalled()

      describe "if the atom key event handler returns true, indicating that it handled the event", ->
        beforeEach ->
          returnValue = true

        it "stops propagation of the event, so Ace does not attempt to handle it", ->
          editor.aceEditor.onCommandKey event, 0, event.which
          expect(event.stopPropagation).toHaveBeenCalled()

