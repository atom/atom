RootView = require 'root-view'
FuzzyFinder = require 'fuzzy-finder'
$ = require 'jquery'
{$$} = require 'space-pen'

describe 'FuzzyFinder', ->
  [rootView, finder] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    rootView.enableKeymap()
    rootView.activateExtension(FuzzyFinder)
    finder = FuzzyFinder.instance

  describe "file-finder behavior", ->
    describe "toggling", ->
      describe "when the root view's project has a path", ->
        it "shows the FuzzyFinder or hides it and returns focus to the active editor if it already showing", ->
          rootView.attachToDom()
          expect(rootView.find('.fuzzy-finder')).not.toExist()
          rootView.find('.editor').trigger 'split-right'
          [editor1, editor2] = rootView.find('.editor').map -> $(this).view()

          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          expect(rootView.find('.fuzzy-finder')).toExist()
          expect(rootView.find('.fuzzy-finder input:focus')).toExist()
          finder.miniEditor.insertText('this should not show up next time we toggle')

          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          expect(editor1.isFocused).toBeFalsy()
          expect(editor2.isFocused).toBeTruthy()
          expect(rootView.find('.fuzzy-finder')).not.toExist()

          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          expect(finder.miniEditor.getText()).toBe ''

        it "shows all relative file paths for the current project and selects the first", ->
          finder.maxResults = 1000
          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          rootView.project.getFilePaths().done (paths) ->
            expect(finder.pathList.children('li').length).toBe paths.length, finder.maxResults
            for path in paths
              expect(finder.pathList.find("li:contains(#{path})")).toExist()
            expect(finder.pathList.children().first()).toHaveClass 'selected'

      describe "when root view's project has no path", ->
        beforeEach ->
          rootView.project.setPath(null)

        it "does not open the FuzzyFinder", ->
          expect(rootView.find('.fuzzy-finder')).not.toExist()
          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          expect(rootView.find('.fuzzy-finder')).not.toExist()

    describe "selecting a path", ->
      [editor1, editor2] = []

      beforeEach ->
        rootView.attachToDom()
        editor1 = rootView.activeEditor()
        editor2 = editor1.splitRight()
        expect(rootView.activeEditor()).toBe editor2
        rootView.trigger 'fuzzy-finder:toggle-file-finder'

      describe "when a path is highlighted", ->
        it "opens the file associated with that path in the editor", ->
          finder.trigger 'move-down'
          selectedLi = finder.find('li:eq(1)')

          expectedPath = rootView.project.resolve(selectedLi.text())
          expect(editor1.buffer.path).not.toBe expectedPath
          expect(editor2.buffer.path).not.toBe expectedPath

          finder.trigger 'fuzzy-finder:select-path'

          expect(finder.hasParent()).toBeFalsy()
          expect(editor1.buffer.path).not.toBe expectedPath
          expect(editor2.buffer.path).toBe expectedPath
          expect(editor2.isFocused).toBeTruthy()

      describe "when no paths are highlighted", ->
          it "does nothing", ->
            finder.miniEditor.insertText('this should match nothing, because no one wants to drink battery acid')
            finder.trigger 'fuzzy-finder:select-path'
            expect(finder.hasParent()).toBeTruthy()

  describe "buffer-finder behavior", ->
    describe "toggling", ->
      describe "when the active editor contains edit sessions for buffers with paths", ->
        beforeEach ->
          rootView.open('sample.txt')

        it "shows the FuzzyFinder or hides it and returns focus to the active editor if it already showing", ->
          rootView.attachToDom()
          expect(rootView.find('.fuzzy-finder')).not.toExist()
          rootView.find('.editor').trigger 'split-right'
          [editor1, editor2] = rootView.find('.editor').map -> $(this).view()

          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          expect(rootView.find('.fuzzy-finder')).toExist()
          expect(rootView.find('.fuzzy-finder input:focus')).toExist()
          finder.miniEditor.insertText('this should not show up next time we toggle')

          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          expect(editor1.isFocused).toBeFalsy()
          expect(editor2.isFocused).toBeTruthy()
          expect(rootView.find('.fuzzy-finder')).not.toExist()

          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          expect(finder.miniEditor.getText()).toBe ''

        it "lists the paths of the current editor's open buffers", ->
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          expect(finder.pathList.children('li').length).toBe 2
          expect(finder.pathList.find("li:contains(sample.js)")).toExist()
          expect(finder.pathList.find("li:contains(sample.txt)")).toExist()
          expect(finder.pathList.children().first()).toHaveClass 'selected'

      describe "when the active editor only contains edit sessions for anonymous buffers", ->
        it "does not open", ->
          editor = rootView.activeEditor()
          editor.edit(rootView.project.open())
          editor.loadPreviousEditSession()
          editor.removeActiveEditSession()
          expect(editor.getOpenBufferPaths().length).toBe 0
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          expect(rootView.find('.fuzzy-finder')).not.toExist()

      describe "when there is no active editor", ->
        it "does not open", ->
          rootView.activeEditor().removeActiveEditSession()
          expect(rootView.activeEditor()).toBeUndefined()
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          expect(rootView.find('.fuzzy-finder')).not.toExist()

    describe "selecting a path", ->
      [editor1, editor2] = []

      beforeEach ->
        rootView.attachToDom()
        editor1 = rootView.activeEditor()
        editor2 = editor1.splitRight()
        expect(rootView.activeEditor()).toBe editor2
        rootView.open('sample.txt')
        editor2.loadPreviousEditSession()
        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'

      describe "when a path is highlighted", ->
        describe "when the highlighted path is open in the active editor", ->
          it "switches the active editor to the edit session for the selected path", ->
            finder.moveDown()
            selectedLi = finder.findSelectedLi()
            expect(selectedLi.text()).toBe 'sample.txt'
            expectedPath = rootView.project.resolve('sample.txt')

            finder.trigger 'fuzzy-finder:select-path'

            expect(finder.hasParent()).toBeFalsy()
            expect(editor1.buffer.path).not.toBe expectedPath
            expect(editor2.buffer.path).toBe expectedPath
            expect(editor2.isFocused).toBeTruthy()

        describe "when the highlighted path is not open in the active editor, but instead is open on another editor", ->
          it "focuses the editor that contains an edit session for the selected path", ->
            rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
            editor1.focus()
            rootView.trigger 'fuzzy-finder:toggle-buffer-finder'

            expect(rootView.activeEditor()).toBe editor1

            finder.moveDown()
            selectedLi = finder.findSelectedLi()
            expect(selectedLi.text()).toBe 'sample.txt'
            expectedPath = rootView.project.resolve('sample.txt')

            finder.trigger 'fuzzy-finder:select-path'

            expect(finder.hasParent()).toBeFalsy()
            expect(editor1.buffer.path).not.toBe expectedPath
            expect(editor2.buffer.path).toBe expectedPath
            expect(editor2.isFocused).toBeTruthy()

  describe "common behavior between file and buffer finder", ->
    describe "when characters are typed into the input element", ->
      it "displays matching paths in the ol element and selects the first", ->
        rootView.trigger 'fuzzy-finder:toggle-file-finder'

        listLengthBefore = finder.pathList.children().length

        finder.miniEditor.insertText('samp')

        expect(finder.pathList.children().length).toBeLessThan(listLengthBefore)
        expect(finder.pathList.find('li:first')).toHaveClass 'selected'
        expect(finder.pathList.find('li.selected').length).toBe 1

        # we should clear the list before re-populating it
        finder.miniEditor.insertText('txt')

        expect(finder.pathList.children().length).toBe 1
        expect(finder.pathList.find('li:first')).toHaveClass 'selected'
        expect(finder.pathList.find('li:first')).toHaveText 'sample.txt'

    describe "move-down / move-up events", ->
      beforeEach ->
        rootView.trigger 'fuzzy-finder:toggle-file-finder'

      it "selects the next / previous path in the list", ->
        expect(finder.find('li:eq(0)')).toHaveClass "selected"
        expect(finder.find('li:eq(2)')).not.toHaveClass "selected"

        finder.miniEditor.trigger keydownEvent('down')
        finder.miniEditor.trigger keydownEvent('down')

        expect(finder.find('li:eq(0)')).not.toHaveClass "selected"
        expect(finder.find('li:eq(2)')).toHaveClass "selected"

        finder.miniEditor.trigger keydownEvent('up')

        expect(finder.find('li:eq(0)')).not.toHaveClass "selected"
        expect(finder.find('li:eq(1)')).toHaveClass "selected"
        expect(finder.find('li:eq(2)')).not.toHaveClass "selected"

      it "does not fall off the end or begining of the list", ->
        expect(finder.find('li:first')).toHaveClass "selected"
        finder.miniEditor.trigger keydownEvent('up')
        expect(finder.find('li:first')).toHaveClass "selected"

        for i in [1..finder.pathList.children().length+2]
          finder.miniEditor.trigger keydownEvent('down')

        expect(finder.find('li:last')).toHaveClass "selected"

    describe "when the fuzzy finder loses focus", ->
      it "detaches itself", ->
        rootView.attachToDom()
        rootView.trigger 'fuzzy-finder:toggle-file-finder'

        expect(finder.hasParent()).toBeTruthy()
        rootView.focus()
        expect(finder.hasParent()).toBeFalsy()

    describe "when the fuzzy finder is cancelled", ->
      it "hides the finder", ->
        rootView.trigger 'fuzzy-finder:toggle-file-finder'
        expect(finder.hasParent()).toBeTruthy()

        finder.trigger 'fuzzy-finder:cancel'
        expect(finder.hasParent()).toBeFalsy()

      it "focuses previously focused element", ->
        rootView.attachToDom()
        activeEditor = rootView.activeEditor()
        activeEditor.focus()

        rootView.trigger 'fuzzy-finder:toggle-file-finder'
        expect(activeEditor.isFocused).toBeFalsy()
        expect(finder.miniEditor.isFocused).toBeTruthy()

        finder.trigger 'fuzzy-finder:cancel'
        expect(activeEditor.isFocused).toBeTruthy()
        expect(finder.miniEditor.isFocused).toBeFalsy()

    describe ".findMatches(queryString)", ->
      beforeEach ->
        rootView.trigger 'fuzzy-finder:toggle-file-finder'

      it "returns up to finder.maxResults paths if queryString is empty", ->
        expect(finder.findMatches('').length).toBeLessThan finder.maxResults + 1
        finder.maxResults = 5
        expect(finder.findMatches('').length).toBeLessThan finder.maxResults + 1

      it "returns paths sorted by score of match against the given query", ->
        finder.paths = ["app.coffee", "atom/app.coffee"]
        expect(finder.findMatches('app.co')).toEqual ["app.coffee", "atom/app.coffee"]
        expect(finder.findMatches('atom/app.co')).toEqual ["atom/app.coffee"]
