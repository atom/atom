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
    atom.loadPackage("snippets")
    editor = rootView.getActiveEditor()
    buffer = editor.getBuffer()
    rootView.simulateDomAttachment()
    rootView.enableKeymap()

  afterEach ->
    rootView.remove()

  describe "when 'tab' is triggered on the editor", ->
    beforeEach ->
      Snippets.evalSnippets 'js', """
        snippet t1 "Snippet without tab stops"
        this is a test
        endsnippet

        snippet t2 "With tab stops"
        go here next:($2) and finally go here:($3)
        go here first:($1)

        endsnippet

        snippet t3 "With indented second line"
        line 1
          line 2$1

        endsnippet

        snippet t4 "With tab stop placeholders"
        go here ${1:first} and then here ${2:second}

        endsnippet

        snippet t5 "Caused problems with undo"
        first line$1
          ${2:placeholder ending second line}
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
          anchorCountBefore = editor.activeEditSession.getAnchors().length
          editor.setCursorScreenPosition([2, 0])
          editor.insertText('t2')
          editor.trigger keydownEvent('tab', target: editor[0])
          expect(buffer.lineForRow(2)).toBe "go here next:() and finally go here:()"
          expect(buffer.lineForRow(3)).toBe "go here first:()"
          expect(buffer.lineForRow(4)).toBe "    if (items.length <= 1) return items;"
          expect(editor.getSelectedBufferRange()).toEqual [[3, 15], [3, 15]]

          editor.trigger keydownEvent('tab', target: editor[0])
          expect(editor.getSelectedBufferRange()).toEqual [[2, 14], [2, 14]]
          editor.insertText 'abc'

          editor.trigger keydownEvent('tab', target: editor[0])
          expect(editor.getSelectedBufferRange()).toEqual [[2, 40], [2, 40]]

          # tab backwards
          editor.trigger keydownEvent('tab', shiftKey: true, target: editor[0])
          expect(editor.getSelectedBufferRange()).toEqual [[2, 14], [2, 17]] # should highlight text typed at tab stop

          editor.trigger keydownEvent('tab', shiftKey: true, target: editor[0])
          expect(editor.getSelectedBufferRange()).toEqual [[3, 15], [3, 15]]

          # shift-tab on first tab-stop does nothing
          editor.trigger keydownEvent('tab', shiftKey: true, target: editor[0])
          expect(editor.getCursorScreenPosition()).toEqual [3, 15]

          # tab through all tab stops, then tab on last stop to terminate snippet
          editor.trigger keydownEvent('tab', target: editor[0])
          editor.trigger keydownEvent('tab', target: editor[0])
          editor.trigger keydownEvent('tab', target: editor[0])
          expect(buffer.lineForRow(2)).toBe "go here next:(abc) and finally go here:(  )"
          expect(editor.activeEditSession.getAnchors().length).toBe anchorCountBefore

        describe "when the tab stops have placeholder text", ->
          it "auto-fills the placeholder text and highlights it when navigating to that tab stop", ->
            editor.insertText 't4'
            editor.trigger 'snippets:expand'
            expect(buffer.lineForRow(0)).toBe 'go here first and then here second'
            expect(editor.getSelectedBufferRange()).toEqual [[0, 8], [0, 13]]

        describe "when the cursor is moved beyond the bounds of a tab stop", ->
          it "terminates the snippet", ->
            editor.setCursorScreenPosition([2, 0])
            editor.insertText('t2')
            editor.trigger keydownEvent('tab', target: editor[0])

            editor.moveCursorUp()
            editor.moveCursorLeft()
            editor.trigger keydownEvent('tab', target: editor[0])

            expect(buffer.lineForRow(2)).toBe "go here next:(  ) and finally go here:()"
            expect(editor.getCursorBufferPosition()).toEqual [2, 16]

            # test we can terminate with shift-tab
            editor.setCursorScreenPosition([4, 0])
            editor.insertText('t2')
            editor.trigger keydownEvent('tab', target: editor[0])
            editor.trigger keydownEvent('tab', target: editor[0])

            editor.moveCursorRight()
            editor.trigger keydownEvent('tab', shiftKey: true, target: editor[0])
            expect(editor.getCursorBufferPosition()).toEqual [4, 15]

      describe "when a the start of the snippet is indented", ->
        describe "when the snippet spans a single line", ->
          it "does not indent the next line", ->
            editor.setCursorScreenPosition([2, Infinity])
            editor.insertText ' t1'
            editor.trigger 'snippets:expand'
            expect(buffer.lineForRow(3)).toBe "    var pivot = items.shift(), current, left = [], right = [];"

        describe "when the snippet spans multiple lines", ->
          it "indents the subsequent lines of the snippet to be even with the start of the first line", ->
            editor.setCursorScreenPosition([2, Infinity])
            editor.insertText ' t3'
            editor.trigger 'snippets:expand'
            expect(buffer.lineForRow(2)).toBe "    if (items.length <= 1) return items; line 1"
            expect(buffer.lineForRow(3)).toBe "      line 2"
            expect(editor.getCursorBufferPosition()).toEqual [3, 12]

    describe "when the letters preceding the cursor don't match a snippet", ->
      it "inserts a tab as normal", ->
        editor.insertText("xte")
        expect(editor.getCursorScreenPosition()).toEqual [0, 3]

        editor.trigger keydownEvent('tab', target: editor[0])
        expect(buffer.lineForRow(0)).toBe "xte  var quicksort = function () {"
        expect(editor.getCursorScreenPosition()).toEqual [0, 5]

    describe "when a previous snippet expansion has just been undone", ->
      it "expands the snippet based on the current prefix rather than jumping to the old snippet's tab stop", ->
        editor.insertText 't5\n'
        editor.setCursorBufferPosition [0, 2]
        editor.trigger keydownEvent('tab', target: editor[0])
        expect(buffer.lineForRow(0)).toBe "first line"
        editor.undo()
        expect(buffer.lineForRow(0)).toBe "t5"
        editor.trigger keydownEvent('tab', target: editor[0])
        expect(buffer.lineForRow(0)).toBe "first line"

    describe "when a snippet expansion is undone and redone", ->
      it "recreates the snippet's tab stops", ->
        editor.insertText '    t5\n'
        editor.setCursorBufferPosition [0, 6]
        editor.trigger keydownEvent('tab', target: editor[0])
        expect(buffer.lineForRow(0)).toBe "    first line"
        editor.undo()
        editor.redo()

        expect(editor.getCursorBufferPosition()).toEqual [0, 14]
        editor.trigger keydownEvent('tab', target: editor[0])
        expect(editor.getSelectedBufferRange()).toEqual [[1, 6], [1, 36]]

      it "restores tabs stops in active edit session even when the initial expansion was in a different edit session", ->
        anotherEditor = editor.splitRight()

        editor.insertText '    t5\n'
        editor.setCursorBufferPosition [0, 6]
        editor.trigger keydownEvent('tab', target: editor[0])
        expect(buffer.lineForRow(0)).toBe "    first line"
        editor.undo()

        anotherEditor.redo()
        expect(anotherEditor.getCursorBufferPosition()).toEqual [0, 14]
        anotherEditor.trigger keydownEvent('tab', target: anotherEditor[0])
        expect(anotherEditor.getSelectedBufferRange()).toEqual [[1, 6], [1, 36]]

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
        go here first:()
      """

      expect(snippet.tabStops).toEqual [[[1, 15], [1, 15]], [[0, 14], [0, 14]], [[0, 37], [0, 37]]]
