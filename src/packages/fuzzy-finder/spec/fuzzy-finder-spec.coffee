RootView = require 'root-view'
FuzzyFinder = require 'fuzzy-finder/lib/fuzzy-finder-view'
PathLoader = require 'fuzzy-finder/lib/path-loader'
_ = require 'underscore'
$ = require 'jquery'
{$$} = require 'space-pen'
fsUtils = require 'fs-utils'
path = require 'path'

describe 'FuzzyFinder', ->
  [finderView] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    rootView.enableKeymap()
    finderView = atom.activatePackage("fuzzy-finder").mainModule.createView()

  describe "file-finder behavior", ->
    describe "toggling", ->
      describe "when the root view's project has a path", ->
        it "shows the FuzzyFinder or hides it and returns focus to the active editor if it already showing", ->
          rootView.attachToDom()
          expect(rootView.find('.fuzzy-finder')).not.toExist()
          rootView.getActiveView().splitRight()
          [editor1, editor2] = rootView.getEditors()

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
          expect(finderView.find(".loading").text().length).toBeGreaterThan 0

          waitsFor "all project paths to load", 5000, ->
            unless finderView.reloadProjectPaths
              paths = finderView.projectPaths
              true

          runs ->
            expect(paths.length).toBeGreaterThan 0
            expect(finderView.list.children('li').length).toBe paths.length
            for filePath in paths
              expect(finderView.list.find("li:contains(#{path.basename(filePath)})")).toExist()
            expect(finderView.list.children().first()).toHaveClass 'selected'
            expect(finderView.find(".loading")).not.toBeVisible()

        it "includes symlinked file paths", ->
          rootView.attachToDom()
          finderView.maxItems = Infinity
          rootView.trigger 'fuzzy-finder:toggle-file-finder'

          waitsFor "all project paths to load", 5000, ->
            not finderView.reloadProjectPaths

          runs ->
            expect(finderView.list.find("li:contains(symlink-to-file)")).toExist()

        it "excludes symlinked folder paths", ->
          rootView.attachToDom()
          finderView.maxItems = Infinity
          rootView.trigger 'fuzzy-finder:toggle-file-finder'

          waitsFor "all project paths to load", 5000, ->
            not finderView.reloadProjectPaths

          runs ->
            expect(finderView.list.find("li:contains(symlink-to-dir)")).not.toExist()

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
        editor1 = rootView.getActiveView()
        editor2 = editor1.splitRight()
        expect(rootView.getActiveView()).toBe editor2
        rootView.trigger 'fuzzy-finder:toggle-file-finder'

        expectedPath = project.resolve('dir/a')
        finderView.confirmed({filePath: expectedPath})

        expect(finderView.hasParent()).toBeFalsy()
        expect(editor1.getPath()).not.toBe expectedPath
        expect(editor2.getPath()).toBe expectedPath
        expect(editor2.isFocused).toBeTruthy()

      describe "when the selected path isn't a file that exists", ->
        it "leaves the the tree view open, doesn't open the path in the editor, and displays an error", ->
          rootView.attachToDom()
          editorPath = rootView.getActiveView().getPath()
          rootView.trigger 'fuzzy-finder:toggle-file-finder'
          finderView.confirmed({filePath: 'dir/this/is/not/a/file.txt'})
          expect(finderView.hasParent()).toBeTruthy()
          expect(rootView.getActiveView().getPath()).toBe editorPath
          expect(finderView.error.text().length).toBeGreaterThan 0
          advanceClock(2000)
          expect(finderView.error.text().length).toBe 0

  describe "buffer-finder behavior", ->
    describe "toggling", ->
      describe "when there are pane items with paths", ->
        beforeEach ->
          rootView.open('sample.txt')

        it "shows the FuzzyFinder if it isn't showing, or hides it and returns focus to the active editor", ->
          rootView.attachToDom()
          expect(rootView.find('.fuzzy-finder')).not.toExist()
          rootView.getActiveView().splitRight()
          [editor1, editor2] = rootView.getEditors()

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

        it "lists the paths of the current items, sorted by most recently opened but with the current item last", ->
          rootView.attachToDom()
          rootView.open 'sample-with-tabs.coffee'
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          expect(_.pluck(finderView.list.find('li > div.file'), 'outerText')).toEqual ['sample.txt', 'sample.js', 'sample-with-tabs.coffee']
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'

          rootView.open 'sample.txt'
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'

          expect(_.pluck(finderView.list.find('li > div.file'), 'outerText')).toEqual ['sample-with-tabs.coffee', 'sample.js', 'sample.txt']
          expect(finderView.list.children().first()).toHaveClass 'selected'

        it "serializes the list of paths and their last opened time", ->
          rootView.open 'sample-with-tabs.coffee'
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          rootView.open 'sample.js'
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          rootView.open()

          atom.deactivatePackage('fuzzy-finder')
          states = _.map atom.getPackageState('fuzzy-finder'), (path, time) -> [ path, time ]
          expect(states.length).toBe 3
          states = _.sortBy states, (path, time) -> -time

          paths = [ 'sample-with-tabs.coffee', 'sample.txt', 'sample.js' ]

          for [time, bufferPath] in states
            expect(_.last bufferPath.split '/').toBe paths.shift()
            expect(time).toBeGreaterThan 50000

      describe "when there are only panes with anonymous items", ->
        it "does not open", ->
          rootView.getActivePane().remove()
          rootView.open()
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          expect(rootView.find('.fuzzy-finder')).not.toExist()

      describe "when there are no pane items", ->
        it "does not open", ->
          rootView.getActivePane().remove()
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          expect(rootView.find('.fuzzy-finder')).not.toExist()

      describe "when multiple sessions are opened on the same path", ->
        it "does not display duplicates for that path in the list", ->
          rootView.open 'sample.js'
          rootView.getActivePane().splitRight()
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          expect(_.pluck(finderView.list.find('li > div.file'), 'outerText')).toEqual ['sample.js']

    describe "when a path selection is confirmed", ->
      [editor1, editor2] = []

      beforeEach ->
        rootView.attachToDom()
        editor1 = rootView.getActiveView()
        editor2 = editor1.splitRight()
        expect(rootView.getActiveView()).toBe editor2
        rootView.open('sample.txt')
        editor2.trigger 'pane:show-previous-item'
        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'

      describe "when the active pane has an item for the selected path", ->
        it "switches to the item for the selected path", ->
          expectedPath = project.resolve('sample.txt')
          finderView.confirmed({filePath: expectedPath})

          expect(finderView.hasParent()).toBeFalsy()
          expect(editor1.getPath()).not.toBe expectedPath
          expect(editor2.getPath()).toBe expectedPath
          expect(editor2.isFocused).toBeTruthy()

      describe "when the active pane does not have an item for the selected path", ->
        it "adds a new item to the active pane for the selcted path", ->
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
          editor1.focus()
          rootView.trigger 'fuzzy-finder:toggle-buffer-finder'

          expect(rootView.getActiveView()).toBe editor1

          expectedPath = project.resolve('sample.txt')
          finderView.confirmed({filePath: expectedPath})

          expect(finderView.hasParent()).toBeFalsy()
          expect(editor1.getPath()).toBe expectedPath
          expect(editor1.isFocused).toBeTruthy()

  describe "git-status-finder behavior", ->
    [originalText, originalPath, newPath] = []

    beforeEach ->
      editor = rootView.getActiveView()
      originalText = editor.getText()
      originalPath = editor.getPath()
      fsUtils.writeSync(originalPath, 'making a change for the better')
      project.getRepo().getPathStatus(originalPath)

      newPath = project.resolve('newsample.js')
      fsUtils.writeSync(newPath, '')
      project.getRepo().getPathStatus(newPath)

    afterEach ->
      fsUtils.writeSync(originalPath, originalText)
      fsUtils.remove(newPath) if fsUtils.exists(newPath)

    it "displays all new and modified paths", ->
      expect(rootView.find('.fuzzy-finder')).not.toExist()
      rootView.trigger 'fuzzy-finder:toggle-git-status-finder'
      expect(rootView.find('.fuzzy-finder')).toExist()

      expect(finderView.find('.file').length).toBe 2

      expect(finderView.find('.status.modified').length).toBe 1
      expect(finderView.find('.status.new').length).toBe 1

  describe "common behavior between file and buffer finder", ->
    describe "when the fuzzy finder is cancelled", ->
      describe "when an editor is open", ->
        it "detaches the finder and focuses the previously focused element", ->
          rootView.attachToDom()
          activeEditor = rootView.getActiveView()
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
          rootView.getActivePane().remove()

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
      spyOn(PathLoader, "startTask").andCallThrough()
      rootView.trigger 'fuzzy-finder:toggle-file-finder'

      waitsFor ->
        finderView.list.children('li').length > 0

      runs ->
        expect(PathLoader.startTask).toHaveBeenCalled()
        PathLoader.startTask.reset()
        rootView.trigger 'fuzzy-finder:toggle-file-finder'
        rootView.trigger 'fuzzy-finder:toggle-file-finder'

      waitsFor ->
        finderView.list.children('li').length > 0

      runs ->
        expect(PathLoader.startTask).not.toHaveBeenCalled()

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
      spyOn(PathLoader, "startTask").andCallThrough()
      rootView.trigger 'fuzzy-finder:toggle-file-finder'

      waitsFor ->
        finderView.list.children('li').length > 0

      runs ->
        expect(PathLoader.startTask).toHaveBeenCalled()
        PathLoader.startTask.reset()
        $(window).trigger 'focus'
        rootView.trigger 'fuzzy-finder:toggle-file-finder'
        rootView.trigger 'fuzzy-finder:toggle-file-finder'
        expect(PathLoader.startTask).toHaveBeenCalled()

  describe "path ignoring", ->
    it "ignores paths that match entries in config.fuzzyFinder.ignoredNames", ->
      config.set("fuzzyFinder.ignoredNames", ["tree-view.js"])
      rootView.trigger 'fuzzy-finder:toggle-file-finder'
      finderView.maxItems = Infinity

      waitsFor ->
        finderView.list.children('li').length > 0

      runs ->
        expect(finderView.list.find("li:contains(tree-view.js)")).not.toExist()

    describe "when core.excludeVcsIgnoredPaths is set to true", ->
      ignoreFile = null

      beforeEach ->
        ignoreFile = path.join(project.getPath(), '.gitignore')
        fsUtils.writeSync(ignoreFile, 'sample.js')
        config.set("core.excludeVcsIgnoredPaths", true)

      afterEach ->
        fsUtils.remove(ignoreFile) if fsUtils.exists(ignoreFile)

      it "ignores paths that are git ignored", ->
        rootView.trigger 'fuzzy-finder:toggle-file-finder'
        finderView.maxItems = Infinity

        waitsFor ->
          finderView.list.children('li').length > 0

        runs ->
          expect(finderView.list.find("li:contains(sample.js)")).not.toExist()

  describe "fuzzy find by content under cursor", ->
    editor = null

    beforeEach ->
      editor = rootView.getActiveView()
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
        expect(openedPath).toBe project.resolve("sample.txt")

    it "displays an error when the word under the cursor doesn't match any files", ->
      editor.setText("moogoogaipan")
      editor.setCursorBufferPosition([0,5])

      rootView.trigger 'fuzzy-finder:find-under-cursor'

      waitsFor ->
        finderView.is(':visible')

      runs ->
        expect(finderView.error.text().length).toBeGreaterThan 0

    it "displays error when there is no word under the cursor", ->
      editor.setText("&&&&&&&&&&&&&&& sample")
      editor.setCursorBufferPosition([0,5])

      rootView.trigger 'fuzzy-finder:find-under-cursor'

      waitsFor ->
        finderView.is(':visible')

      runs ->
        expect(finderView.error.text().length).toBeGreaterThan 0

  describe "opening a path into a split", ->
    it "opens the path by splitting the active editor left", ->
      expect(rootView.getPanes().length).toBe 1
      pane = rootView.getActivePane()
      spyOn(pane, "splitLeft").andCallThrough()

      rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
      {filePath} = finderView.getSelectedElement()
      finderView.miniEditor.trigger 'pane:split-left'

      expect(rootView.getPanes().length).toBe 2
      expect(pane.splitLeft).toHaveBeenCalled()
      expect(rootView.getActiveView().getPath()).toBe project.resolve(filePath)

    it "opens the path by splitting the active editor right", ->
      expect(rootView.getPanes().length).toBe 1
      pane = rootView.getActivePane()
      spyOn(pane, "splitRight").andCallThrough()

      rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
      {filePath} = finderView.getSelectedElement()
      finderView.miniEditor.trigger 'pane:split-right'

      expect(rootView.getPanes().length).toBe 2
      expect(pane.splitRight).toHaveBeenCalled()
      expect(rootView.getActiveView().getPath()).toBe project.resolve(filePath)

    it "opens the path by splitting the active editor up", ->
      expect(rootView.getPanes().length).toBe 1
      pane = rootView.getActivePane()
      spyOn(pane, "splitUp").andCallThrough()

      rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
      {filePath} = finderView.getSelectedElement()
      finderView.miniEditor.trigger 'pane:split-up'

      expect(rootView.getPanes().length).toBe 2
      expect(pane.splitUp).toHaveBeenCalled()
      expect(rootView.getActiveView().getPath()).toBe project.resolve(filePath)

    it "opens the path by splitting the active editor down", ->
      expect(rootView.getPanes().length).toBe 1
      pane = rootView.getActivePane()
      spyOn(pane, "splitDown").andCallThrough()

      rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
      {filePath} = finderView.getSelectedElement()
      finderView.miniEditor.trigger 'pane:split-down'

      expect(rootView.getPanes().length).toBe 2
      expect(pane.splitDown).toHaveBeenCalled()
      expect(rootView.getActiveView().getPath()).toBe project.resolve(filePath)

  describe "git status decorations", ->
    [originalText, originalPath, editor, newPath] = []

    beforeEach ->
      editor = rootView.getActiveView()
      originalText = editor.getText()
      originalPath = editor.getPath()
      newPath = project.resolve('newsample.js')
      fsUtils.writeSync(newPath, '')

    afterEach ->
      fsUtils.writeSync(originalPath, originalText)
      fsUtils.remove(newPath) if fsUtils.exists(newPath)

    describe "when a modified file is shown in the list", ->
      it "displays the modified icon", ->
        editor.setText('modified')
        editor.activeEditSession.save()
        project.getRepo().getPathStatus(editor.getPath())

        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
        expect(finderView.find('.status.modified').length).toBe 1
        expect(finderView.find('.status.modified').closest('li').find('.file').text()).toBe 'sample.js'


    describe "when a new file is shown in the list", ->
      it "displays the new icon", ->
        rootView.open('newsample.js')
        project.getRepo().getPathStatus(editor.getPath())

        rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
        expect(finderView.find('.status.new').length).toBe 1
        expect(finderView.find('.status.new').closest('li').find('.file').text()).toBe 'newsample.js'

  describe "when the filter text contains a colon followed by a number", ->
    it "opens the selected path to that line number", ->
      rootView.attachToDom()
      expect(rootView.find('.fuzzy-finder')).not.toExist()
      [editor] = rootView.getEditors()
      expect(editor.getCursorBufferPosition()).toEqual [0, 0]

      rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
      expect(rootView.find('.fuzzy-finder')).toExist()
      finderView.miniEditor.insertText(':4')
      finderView.trigger 'core:confirm'

      expect(editor.getCursorBufferPosition()).toEqual [3, 4]

      rootView.trigger 'fuzzy-finder:toggle-buffer-finder'
      expect(rootView.find('.fuzzy-finder')).toExist()
      finderView.miniEditor.insertText(':10')
      finderView.miniEditor.trigger 'pane:split-left'

      expect(rootView.getActiveView()).not.toBe editor
      expect(rootView.getActiveView().getCursorBufferPosition()).toEqual [9, 2]
