RootView = require 'root-view'
FuzzyFinder = require 'fuzzy-finder'
$ = require 'jquery'
{$$} = require 'space-pen'
fs = require 'fs'

describe 'FuzzyFinder', ->
  [rootView, finder] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    rootView.enableKeymap()
    atom.loadPackage("fuzzy-finder")
    finder = FuzzyFinder.instance

  afterEach ->
    rootView.remove()

  describe "file-finder behavior", ->
    describe "toggling", ->
      describe "when the root view's project has a path", ->
        it "shows the FuzzyFinder or hides it and returns focus to the active editor if it already showing", ->
          rootView.attachToDom()
          expect(rootView.find('.fuzzy-finder')).not.toExist()
          rootView.find('.editor').trigger 'editor:split-right'
          [editor1, editor2] = rootView.find('.editor').map -> $(this).view()

          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          expect(rootView.find('.fuzzy-finder')).toExist()
          expect(finder.miniEditor.isFocused).toBeTruthy()
          expect(editor1.isFocused).toBeFalsy()
          expect(editor2.isFocused).toBeFalsy()
          finder.miniEditor.insertText('this should not show up next time we toggle')

          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          expect(editor1.isFocused).toBeFalsy()
          expect(editor2.isFocused).toBeTruthy()
          expect(rootView.find('.fuzzy-finder')).not.toExist()

          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          expect(finder.miniEditor.getText()).toBe ''

        it "shows all relative file paths for the current project and selects the first", ->
          rootView.attachToDom()
          finder.maxItems = Infinity
          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          paths = null
          expect(finder.find(".loading")).toBeVisible()
          expect(finder.find(".loading")).toHaveText "Indexing..."

          waitsForPromise ->
            rootView.project.getFilePaths().done (foundPaths) -> paths = foundPaths

          waitsFor ->
            finder.list.children('li').length > 0

          runs ->
            expect(finder.list.children('li').length).toBe paths.length, finder.maxResults
            for path in paths
              expect(finder.list.find("li:contains(#{fs.base(path)})")).toExist()
            expect(finder.list.children().first()).toHaveClass 'selected'
            expect(finder.find(".loading")).not.toBeVisible()

      describe "when root view's project has no path", ->
        beforeEach ->
          rootView.project.setPath(null)

        it "does not open the FuzzyFinder", ->
          expect(rootView.find('.fuzzy-finder')).not.toExist()
          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          expect(rootView.find('.fuzzy-finder')).not.toExist()

    describe "when a path selection is confirmed", ->
      it "opens the file associated with that path in the editor", ->
        rootView.attachToDom()
        editor1 = rootView.getActiveEditor()
        editor2 = editor1.splitRight()
        expect(rootView.getActiveEditor()).toBe editor2
        rootView.trigger 'fuzzy-finder:toggle-file-finder'

        finder.confirmed('dir/a')
        expectedPath = fixturesProject.resolve('dir/a')

        expect(finder.hasParent()).toBeFalsy()
        expect(editor1.getPath()).not.toBe expectedPath
        expect(editor2.getPath()).toBe expectedPath
        expect(editor2.isFocused).toBeTruthy()

  describe "buffer-finder behavior", ->
    describe "toggling", ->
      describe "when the active editor contains edit sessions for buffers with paths", ->
        beforeEach ->
          rootView.open('sample.txt')

        it "shows the FuzzyFinder or hides it, returning focus to the active editor if", ->
          rootView.attachToDom()
          expect(rootView.find('.fuzzy-finder')).not.toExist()
          rootView.find('.editor').trigger 'editor:split-right'
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

        it "lists the paths of the current open buffers", ->
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          expect(finder.list.children('li').length).toBe 2
          expect(finder.list.find("li:contains(sample.js)")).toExist()
          expect(finder.list.find("li:contains(sample.txt)")).toExist()
          expect(finder.list.children().first()).toHaveClass 'selected'

      describe "when the active editor only contains edit sessions for anonymous buffers", ->
        it "does not open", ->
          editor = rootView.getActiveEditor()
          editor.edit(rootView.project.buildEditSessionForPath())
          editor.loadPreviousEditSession()
          editor.destroyActiveEditSession()
          expect(editor.getOpenBufferPaths().length).toBe 0
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          expect(rootView.find('.fuzzy-finder')).not.toExist()

      describe "when there is no active editor", ->
        it "does not open", ->
          rootView.getActiveEditor().destroyActiveEditSession()
          expect(rootView.getActiveEditor()).toBeUndefined()
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          expect(rootView.find('.fuzzy-finder')).not.toExist()

    describe "when a path selection is confirmed", ->
      [editor1, editor2] = []

      beforeEach ->
        rootView.attachToDom()
        editor1 = rootView.getActiveEditor()
        editor2 = editor1.splitRight()
        expect(rootView.getActiveEditor()).toBe editor2
        rootView.open('sample.txt')
        editor2.loadPreviousEditSession()
        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'

      describe "when there is an edit session for the confirmed path in the active editor", ->
        it "switches the active editor to the edit session for the selected path", ->
          expectedPath = fixturesProject.resolve('sample.txt')
          finder.confirmed('sample.txt')

          expect(finder.hasParent()).toBeFalsy()
          expect(editor1.getPath()).not.toBe expectedPath
          expect(editor2.getPath()).toBe expectedPath
          expect(editor2.isFocused).toBeTruthy()

      describe "when there is NO edit session for the confirmed path on the active editor, but there is one on another editor", ->
        it "focuses the editor that contains an edit session for the selected path", ->
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          editor1.focus()
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'

          expect(rootView.getActiveEditor()).toBe editor1

          expectedPath = fixturesProject.resolve('sample.txt')
          finder.confirmed('sample.txt')

          expect(finder.hasParent()).toBeFalsy()
          expect(editor1.getPath()).not.toBe expectedPath
          expect(editor2.getPath()).toBe expectedPath
          expect(editor2.isFocused).toBeTruthy()

  describe "common behavior between file and buffer finder", ->
    describe "when the fuzzy finder is cancelled", ->
      it "detaches the finder and focuses the previously focused element", ->
        rootView.attachToDom()
        activeEditor = rootView.getActiveEditor()
        activeEditor.focus()

        rootView.trigger 'fuzzy-finder:toggle-file-finder'
        expect(finder.hasParent()).toBeTruthy()
        expect(activeEditor.isFocused).toBeFalsy()
        expect(finder.miniEditor.isFocused).toBeTruthy()

        finder.cancel()

        expect(finder.hasParent()).toBeFalsy()
        expect(activeEditor.isFocused).toBeTruthy()
        expect(finder.miniEditor.isFocused).toBeFalsy()

  describe "cached file paths", ->
    it "caches file paths after first time", ->
      spyOn(rootView.project, "getFilePaths").andCallThrough()
      rootView.trigger 'fuzzy-finder:toggle-file-finder'

      waitsFor ->
        finder.list.children('li').length > 0

      runs ->
        expect(rootView.project.getFilePaths).toHaveBeenCalled()
        rootView.project.getFilePaths.reset()
        rootView.trigger 'fuzzy-finder:toggle-file-finder'
        rootView.trigger 'fuzzy-finder:toggle-file-finder'

      waitsFor ->
        finder.list.children('li').length > 0

      runs ->
        expect(rootView.project.getFilePaths).not.toHaveBeenCalled()

    it "doesn't cache buffer paths", ->
      spyOn(rootView.project, "getFilePaths").andCallThrough()
      rootView.trigger 'fuzzy-finder:toggle-buffer-finder'

      waitsFor ->
        finder.list.children('li').length > 0

      runs ->
        expect(rootView.project.getFilePaths).not.toHaveBeenCalled()
        rootView.project.getFilePaths.reset()
        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
        rootView.trigger 'fuzzy-finder:toggle-file-finder'

      waitsFor ->
        finder.list.children('li').length > 0

      runs ->
        expect(rootView.project.getFilePaths).toHaveBeenCalled()

    it "busts the cache when the window gains focus", ->
      spyOn(rootView.project, "getFilePaths").andCallThrough()
      rootView.trigger 'fuzzy-finder:toggle-file-finder'

      waitsFor ->
        finder.list.children('li').length > 0

      runs ->
        expect(rootView.project.getFilePaths).toHaveBeenCalled()
        rootView.project.getFilePaths.reset()
        $(window).trigger 'focus'
        rootView.trigger 'fuzzy-finder:toggle-file-finder'
        rootView.trigger 'fuzzy-finder:toggle-file-finder'

      waitsFor ->
        finder.list.children('li').length > 0

      runs ->
        expect(rootView.project.getFilePaths).toHaveBeenCalled()

  describe "path ignoring", ->
    it "ignores paths that match entries in config.fuzzyFinder.ignoredNames", ->
      spyOn(rootView.project, "getFilePaths").andCallThrough()
      config.set("fuzzyFinder.ignoredNames", ["tree-view.js"])
      rootView.trigger 'fuzzy-finder:toggle-file-finder'
      finder.maxItems = Infinity

      waitsFor ->
        finder.list.children('li').length > 0

      runs ->
        expect(finder.list.find("li:contains(tree-view.js)")).not.toExist()

  describe "opening a path into a split", ->
    beforeEach ->
      rootView.attachToDom()

    describe "when an editor is active", ->
      it "opens the path by splitting the active editor left", ->
        editor = rootView.getActiveEditor()
        spyOn(editor, "splitLeft").andCallThrough()
        expect(rootView.find('.editor').length).toBe 1
        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
        finder.miniEditor.trigger 'editor:split-left'
        expect(rootView.find('.editor').length).toBe 2
        expect(editor.splitLeft).toHaveBeenCalled()
        expect(rootView.getActiveEditor()).not.toBe editor
        expect(rootView.getActiveEditor().getPath()).toBe editor.getPath()

      it "opens the path by splitting the active editor right", ->
        editor = rootView.getActiveEditor()
        spyOn(editor, "splitRight").andCallThrough()
        expect(rootView.find('.editor').length).toBe 1
        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
        finder.miniEditor.trigger 'editor:split-right'
        expect(rootView.find('.editor').length).toBe 2
        expect(editor.splitRight).toHaveBeenCalled()
        expect(rootView.getActiveEditor()).not.toBe editor
        expect(rootView.getActiveEditor().getPath()).toBe editor.getPath()

      it "opens the path by splitting the active editor down", ->
        editor = rootView.getActiveEditor()
        spyOn(editor, "splitDown").andCallThrough()
        expect(rootView.find('.editor').length).toBe 1
        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
        finder.miniEditor.trigger 'editor:split-down'
        expect(rootView.find('.editor').length).toBe 2
        expect(editor.splitDown).toHaveBeenCalled()
        expect(rootView.getActiveEditor()).not.toBe editor
        expect(rootView.getActiveEditor().getPath()).toBe editor.getPath()

      it "opens the path by splitting the active editor up", ->
        editor = rootView.getActiveEditor()
        spyOn(editor, "splitUp").andCallThrough()
        expect(rootView.find('.editor').length).toBe 1
        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
        finder.miniEditor.trigger 'editor:split-up'
        expect(rootView.find('.editor').length).toBe 2
        expect(editor.splitUp).toHaveBeenCalled()
        expect(rootView.getActiveEditor()).not.toBe editor
        expect(rootView.getActiveEditor().getPath()).toBe editor.getPath()
