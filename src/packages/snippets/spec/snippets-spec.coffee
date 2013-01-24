Snippets = require 'snippets'
Snippet = require 'snippets/src/snippet'
SnippetsTask = require 'snippets/src/snippets-task'
RootView = require 'root-view'
Buffer = require 'buffer'
Editor = require 'editor'
_ = require 'underscore'
fs = require 'fs'
AtomPackage = require 'atom-package'
TextMatePackage = require 'text-mate-package'

describe "Snippets extension", ->
  [buffer, editor] = []
  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    spyOn(SnippetsTask.prototype, 'start')
    atom.loadPackage("snippets")
    editor = rootView.getActiveEditor()
    buffer = editor.getBuffer()
    rootView.simulateDomAttachment()
    rootView.enableKeymap()

  afterEach ->
    rootView.remove()
    delete window.snippets

  describe "when 'tab' is triggered on the editor", ->
    beforeEach ->
      snippets.add
        ".source.js":
          "without tab stops":
            prefix: "t1"
            body: "this is a test"

          "tab stops":
            prefix: "t2"
            body: """
              go here next:($2) and finally go here:($0)
              go here first:($1)

            """

          "indented second line":
            prefix: "t3"
            body: """
              line 1
                line 2$1

            """

          "tab stop placeholders":
            prefix: "t4"
            body: """
              go here ${1:first
              think a while}, and then here ${2:second}

            """

          "nested tab stops":
            prefix: "t5"
            body: '${1:"${2:key}"}: ${3:value}'

          "caused problems with undo":
            prefix: "t6"
            body: """
              first line$1
                ${2:placeholder ending second line}
            """

    describe "when the letters preceding the cursor trigger a snippet", ->
      describe "when the snippet contains no tab stops", ->
        it "replaces the prefix with the snippet text and places the cursor at its end", ->
          editor.insertText("t1")
          expect(editor.getCursorScreenPosition()).toEqual [0, 2]

          editor.trigger keydownEvent('tab', target: editor[0])
          expect(buffer.lineForRow(0)).toBe "this is a testvar quicksort = function () {"
          expect(editor.getCursorScreenPosition()).toEqual [0, 14]

        it "inserts a real tab the next time a tab is pressed after the snippet is expanded", ->
          editor.insertText("t1")
          editor.trigger keydownEvent('tab', target: editor[0])
          expect(buffer.lineForRow(0)).toBe "this is a testvar quicksort = function () {"
          editor.trigger keydownEvent('tab', target: editor[0])
          expect(buffer.lineForRow(0)).toBe "this is a test  var quicksort = function () {"

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
            expect(buffer.lineForRow(0)).toBe 'go here first'
            expect(buffer.lineForRow(1)).toBe 'think a while, and then here second'
            expect(editor.getSelectedBufferRange()).toEqual [[0, 8], [1, 13]]
            editor.trigger keydownEvent('tab', target: editor[0])
            expect(editor.getSelectedBufferRange()).toEqual [[1, 29], [1, 35]]

        describe "when tab stops are nested", ->
          it "destroys the inner tab stop if the outer tab stop is modified", ->
            buffer.setText('')
            editor.insertText 't5'
            editor.trigger 'snippets:expand'
            expect(buffer.lineForRow(0)).toBe '"key": value'
            expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 5]]
            editor.insertText("foo")
            editor.trigger keydownEvent('tab', target: editor[0])
            expect(editor.getSelectedBufferRange()).toEqual [[0, 5], [0, 10]]

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
        editor.insertText 't6\n'
        editor.setCursorBufferPosition [0, 2]
        editor.trigger keydownEvent('tab', target: editor[0])
        expect(buffer.lineForRow(0)).toBe "first line"
        editor.undo()
        expect(buffer.lineForRow(0)).toBe "t6"
        editor.trigger keydownEvent('tab', target: editor[0])
        expect(buffer.lineForRow(0)).toBe "first line"

    describe "when a snippet expansion is undone and redone", ->
      it "recreates the snippet's tab stops", ->
        editor.insertText '    t6\n'
        editor.setCursorBufferPosition [0, 6]
        editor.trigger keydownEvent('tab', target: editor[0])
        expect(buffer.lineForRow(0)).toBe "    first line"
        editor.undo()
        editor.redo()
        expect(editor.getCursorBufferPosition()).toEqual [0, 14]
        editor.trigger keydownEvent('tab', target: editor[0])
        expect(editor.getSelectedBufferRange()).toEqual [[1, 6], [1, 36]]

  describe "snippet loading", ->
    it "loads non-hidden snippet files from all atom packages with snippets directories, logging a warning if a file can't be parsed", ->
      spyOn(console, 'warn').andCallThrough()
      jasmine.unspy(SnippetsTask.prototype, 'start')
      snippets.loaded = false
      snippets.loadAll()

      waitsFor((-> snippets.loaded), "Waiting for all snippets to load", 5000)

      runs ->
        expect(syntax.getProperty(['.test'], 'snippets.test')?.constructor).toBe Snippet

        # warn about junk-file, but don't even try to parse a hidden file
        expect(console.warn).toHaveBeenCalled()
        expect(console.warn.calls.length).toBeGreaterThan 0

    it "loads snippets from all TextMate packages with snippets", ->
      jasmine.unspy(SnippetsTask.prototype, 'start')
      snippets.loaded = false
      snippets.loadAll()

      waitsFor((-> snippets.loaded), "Waiting for all snippets to load", 5000)

      runs ->
        snippet = syntax.getProperty(['.source.js'], 'snippets.fun')
        expect(snippet.constructor).toBe Snippet
        expect(snippet.prefix).toBe 'fun'
        expect(snippet.name).toBe 'Function'
        expect(snippet.body).toBe """
          function function_name (argument) {
          \t// body...
          }
        """

  describe "Snippets parser", ->
    it "breaks a snippet body into lines, with each line containing tab stops at the appropriate position", ->
      bodyTree = snippets.parser.parse """
        the quick brown $1fox ${2:jumped ${3:over}
        }the ${4:lazy} dog
      """

      expect(bodyTree).toEqual [
        "the quick brown ",
        { index: 1, content: [] },
        "fox ",
        {
          index: 2,
          content: [
            "jumped ",
            { index: 3, content: ["over"]},
            "\n"
          ],
        }
        "the "
        { index: 4, content: ["lazy"] },
        " dog"
      ]
