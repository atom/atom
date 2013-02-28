RootView = require 'root-view'
FuzzyFinder = require 'fuzzy-finder/lib/fuzzy-finder-view'
LoadPathsTask = require 'fuzzy-finder/lib/load-paths-task'
_ = require 'underscore'
$ = require 'jquery'
{$$} = require 'space-pen'
fs = require 'fs'

describe 'FuzzyFinder', ->
  [finderView] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    rootView.enableKeymap()
    finderView = window.loadPackage("fuzzy-finder").packageMain.createView()

  describe "file-finder behavior", ->
    describe "toggling", ->
      describe "when the root view's project has a path", ->
        it "shows the FuzzyFinder or hides it and returns focus to the active editor if it already showing", ->
          rootView.attachToDom()
          expect(rootView.find('.fuzzy-finder')).not.toExist()
          rootView.find('.editor').trigger 'editor:split-right'
          [editor1, editor2] = rootView.find('.editor').map -> $(this).view()

          expect(rootView.find('.fuzzy-finder')).not.toExist()
          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          expect(rootView.find('.fuzzy-finder')).toExist()
          expect(finderView.miniEditor.isFocused).toBeTruthy()
          expect(editor1.isFocused).toBeFalsy()
          expect(editor2.isFocused).toBeFalsy()
          finderView.miniEditor.insertText('this should not show up next time we toggle')

          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          expect(editor1.isFocused).toBeFalsy()
          expect(editor2.isFocused).toBeTruthy()
          expect(rootView.find('.fuzzy-finder')).not.toExist()

          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          expect(finderView.miniEditor.getText()).toBe ''

        it "shows all relative file paths for the current project and selects the first", ->
          rootView.attachToDom()
          finderView.maxItems = Infinity
          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          paths = null
          expect(finderView.find(".loading")).toBeVisible()
          expect(finderView.find(".loading")).toHaveText "Indexing..."

          waitsFor "all project paths to load", 5000, ->
            if finderView.projectPaths?.length > 0
              paths = finderView.projectPaths
              true

          runs ->
            expect(finderView.list.children('li').length).toBe paths.length
            for path in paths
              expect(finderView.list.find("li:contains(#{fs.base(path)})")).toExist()
            expect(finderView.list.children().first()).toHaveClass 'selected'
            expect(finderView.find(".loading")).not.toBeVisible()

      describe "when root view's project has no path", ->
        beforeEach ->
          project.setPath(null)

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

        finderView.confirmed('dir/a')
        expectedPath = fixturesProject.resolve('dir/a')

        expect(finderView.hasParent()).toBeFalsy()
        expect(editor1.getPath()).not.toBe expectedPath
        expect(editor2.getPath()).toBe expectedPath
        expect(editor2.isFocused).toBeTruthy()

      describe "when the selected path isn't a file that exists", ->
        it "leaves the the tree view open, doesn't open the path in the editor, and displays an error", ->
          rootView.attachToDom()
          path = rootView.getActiveEditor().getPath()
          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          finderView.confirmed('dir/this/is/not/a/file.txt')
          expect(finderView.hasParent()).toBeTruthy()
          expect(rootView.getActiveEditor().getPath()).toBe path
          expect(finderView.find('.error').text().length).toBeGreaterThan 0
          advanceClock(2000)
          expect(finderView.find('.error').text().length).toBe 0

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
          finderView.miniEditor.insertText('this should not show up next time we toggle')

          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          expect(editor1.isFocused).toBeFalsy()
          expect(editor2.isFocused).toBeTruthy()
          expect(rootView.find('.fuzzy-finder')).not.toExist()

          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          expect(finderView.miniEditor.getText()).toBe ''

        it "lists the paths of the current open buffers by most recently modified", ->
          rootView.attachToDom()
          rootView.open 'sample-with-tabs.coffee'
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          children = finderView.list.children('li')
          expect(children.get(0).outerText).toBe "sample.txt"
          expect(children.get(1).outerText).toBe "sample.js"
          expect(children.get(2).outerText).toBe "sample-with-tabs.coffee"

          rootView.open 'sample.txt'
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          children = finderView.list.children('li')
          expect(children.get(0).outerText).toBe "sample-with-tabs.coffee"
          expect(children.get(1).outerText).toBe "sample.js"
          expect(children.get(2).outerText).toBe "sample.txt"

          expect(finderView.list.children('li').length).toBe 3
          expect(finderView.list.find("li:contains(sample.js)")).toExist()
          expect(finderView.list.find("li:contains(sample.txt)")).toExist()
          expect(finderView.list.find("li:contains(sample-with-tabs.coffee)")).toExist()
          expect(finderView.list.children().first()).toHaveClass 'selected'

        it "serializes the list of paths and their last opened time", ->
          rootView.open 'sample-with-tabs.coffee'
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          rootView.open 'sample.js'
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          rootView.open()

          states = rootView.serialize().packageStates
          states = _.map states['fuzzy-finder'], (path, time) -> [ path, time ]
          states = _.sortBy states, (path, time) -> -time

          paths = [ 'sample-with-tabs.coffee', 'sample.txt', 'sample.js' ]
          for [time, path] in states
            expect(_.last path.split '/').toBe paths.shift()
            expect(time).toBeGreaterThan 50000

      describe "when the active editor only contains edit sessions for anonymous buffers", ->
        it "does not open", ->
          editor = rootView.getActiveEditor()
          editor.edit(project.buildEditSessionForPath())
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
          finderView.confirmed('sample.txt')

          expect(finderView.hasParent()).toBeFalsy()
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
          finderView.confirmed('sample.txt')

          expect(finderView.hasParent()).toBeFalsy()
          expect(editor1.getPath()).not.toBe expectedPath
          expect(editor2.getPath()).toBe expectedPath
          expect(editor2.isFocused).toBeTruthy()

  describe "common behavior between file and buffer finder", ->
    describe "when the fuzzy finder is cancelled", ->
      describe "when an editor is open", ->
        it "detaches the finder and focuses the previously focused element", ->
          rootView.attachToDom()
          activeEditor = rootView.getActiveEditor()
          activeEditor.focus()

          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          expect(finderView.hasParent()).toBeTruthy()
          expect(activeEditor.isFocused).toBeFalsy()
          expect(finderView.miniEditor.isFocused).toBeTruthy()

          finderView.cancel()

          expect(finderView.hasParent()).toBeFalsy()
          expect(activeEditor.isFocused).toBeTruthy()
          expect(finderView.miniEditor.isFocused).toBeFalsy()

      describe "when no editors are open", ->
        it "detaches the finder and focuses the previously focused element", ->
          rootView.attachToDom()
          rootView.getActiveEditor().destroyActiveEditSession()

          inputView = $$ -> @input()
          rootView.append(inputView)
          inputView.focus()

          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          expect(finderView.hasParent()).toBeTruthy()
          expect(finderView.miniEditor.isFocused).toBeTruthy()

          finderView.cancel()

          expect(finderView.hasParent()).toBeFalsy()
          expect(document.activeElement).toBe inputView[0]
          expect(finderView.miniEditor.isFocused).toBeFalsy()

  describe "cached file paths", ->
    it "caches file paths after first time", ->
      spyOn(LoadPathsTask.prototype, "start").andCallThrough()
      rootView.trigger 'fuzzy-finder:toggle-file-finder'

      waitsFor ->
        finderView.list.children('li').length > 0

      runs ->
        expect(finderView.loadPathsTask.start).toHaveBeenCalled()
        finderView.loadPathsTask.start.reset()
        rootView.trigger 'fuzzy-finder:toggle-file-finder'
        rootView.trigger 'fuzzy-finder:toggle-file-finder'

      waitsFor ->
        finderView.list.children('li').length > 0

      runs ->
        expect(finderView.loadPathsTask.start).not.toHaveBeenCalled()

    it "doesn't cache buffer paths", ->
      spyOn(project, "getEditSessions").andCallThrough()
      rootView.trigger 'fuzzy-finder:toggle-buffer-finder'

      waitsFor ->
        finderView.list.children('li').length > 0

      runs ->
        expect(project.getEditSessions).toHaveBeenCalled()
        project.getEditSessions.reset()
        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'

      waitsFor ->
        finderView.list.children('li').length > 0

      runs ->
        expect(project.getEditSessions).toHaveBeenCalled()

    it "busts the cache when the window gains focus", ->
      spyOn(LoadPathsTask.prototype, "start").andCallThrough()
      rootView.trigger 'fuzzy-finder:toggle-file-finder'

      waitsFor ->
        finderView.list.children('li').length > 0

      runs ->
        expect(finderView.loadPathsTask.start).toHaveBeenCalled()
        finderView.loadPathsTask.start.reset()
        $(window).trigger 'focus'
        rootView.trigger 'fuzzy-finder:toggle-file-finder'
        rootView.trigger 'fuzzy-finder:toggle-file-finder'
        expect(finderView.loadPathsTask.start).toHaveBeenCalled()

  describe "path ignoring", ->
    it "ignores paths that match entries in config.fuzzyFinder.ignoredNames", ->
      config.set("fuzzyFinder.ignoredNames", ["tree-view.js"])
      rootView.trigger 'fuzzy-finder:toggle-file-finder'
      finderView.maxItems = Infinity

      waitsFor ->
        finderView.list.children('li').length > 0

      runs ->
        expect(finderView.list.find("li:contains(tree-view.js)")).not.toExist()

  describe "fuzzy find by content under cursor", ->
    editor = null

    beforeEach ->
      editor = rootView.getActiveEditor()
      rootView.attachToDom()

    it "opens the fuzzy finder window when there are multiple matches", ->
      editor.setText("sample")
      rootView.trigger 'fuzzy-finder:find-under-cursor'

      waitsFor ->
        finderView.list.children('li').length > 0

      runs ->
        expect(finderView).toBeVisible()
        expect(rootView.find('.fuzzy-finder input:focus')).toExist()

    it "opens a file directly when there is a single match", ->
      editor.setText("sample.txt")
      rootView.trigger 'fuzzy-finder:find-under-cursor'

      openedPath = null
      spyOn(rootView, "open").andCallFake (path) ->
        openedPath = path

      waitsFor ->
        openedPath != null

      runs ->
        expect(finderView).not.toBeVisible()
        expect(openedPath).toBe "sample.txt"

    it "displays error when the word under the cursor doesn't match any files", ->
      editor.setText("moogoogaipan")
      editor.setCursorBufferPosition([0,5])

      rootView.trigger 'fuzzy-finder:find-under-cursor'

      waitsFor ->
        finderView.is(':visible')

      runs ->
        expect(finderView.find('.error').text().length).toBeGreaterThan 0

    it "displays error when there is no word under the cursor", ->
      editor.setText("&&&&&&&&&&&&&&& sample")
      editor.setCursorBufferPosition([0,5])

      rootView.trigger 'fuzzy-finder:find-under-cursor'

      waitsFor ->
        finderView.is(':visible')

      runs ->
        expect(finderView.find('.error').text().length).toBeGreaterThan 0

  describe "opening a path into a split", ->
    beforeEach ->
      rootView.attachToDom()

    describe "when an editor is active", ->
      it "opens the path by splitting the active editor left", ->
        editor = rootView.getActiveEditor()
        spyOn(editor, "splitLeft").andCallThrough()
        expect(rootView.find('.editor').length).toBe 1
        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
        finderView.miniEditor.trigger 'editor:split-left'
        expect(rootView.find('.editor').length).toBe 2
        expect(editor.splitLeft).toHaveBeenCalled()
        expect(rootView.getActiveEditor()).not.toBe editor
        expect(rootView.getActiveEditor().getPath()).toBe editor.getPath()

      it "opens the path by splitting the active editor right", ->
        editor = rootView.getActiveEditor()
        spyOn(editor, "splitRight").andCallThrough()
        expect(rootView.find('.editor').length).toBe 1
        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
        finderView.miniEditor.trigger 'editor:split-right'
        expect(rootView.find('.editor').length).toBe 2
        expect(editor.splitRight).toHaveBeenCalled()
        expect(rootView.getActiveEditor()).not.toBe editor
        expect(rootView.getActiveEditor().getPath()).toBe editor.getPath()

      it "opens the path by splitting the active editor down", ->
        editor = rootView.getActiveEditor()
        spyOn(editor, "splitDown").andCallThrough()
        expect(rootView.find('.editor').length).toBe 1
        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
        finderView.miniEditor.trigger 'editor:split-down'
        expect(rootView.find('.editor').length).toBe 2
        expect(editor.splitDown).toHaveBeenCalled()
        expect(rootView.getActiveEditor()).not.toBe editor
        expect(rootView.getActiveEditor().getPath()).toBe editor.getPath()

      it "opens the path by splitting the active editor up", ->
        editor = rootView.getActiveEditor()
        spyOn(editor, "splitUp").andCallThrough()
        expect(rootView.find('.editor').length).toBe 1
        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
        finderView.miniEditor.trigger 'editor:split-up'
        expect(rootView.find('.editor').length).toBe 2
        expect(editor.splitUp).toHaveBeenCalled()
        expect(rootView.getActiveEditor()).not.toBe editor
        expect(rootView.getActiveEditor().getPath()).toBe editor.getPath()

  describe "git status decorations", ->
    [originalText, originalPath, editor, newPath] = []

    beforeEach ->
      editor = rootView.getActiveEditor()
      originalText = editor.getText()
      originalPath = editor.getPath()
      newPath = project.resolve('newsample.js')
      fs.write(newPath, '')

    afterEach ->
      fs.write(originalPath, originalText)
      fs.remove(newPath) if fs.exists(newPath)

    describe "when a modified file is shown in the list", ->
      it "displays the modified icon", ->
        editor.setText('modified')
        editor.save()
        project.repo?.getPathStatus(editor.getPath())

        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
        expect(finderView.find('.file.modified').length).toBe 1
        expect(finderView.find('.file.modified').text()).toBe 'sample.js'


    describe "when a new file is shown in the list", ->
      it "displays the new icon", ->
        rootView.open('newsample.js')
        project.repo?.getPathStatus(editor.getPath())

        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
        expect(finderView.find('.file.new').length).toBe 1
        expect(finderView.find('.file.new').text()).toBe 'newsample.js'
