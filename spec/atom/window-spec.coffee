require 'window'

describe "Window", ->
  describe "bindKeys", ->
    beforeEach ->
      window.startup()

    afterEach ->
      window.shutdown()

    it "creates 'save' keybinding", ->
      spyOn(window.editor, 'save')
      window.keydown 'meta+s'
      expect(window.editor.save).toHaveBeenCalled()
