Snippets = require 'snippets'
Buffer = require 'buffer'
Editor = require 'editor'
_ = require 'underscore'

fdescribe "Snippets extension", ->
  [buffer, editor] = []
  beforeEach ->
    buffer = new Buffer(require.resolve('fixtures/sample.js'))
    editor = new Editor({buffer})

  describe "when 'tab' is triggered on the editor", ->
    describe "when the letters preceding the cursor are registered as a global extension", ->
      it "replaces the prefix with the snippet text", ->
        Snippets.evalSnippets 'js', """
          snippet te "Test snippet description"
          this is a test
          endsnippet

          snippet moo "Moo snippet"
          Mooooooo!
          endsnippet
        """

        editor.insertText("te")
        editor.trigger 'tab'

        expect(editor.getCursorScreenPosition()).toEqual [0, 2]
        expect(buffer.lineForRow(0)).toBe "this is a testvar quicksort = function () {"

  ffdescribe "Snippets parser", ->
    it "can parse a snippet", ->
      snippets = Snippets.snippetsParser.parse """
        snippet te "Test snippet description"
        this is a test
        endsnippet
      """

      expect(_.keys(snippets).length).toBe 1
      snippet = snippets['te']
      expect(snippet.prefix).toBe 'te'
      expect(snippet.description).toBe "Test snippet description"
      expect(snippet.body).toBe "this is a test"
