Snippets = require 'snippets'
RootView = require 'root-view'
Buffer = require 'buffer'
Editor = require 'editor'
_ = require 'underscore'
fs = require 'fs'

describe "Snippets extension", ->
  [buffer, editor] = []
  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    rootView.activateExtension(Snippets)
    editor = rootView.activeEditor()
    buffer = editor.buffer
    rootView.simulateDomAttachment()

  describe "when 'tab' is triggered on the editor", ->
    beforeEach ->
      Snippets.evalSnippets 'js', """
        snippet t1 "Snippet without tab stops"
        this is a test
        endsnippet

        snippet t2 "Snippet with tab stops"
        first go here:$1 then here:$2
        endsnippet
      """
    describe "when the letters preceding the cursor trigger a snippet", ->
      describe "when the snippet contains no tab stops", ->
        it "replaces the prefix with the snippet text and places the cursor at its end", ->
          editor.insertText("t1")
          expect(editor.getCursorScreenPosition()).toEqual [0, 2]

          editor.trigger 'tab'
          expect(buffer.lineForRow(0)).toBe "this is a testvar quicksort = function () {"
          expect(editor.getCursorScreenPosition()).toEqual [0, 14]

      describe "when the snippet contains tab stops", ->


    describe "when the letters preceding the cursor don't match a snippet", ->
      it "inserts a tab as normal", ->
        editor.insertText("xte")
        expect(editor.getCursorScreenPosition()).toEqual [0, 3]

        editor.trigger 'tab'
        expect(buffer.lineForRow(0)).toBe "xte  var quicksort = function () {"
        expect(editor.getCursorScreenPosition()).toEqual [0, 5]

  describe ".loadSnippetsFile(path)", ->
    it "loads the snippets in the given file", ->
      spyOn(fs, 'read').andReturn """
        snippet t1 "Test snippet 1"
        this is a test 1
        endsnippet
      """

      Snippets.loadSnippetsFile('/tmp/foo/js.snippets')
      expect(fs.read).toHaveBeenCalledWith('/tmp/foo/js.snippets')

      editor.insertText("t1")
      editor.trigger 'tab'
      expect(buffer.lineForRow(0)).toBe "this is a test 1var quicksort = function () {"

  describe "Snippets parser", ->
    it "can parse multiple snippets", ->
      snippets = Snippets.snippetsParser.parse """
        snippet t1 "Test snippet 1"
        this is a test 1
        endsnippet

        snippet t2 "Test snippet 2"
        this is a test 2
        endsnippet
      """
      expect(_.keys(snippets).length).toBe 2
      snippet = snippets['t1']
      expect(snippet.prefix).toBe 't1'
      expect(snippet.description).toBe "Test snippet 1"
      expect(snippet.body).toBe "this is a test 1"

      snippet = snippets['t2']
      expect(snippet.prefix).toBe 't2'
      expect(snippet.description).toBe "Test snippet 2"
      expect(snippet.body).toBe "this is a test 2"
