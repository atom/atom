RootView = require 'root-view'

describe "Autoflow package", ->
  editor = null
  autoflow = null

  describe "autoflow:reflow-paragraph", ->
    beforeEach ->
      window.rootView = new RootView
      rootView.open()
      atom.activatePackage('autoflow')
      rootView.attachToDom()
      editor = rootView.getActiveView()

      config.set('editor.preferredLineLength', 30)

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

  describe "reflowing text", ->
    beforeEach ->
      window.rootView = new RootView
      autoflow = atom.activatePackage('autoflow', immediate: true).mainModule

    it 'respects current paragraphs', ->
      text = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh id magna ullamcorper sagittis. Maecenas
        et enim eu orci tincidunt adipiscing
        aliquam ligula.

        Lorem ipsum dolor sit amet, consectetur adipiscing elit.
        Phasellus gravida
        nibh id magna ullamcorper
        tincidunt adipiscing lacinia a dui. Etiam quis erat dolor.
        rutrum nisl fermentum rhoncus. Duis blandit ligula facilisis fermentum.
      '''

      res = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh
        id magna ullamcorper sagittis. Maecenas et enim eu orci tincidunt adipiscing
        aliquam ligula.

        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh
        id magna ullamcorper tincidunt adipiscing lacinia a dui. Etiam quis erat dolor.
        rutrum nisl fermentum rhoncus. Duis blandit ligula facilisis fermentum.
      '''
      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'respects indentation', ->
      text = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh id magna ullamcorper sagittis. Maecenas
        et enim eu orci tincidunt adipiscing
        aliquam ligula.

            Lorem ipsum dolor sit amet, consectetur adipiscing elit.
            Phasellus gravida
            nibh id magna ullamcorper
            tincidunt adipiscing lacinia a dui. Etiam quis erat dolor.
            rutrum nisl fermentum  rhoncus. Duis blandit ligula facilisis fermentum
      '''

      res = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh
        id magna ullamcorper sagittis. Maecenas et enim eu orci tincidunt adipiscing
        aliquam ligula.

            Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida
            nibh id magna ullamcorper tincidunt adipiscing lacinia a dui. Etiam quis
            erat dolor. rutrum nisl fermentum  rhoncus. Duis blandit ligula facilisis
            fermentum
      '''
      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'respects prefixed text (comments!)', ->
      text = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh id magna ullamcorper sagittis. Maecenas
        et enim eu orci tincidunt adipiscing
        aliquam ligula.

          #  Lorem ipsum dolor sit amet, consectetur adipiscing elit.
          #  Phasellus gravida
          #  nibh id magna ullamcorper
          #  tincidunt adipiscing lacinia a dui. Etiam quis erat dolor.
          #  rutrum nisl fermentum  rhoncus. Duis blandit ligula facilisis fermentum
      '''

      res = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh
        id magna ullamcorper sagittis. Maecenas et enim eu orci tincidunt adipiscing
        aliquam ligula.

          #  Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida
          #  nibh id magna ullamcorper tincidunt adipiscing lacinia a dui. Etiam quis
          #  erat dolor. rutrum nisl fermentum  rhoncus. Duis blandit ligula facilisis
          #  fermentum
      '''
      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'respects multiple prefixes (js/c comments)', ->
      text = '''
        // Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida
        et enim eu orci tincidunt adipiscing
        aliquam ligula.
      '''

      res = '''
        // Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida et
        // enim eu orci tincidunt adipiscing aliquam ligula.
      '''
      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res
