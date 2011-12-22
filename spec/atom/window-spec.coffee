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
