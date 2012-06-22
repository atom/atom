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
    rootView.enableKeymap()

  describe "when 'tab' is triggered on the editor", ->
    beforeEach ->
      Snippets.evalSnippets 'js', """
        snippet t1 "Snippet without tab stops"
        this is a test
        endsnippet

        snippet t2 "Snippet with tab stops"
        go here next:($2) and finally go here:($3)
        go here first:($1)

        endsnippet
      """

    describe "when the letters preceding the cursor trigger a snippet", ->
      describe "when the snippet contains no tab stops", ->
        it "replaces the prefix with the snippet text and places the cursor at its end", ->
          editor.insertText("t1")
          expect(editor.getCursorScreenPosition()).toEqual [0, 2]

          editor.trigger keydownEvent('tab', target: editor[0])
          expect(buffer.lineForRow(0)).toBe "this is a testvar quicksort = function () {"
          expect(editor.getCursorScreenPosition()).toEqual [0, 14]

      describe "when the snippet contains tab stops", ->
        it "places the cursor at the first tab-stop, and moves the cursor in response to 'next-tab-stop' events", ->
          editor.insertText('t2')
          editor.trigger keydownEvent('tab', target: editor[0])
          expect(buffer.lineForRow(0)).toBe "go here next:() and finally go here:()"
          expect(buffer.lineForRow(1)).toBe "go here first:()"
          expect(buffer.lineForRow(2)).toBe "var quicksort = function () {"
          expect(editor.getCursorScreenPosition()).toEqual [1, 15]
          editor.trigger keydownEvent('tab', target: editor[0])
          expect(editor.getCursorScreenPosition()).toEqual [0, 14]

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
      editor.trigger 'snippets:expand'
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

    it "can parse snippets with tabstops", ->
      snippets = Snippets.snippetsParser.parse """
        # this line intentially left blank.
        snippet t1 "Snippet with tab stops"
        go here next:($2) and finally go here:($3)
        go here first:($1)
        endsnippet
      """

      snippet = snippets['t1']
      expect(snippet.body).toBe """
        go here next:() and finally go here:()
        go here first:()\n
      """

      expect(snippet.tabStops).toEqual [[1, 15], [0, 14], [0, 37]]
