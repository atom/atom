RootView = require 'root-view'

describe "Autoflow package", ->
  editor = null

  beforeEach ->
    rootView = new RootView
    atom.loadPackage 'autoflow'
    editor = rootView.getActiveEditor()

  describe "autoflow:reflow-paragraph", ->
    it "rearranges line breaks in the current paragraph to ensure lines are shorter than config.editor.preferredLineLength", ->
      config.set('editor.preferredLineLength', 30)
      editor.setText """
        This is a preceding paragraph, which shouldn't be modified by a reflow of the following paragraph.

        The quick brown fox jumps over the lazy
        dog. The preceding sentence contains every letter
        in the entire English alphabet, which has absolutely no relevance
        to this test.

        This is a following paragraph, which shouldn't be modified by a reflow of the preciding paragraph.

      """

      editor.setCursorBufferPosition([3, 5])
      editor.trigger 'autoflow:reflow-paragraph'

      expect(editor.getText()).toBe """
        This is a preceding paragraph, which shouldn't be modified by a reflow of the following paragraph.

        The quick brown fox jumps over
        the lazy dog. The preceding
        sentence contains every letter
        in the entire English
        alphabet, which has absolutely
        no relevance to this test.

        This is a following paragraph, which shouldn't be modified by a reflow of the preciding paragraph.

      """
