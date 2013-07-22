RootView = require 'root-view'

fdescribe "Autoflow package", ->
  editor = null

  beforeEach ->
    window.rootView = new RootView
    rootView.open()
    atom.activatePackage('autoflow')
    rootView.attachToDom()
    editor = rootView.getActiveView()

    config.set('editor.preferredLineLength', 30)

  describe "autoflow:reflow-paragraph", ->
    it "rearranges line breaks in the current paragraph to ensure lines are shorter than config.editor.preferredLineLength", ->
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

    it "allows for single words that exceed the preferred wrap column length", ->
      editor.setText("this-is-a-super-long-word-that-shouldn't-break-autoflow and these are some smaller words")

      editor.setCursorBufferPosition([0, 4])
      editor.trigger 'autoflow:reflow-paragraph'

      expect(editor.getText()).toBe """
        this-is-a-super-long-word-that-shouldn't-break-autoflow
        and these are some smaller
        words
      """
