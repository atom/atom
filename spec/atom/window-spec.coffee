require 'window'

describe "Window", ->
  describe "keybindings", ->
    beforeEach ->
      window.startup()

    afterEach ->
      window.shutdown()

    describe 'meta+s', ->
      it 'saves the buffer', ->
        spyOn(window.editor, 'save')
        window.keydown 'meta+s'
        expect(window.editor.save).toHaveBeenCalled()

    describe 'meta+o', ->
      selectedFilePath = null

      beforeEach ->
        spyOn(atom.native, 'openPanel').andCallFake -> 
          selectedFilePath

      it 'presents an open dialog', ->
        window.keydown 'meta+o'
        expect(atom.native.openPanel).toHaveBeenCalled()

      describe 'when a url is chosen', ->
        it 'opens the url in the editor', ->
          selectedFilePath = require.resolve 'fixtures/sample.txt'
          spyOn(window.editor, 'open').andCallFake (url) -> url
          window.keydown 'meta+o'
          expect(window.editor.open).toHaveBeenCalledWith(selectedFilePath)

      describe 'when dialog is canceled', ->
        it 'does not open the editor', ->
          selectedFilePath = null
          spyOn(window.editor, 'open').andCallFake()
          window.keydown 'meta+o'
          expect(window.editor.open).not.toHaveBeenCalled()
