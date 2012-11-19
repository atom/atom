$ = require 'jquery'
_ = require 'underscore'
TreeView = require 'tree-view'
RootView = require 'root-view'
Directory = require 'directory'
Native = require 'native'
fs = require 'fs'

describe "TreeView", ->
  [rootView, project, treeView, sampleJs, sampleTxt] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/tree-view'))
    project = rootView.project

    rootView.activateExtension(TreeView)
    treeView = rootView.find(".tree-view").view()
    treeView.root = treeView.find('> li:first').view()
    sampleJs = treeView.find('.file:contains(tree-view.js)')
    sampleTxt = treeView.find('.file:contains(tree-view.txt)')

    expect(treeView.root.directory.subscriptionCount()).toBeGreaterThan 0

  afterEach ->
    rootView?.deactivate()

  describe ".initialize(project)", ->
    it "renders the root of the project and its contents alphabetically with subdirectories first in a collapsed state", ->
      expect(treeView.root.find('> .header .disclosure-arrow')).toHaveText('▾')
      expect(treeView.root.find('> .header .name')).toHaveText('tree-view/')

      rootEntries = treeView.root.find('.entries')
      subdir0 = rootEntries.find('> li:eq(0)')
      expect(subdir0.find('.disclosure-arrow')).toHaveText('▸')
      expect(subdir0.find('.name')).toHaveText('dir1/')
      expect(subdir0.find('.entries')).not.toExist()

      subdir2 = rootEntries.find('> li:eq(1)')
      expect(subdir2.find('.disclosure-arrow')).toHaveText('▸')
      expect(subdir2.find('.name')).toHaveText('dir2/')
      expect(subdir2.find('.entries')).not.toExist()

      expect(rootEntries.find('> .file:contains(tree-view.js)')).toExist()
      expect(rootEntries.find('> .file:contains(tree-view.txt)')).toExist()

    it "selects the rootview", ->
      expect(treeView.selectedEntry()).toEqual treeView.root

    describe "when the project has no path", ->
      beforeEach ->
        rootView.deactivate()

        rootView = new RootView
        rootView.activateExtension(TreeView)
        treeView = rootView.find(".tree-view").view()

      it "does not create a root node", ->
        expect(treeView.root).not.toExist()

      it "serializes without throwing an exception", ->
        expect(-> treeView.serialize()).not.toThrow()

      it "creates a root view when the project path is created", ->
        rootView.open(require.resolve('fixtures/sample.js'))
        expect(treeView.root.getPath()).toBe require.resolve('fixtures')
        expect(treeView.root.parent()).toMatchSelector(".tree-view")

        oldRoot = treeView.root

        rootView.project.setPath('/tmp')
        expect(treeView.root).not.toEqual oldRoot
        expect(oldRoot.hasParent()).toBeFalsy()

  describe "when the prototypes deactivate method is called", ->
    it "calls the deactivate on tree view instance", ->
      spyOn(treeView, "deactivate").andCallThrough()
      rootView.deactivateExtension(TreeView)
      expect(treeView.deactivate).toHaveBeenCalled()

  describe "serialization", ->
    [newRootView, newTreeView] = []

    afterEach ->
      newRootView?.deactivate()

    it "restores expanded directories and selected file when deserialized", ->
      treeView.find('.directory:contains(dir1)').click()
      sampleJs.click()
      newRootView = RootView.deserialize(rootView.serialize())
      rootView.deactivate() # Deactivates previous TreeView

      newRootView.activateExtension(TreeView)

      newTreeView = newRootView.find(".tree-view").view()

      expect(newTreeView).toExist()
      expect(newTreeView.selectedEntry()).toMatchSelector(".file:contains(tree-view.js)")
      expect(newTreeView.find(".directory:contains(dir1)")).toHaveClass("expanded")

    it "restores the focus state of the tree view", ->
      rootView.attachToDom()
      treeView.focus()
      expect(treeView).toMatchSelector ':focus'

      newRootView = RootView.deserialize(rootView.serialize())
      rootView.deactivate() # Deactivates previous TreeView

      newRootView.attachToDom()
      newRootView.activateExtension(TreeView)

      newTreeView = newRootView.find(".tree-view").view()
      expect(newTreeView).toMatchSelector ':focus'

    it "restores the scroll top when toggled", ->
      rootView.height(5)
      rootView.attachToDom()
      expect(treeView).toBeVisible()
      treeView.focus()

      treeView.scrollTop(10)
      expect(treeView.scrollTop()).toBe(10)

      rootView.trigger 'tree-view:toggle'
      expect(treeView).toBeHidden()
      rootView.trigger 'tree-view:toggle'
      expect(treeView).toBeVisible()
      expect(treeView.scrollTop()).toBe(10)

  describe "when tree-view:toggle is triggered on the root view", ->
    beforeEach ->
      rootView.attachToDom()

    describe "when the tree view is visible", ->
      beforeEach ->
        expect(treeView).toBeVisible()

      describe "when the tree view is focused", ->
        it "hides the tree view", ->
          treeView.focus()
          rootView.trigger 'tree-view:toggle'
          expect(treeView).toBeHidden()

      describe "when the tree view is not focused", ->
        it "shifts focus to the tree view", ->
          rootView.open() # When we call focus below, we want an editor to become focused
          rootView.focus()
          rootView.trigger 'tree-view:toggle'
          expect(treeView).toBeVisible()
          expect(treeView).toMatchSelector(':focus')

    describe "when the tree view is hidden", ->
      it "shows and focuses the tree view", ->
        treeView.detach()
        rootView.trigger 'tree-view:toggle'
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView).toMatchSelector(':focus')

  describe "when tree-view:reveal-current-file is triggered on the root view", ->
    beforeEach ->
      treeView.detach()
      spyOn(treeView, 'focus')

    describe "if the current file has a path", ->
      it "shows and focuses the tree view and selects the file", ->
        rootView.open('dir1/file1')
        rootView.trigger 'tree-view:reveal-active-file'
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.focus).toHaveBeenCalled()
        expect(treeView.selectedEntry().getPath()).toMatch /dir1\/file1$/

    describe "if the current file has no path", ->
      it "shows and focuses the tree view, but does not attempt to select a specific file", ->
        rootView.open()
        expect(rootView.getActiveEditSession().getPath()).toBeUndefined()
        rootView.trigger 'tree-view:reveal-active-file'
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.focus).toHaveBeenCalled()

    describe "if there is no editor open", ->
      it "shows and focuses the tree view, but does not attempt to select a specific file", ->
        expect(rootView.getActiveEditSession()).toBeUndefined()
        rootView.trigger 'tree-view:reveal-active-file'
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.focus).toHaveBeenCalled()

  describe "when tool-panel:unfocus is triggered on the tree view", ->
    it "surrenders focus to the root view but remains open", ->
      rootView.open() # When we trigger 'tool-panel:unfocus' below, we want an editor to become focused
      rootView.attachToDom()
      treeView.focus()
      expect(treeView).toMatchSelector(':focus')
      treeView.trigger 'tool-panel:unfocus'
      expect(treeView).toBeVisible()
      expect(treeView).not.toMatchSelector(':focus')
      expect(rootView.getActiveEditor().isFocused).toBeTruthy()

  describe "when core:close is triggered on the tree view", ->
    it "detaches the TreeView, focuses the RootView and does not bubble the core:close event", ->
      treeView.attach()
      treeView.focus()
      rootViewCloseHandler = jasmine.createSpy('rootViewCloseHandler')
      rootView.on 'core:close', rootViewCloseHandler
      spyOn(rootView, 'focus')

      treeView.trigger('core:close')
      expect(rootView.focus).toHaveBeenCalled()
      expect(rootViewCloseHandler).not.toHaveBeenCalled()
      expect(treeView.hasParent()).toBeFalsy()

  describe "when a directory's disclosure arrow is clicked", ->
    it "expands / collapses the associated directory", ->
      subdir = treeView.root.find('.entries > li:contains(dir1/)').view()

      expect(subdir.disclosureArrow).toHaveText('▸')
      expect(subdir.find('.entries')).not.toExist()

      subdir.disclosureArrow.click()

      expect(subdir.disclosureArrow).toHaveText('▾')
      expect(subdir.find('.entries')).toExist()

      subdir.disclosureArrow.click()
      expect(subdir.disclosureArrow).toHaveText('▸')
      expect(subdir.find('.entries')).not.toExist()

    it "restores the expansion state of descendant directories", ->
      child = treeView.root.find('.entries > li:contains(dir1/)').view()
      child.disclosureArrow.click()

      grandchild = child.find('.entries > li:contains(sub-dir1/)').view()
      grandchild.disclosureArrow.click()

      treeView.root.disclosureArrow.click()
      expect(treeView.root.find('.entries')).not.toExist()
      treeView.root.disclosureArrow.click()

      # previously expanded descendants remain expanded
      expect(treeView.root.find('> .entries > li:contains(dir1/) > .entries > li:contains(sub-dir1/) > .entries').length).toBe 1

      # collapsed descendants remain collapsed
      expect(treeView.root.find('> .entries > li.contains(dir2/) > .entries')).not.toExist()

    it "when collapsing a directory, removes change subscriptions from the collapsed directory and its descendants", ->
      child = treeView.root.entries.find('li:contains(dir1/)').view()
      child.disclosureArrow.click()

      grandchild = child.entries.find('li:contains(sub-dir1/)').view()
      grandchild.disclosureArrow.click()

      expect(treeView.root.directory.subscriptionCount()).toBe 1
      expect(child.directory.subscriptionCount()).toBe 1
      expect(grandchild.directory.subscriptionCount()).toBe 1

      treeView.root.disclosureArrow.click()

      expect(treeView.root.directory.subscriptionCount()).toBe 0
      expect(child.directory.subscriptionCount()).toBe 0
      expect(grandchild.directory.subscriptionCount()).toBe 0

  describe "when a file is single-clicked", ->
    it "selects the files and opens it in the active editor, without changing focus", ->
      expect(rootView.getActiveEditor()).toBeUndefined()

      sampleJs.trigger clickEvent(originalEvent: { detail: 1 })
      expect(sampleJs).toHaveClass 'selected'
      expect(rootView.getActiveEditor().getPath()).toBe require.resolve('fixtures/tree-view/tree-view.js')
      expect(rootView.getActiveEditor().isFocused).toBeFalsy()

      sampleTxt.trigger clickEvent(originalEvent: { detail: 1 })
      expect(sampleTxt).toHaveClass 'selected'
      expect(treeView.find('.selected').length).toBe 1
      expect(rootView.getActiveEditor().getPath()).toBe require.resolve('fixtures/tree-view/tree-view.txt')
      expect(rootView.getActiveEditor().isFocused).toBeFalsy()

  describe "when a file is double-clicked", ->
    it "selects the file and opens it in the active editor on the first click, then changes focus to the active editor on the second", ->
      sampleJs.trigger clickEvent(originalEvent: { detail: 1 })
      expect(sampleJs).toHaveClass 'selected'
      expect(rootView.getActiveEditor().getPath()).toBe require.resolve('fixtures/tree-view/tree-view.js')
      expect(rootView.getActiveEditor().isFocused).toBeFalsy()

      sampleJs.trigger clickEvent(originalEvent: { detail: 2 })
      expect(rootView.getActiveEditor().isFocused).toBeTruthy()

  describe "when a directory is single-clicked", ->
    it "is selected", ->
      subdir = treeView.root.find('.directory:first').view()
      subdir.trigger clickEvent(originalEvent: { detail: 1 })
      expect(subdir).toHaveClass 'selected'

  describe "when a directory is double-clicked", ->
    it "toggles the directory expansion state and does not change the focus to the editor", ->
      sampleJs.trigger clickEvent(originalEvent: { detail: 1 })
      subdir = treeView.root.find('.directory:first').view()
      subdir.trigger clickEvent(originalEvent: { detail: 1 })
      expect(subdir).toHaveClass 'selected'
      subdir.trigger clickEvent(originalEvent: { detail: 2 })
      expect(subdir).toHaveClass 'expanded'
      expect(rootView.getActiveEditor().isFocused).toBeFalsy()

  describe "when a new file is opened in the active editor", ->
    it "is selected in the tree view if the file's entry visible", ->
      sampleJs.click()
      rootView.open(require.resolve('fixtures/tree-view/tree-view.txt'))

      expect(sampleTxt).toHaveClass 'selected'
      expect(treeView.find('.selected').length).toBe 1

    it "selected a file's parent dir if the file's entry is not visible", ->
      rootView.open(require.resolve('fixtures/tree-view/dir1/sub-dir1/sub-file1'))

      dirView = treeView.root.find('.directory:contains(dir1)').view()
      expect(dirView).toHaveClass 'selected'

  describe "when a different editor becomes active", ->
    it "selects the file in that is open in that editor", ->
      sampleJs.click()
      leftEditor = rootView.getActiveEditor()
      rightEditor = leftEditor.splitRight()
      sampleTxt.click()

      expect(sampleTxt).toHaveClass('selected')
      leftEditor.focus()
      expect(sampleJs).toHaveClass('selected')

  describe "keyboard navigation", ->
    afterEach ->
      expect(treeView.find('.selected').length).toBeLessThan 2

    describe "core:move-down", ->
      describe "when a collapsed directory is selected", ->
        it "skips to the next directory", ->
          treeView.root.find('.directory:eq(0)').click()
          treeView.trigger 'core:move-down'
          expect(treeView.root.find('.directory:eq(1)')).toHaveClass 'selected'

      describe "when an expanded directory is selected", ->
        it "selects the first entry of the directory", ->
          subdir = treeView.root.find('.directory:eq(1)').view()
          subdir.expand()
          subdir.click()

          treeView.trigger 'core:move-down'

          expect(subdir.entries.find('.entry:first')).toHaveClass 'selected'

      describe "when the last entry of an expanded directory is selected", ->
        it "selects the entry after its parent directory", ->
          subdir1 = treeView.root.find('.directory:eq(1)').view()
          subdir1.expand()
          subdir1.entries.find('.entry:last').click()

          treeView.trigger 'core:move-down'

          expect(treeView.root.find('.entries > .entry:eq(2)')).toHaveClass 'selected'

      describe "when the last directory of another last directory is selected", ->
        [nested, nested2] = []

        beforeEach ->
          nested = treeView.root.find('.directory:eq(2)').view()
          expect(nested.find('.header').text()).toContain 'nested/'
          nested.expand()
          nested2 = nested.entries.find('.entry:last').view()
          nested2.click()

        describe "when the directory is collapsed", ->
          it "selects the entry after its grandparent directory", ->
            treeView.trigger 'core:move-down'
            expect(nested.next()).toHaveClass 'selected'

        describe "when the directory is expanded", ->
          it "selects the entry after its grandparent directory", ->
            nested2.expand()
            nested2.find('.file').remove() # kill the .gitkeep file, which has to be there but screws the test
            treeView.trigger 'core:move-down'
            expect(nested.next()).toHaveClass 'selected'

      describe "when the last entry of the last directory is selected", ->
        it "does not change the selection", ->
          lastEntry = treeView.root.find('> .entries .entry:last')
          lastEntry.click()

          treeView.trigger 'core:move-down'

          expect(lastEntry).toHaveClass 'selected'

    describe "core:move-up", ->
      describe "when there is an expanded directory before the currently selected entry", ->
        it "selects the last entry in the expanded directory", ->
          lastDir = treeView.root.find('.directory:last').view()
          fileAfterDir = lastDir.next().view()
          lastDir.expand()
          fileAfterDir.click()

          treeView.trigger 'core:move-up'
          expect(lastDir.find('.entry:last')).toHaveClass 'selected'

      describe "when there is an entry before the currently selected entry", ->
        it "selects the previous entry", ->
          lastEntry = treeView.root.find('.entry:last')
          lastEntry.click()

          treeView.trigger 'core:move-up'

          expect(lastEntry.prev()).toHaveClass 'selected'

      describe "when there is no entry before the currently selected entry, but there is a parent directory", ->
        it "selects the parent directory", ->
          subdir = treeView.root.find('.directory:first').view()
          subdir.expand()
          subdir.find('> .entries > .entry:first').click()

          treeView.trigger 'core:move-up'

          expect(subdir).toHaveClass 'selected'

      describe "when there is no parent directory or previous entry", ->
        it "does not change the selection", ->
          treeView.root.click()
          treeView.trigger 'core:move-up'
          expect(treeView.root).toHaveClass 'selected'

    describe "core:move-to-top", ->
      it "scrolls to the top", ->
        treeView.height(100)
        treeView.attachToDom()
        $(element).view().expand() for element in treeView.find('.directory')
        expect(treeView.prop('scrollHeight')).toBeGreaterThan treeView.outerHeight()

        expect(treeView.scrollTop()).toBe 0

        entryCount = treeView.find(".entry").length
        _.times entryCount, -> treeView.moveDown()
        expect(treeView.scrollTop()).toBeGreaterThan 0

        treeView.trigger 'core:move-to-top'
        expect(treeView.scrollTop()).toBe 0

    describe "core:move-to-bottom", ->
      it "scrolls to the bottom", ->
        treeView.height(100)
        treeView.attachToDom()
        $(element).view().expand() for element in treeView.find('.directory')
        expect(treeView.prop('scrollHeight')).toBeGreaterThan treeView.outerHeight()

        expect(treeView.scrollTop()).toBe 0
        treeView.trigger 'core:move-to-bottom'
        expect(treeView.scrollBottom()).toBe treeView.prop('scrollHeight')

   describe "core:page-up", ->
      it "scrolls up a page", ->
        treeView.height(5)
        treeView.attachToDom()
        $(element).view().expand() for element in treeView.find('.directory')
        expect(treeView.prop('scrollHeight')).toBeGreaterThan treeView.outerHeight()

        expect(treeView.scrollTop()).toBe 0
        treeView.scrollToBottom()
        scrollTop = treeView.scrollTop()
        expect(scrollTop).toBeGreaterThan 0

        treeView.trigger 'core:page-up'
        expect(treeView.scrollTop()).toBe scrollTop - treeView.height()

    describe "core:page-down", ->
      it "scrolls down a page", ->
        treeView.height(5)
        treeView.attachToDom()
        $(element).view().expand() for element in treeView.find('.directory')
        expect(treeView.prop('scrollHeight')).toBeGreaterThan treeView.outerHeight()

        expect(treeView.scrollTop()).toBe 0
        treeView.trigger 'core:page-down'
        expect(treeView.scrollTop()).toBe treeView.height()

    describe "movement outside of viewable region", ->
      it "scrolls the tree view to the selected item", ->
        treeView.height(100)
        treeView.attachToDom()
        $(element).view().expand() for element in treeView.find('.directory')
        expect(treeView.prop('scrollHeight')).toBeGreaterThan treeView.outerHeight()

        treeView.moveDown()
        expect(treeView.scrollTop()).toBe 0

        entryCount = treeView.find(".entry").length
        _.times entryCount, -> treeView.moveDown()
        expect(treeView.scrollBottom()).toBe treeView.prop('scrollHeight')

        _.times entryCount, -> treeView.moveUp()
        expect(treeView.scrollTop()).toBe 0

    describe "tree-view:expand-directory", ->
      describe "when a directory entry is selected", ->
        it "expands the current directory", ->
          subdir = treeView.root.find('.directory:first')
          subdir.click()

          expect(subdir).not.toHaveClass 'expanded'
          treeView.trigger 'tree-view:expand-directory'
          expect(subdir).toHaveClass 'expanded'

      describe "when a file entry is selected", ->
        it "does nothing", ->
          treeView.root.find('.file').click()
          treeView.trigger 'tree-view:expand-directory'

    describe "tree-view:collapse-directory", ->
      subdir = null

      beforeEach ->
        subdir = treeView.root.find('> .entries > .directory').eq(0).view()
        subdir.expand()

      describe "when an expanded directory is selected", ->
        it "collapses the selected directory", ->
          expect(subdir).toHaveClass 'expanded'

          subdir.click()
          treeView.trigger 'tree-view:collapse-directory'

          expect(subdir).not.toHaveClass 'expanded'
          expect(treeView.root).toHaveClass 'expanded'

      describe "when a collapsed directory is selected", ->
        it "collapses and selects the selected directory's parent directory", ->
          subdir.find('.directory').click()
          treeView.trigger 'tree-view:collapse-directory'

          expect(subdir).not.toHaveClass 'expanded'
          expect(subdir).toHaveClass 'selected'
          expect(treeView.root).toHaveClass 'expanded'

      describe "when collapsed root directory is selected", ->
        it "does not raise an error", ->
          treeView.root.collapse()
          treeView.selectEntry(treeView.root)

          treeView.trigger 'tree-view:collapse-directory'

      describe "when a file is selected", ->
        it "collapses and selects the selected file's parent directory", ->
          subdir.find('.file').click()
          treeView.trigger 'tree-view:collapse-directory'

          expect(subdir).not.toHaveClass 'expanded'
          expect(subdir).toHaveClass 'selected'
          expect(treeView.root).toHaveClass 'expanded'

    describe "tree-view:open-selected-entry", ->
      describe "when a file is selected", ->
        it "opens the file in the editor and focuses it", ->
          treeView.root.find('.file:contains(tree-view.js)').click()
          treeView.root.trigger 'tree-view:open-selected-entry'
          expect(rootView.getActiveEditor().getPath()).toBe require.resolve('fixtures/tree-view/tree-view.js')
          expect(rootView.getActiveEditor().isFocused).toBeTruthy()

      describe "when a directory is selected", ->
        it "expands or collapses the directory", ->
          subdir = treeView.root.find('.directory').first()
          subdir.click()

          expect(subdir).not.toHaveClass 'expanded'
          treeView.root.trigger 'tree-view:open-selected-entry'
          expect(subdir).toHaveClass 'expanded'
          treeView.root.trigger 'tree-view:open-selected-entry'
          expect(subdir).not.toHaveClass 'expanded'

      describe "when nothing is selected", ->
        it "does nothing", ->
          treeView.root.trigger 'tree-view:open-selected-entry'
          expect(rootView.getActiveEditor()).toBeUndefined()

  describe "file modification", ->
    [dirView, fileView, rootDirPath, dirPath, filePath] = []

    beforeEach ->
      rootView.deactivate()

      rootDirPath = "/tmp/atom-tests"
      fs.remove(rootDirPath) if fs.exists(rootDirPath)

      dirPath = fs.join(rootDirPath, "test-dir")
      filePath = fs.join(dirPath, "test-file.txt")
      fs.makeDirectory(rootDirPath)
      fs.makeDirectory(dirPath)
      fs.write(filePath, "doesn't matter")

      rootView = new RootView(rootDirPath)
      project = rootView.project
      rootView.activateExtension(TreeView)
      treeView = rootView.find(".tree-view").view()
      dirView = treeView.root.entries.find('.directory:contains(test-dir)').view()
      dirView.expand()
      fileView = treeView.find('.file:contains(test-file.txt)').view()

    afterEach ->
      rootView.deactivate()
      rootView = null
      fs.remove(rootDirPath) if fs.exists(rootDirPath)

    describe "tree-view:add", ->
      addDialog = null

      beforeEach ->
        fileView.click()
        treeView.trigger "tree-view:add"
        addDialog = rootView.find(".tree-view-dialog").view()

      describe "when a file is selected", ->
        it "opens an add dialog with the file's current directory path populated", ->
          expect(addDialog).toExist()
          expect(addDialog.prompt.text()).toBeTruthy()
          expect(project.relativize(dirPath)).toMatch(/[^\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(project.relativize(dirPath) + "/")
          expect(addDialog.miniEditor.getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor.isFocused).toBeTruthy()

        describe "when parent directory of the selected file changes", ->
          it "active file is still shown as selected in the tree view", ->
            directoryChangeHandler = jasmine.createSpy("directory-change")
            dirView.on "tree-view:directory-modified", directoryChangeHandler

            dirView.directory.trigger 'contents-change'
            expect(directoryChangeHandler).toHaveBeenCalled()
            expect(treeView.find('.selected').text()).toBe fs.base(filePath)

        describe "when the path without a trailing '/' is changed and confirmed", ->
          describe "when no file exists at that location", ->
            it "add a file, closes the dialog and selects the file in the tree-view", ->
              newPath = fs.join(dirPath, "new-test-file.txt")
              addDialog.miniEditor.insertText(fs.base(newPath))
              addDialog.trigger 'core:confirm'
              expect(fs.exists(newPath)).toBeTruthy()
              expect(fs.isFile(newPath)).toBeTruthy()
              expect(addDialog.parent()).not.toExist()
              expect(rootView.getActiveEditor().getPath()).toBe newPath

              waitsFor "tree view to be updated", ->
                dirView.entries.find("> .file").length > 1

              runs ->
                expect(treeView.find('.selected').text()).toBe fs.base(newPath)

          describe "when a file already exists at that location", ->
            it "shows an error message and does not close the dialog", ->
              newPath = fs.join(dirPath, "new-test-file.txt")
              fs.write(newPath, '')
              addDialog.miniEditor.insertText(fs.base(newPath))
              addDialog.trigger 'core:confirm'

              expect(addDialog.prompt.text()).toContain 'Error'
              expect(addDialog.prompt.text()).toContain 'already exists'
              expect(addDialog.prompt).toHaveClass('error')
              expect(addDialog.hasParent()).toBeTruthy()

        describe "when the path with a trailing '/' is changed and confirmed", ->
          describe "when no file or directory exists at the given path", ->
            it "adds a directory and closes the dialog", ->
              treeView.attachToDom()
              newPath = fs.join(dirPath, "new/dir")
              addDialog.miniEditor.insertText("new/dir/")
              addDialog.trigger 'core:confirm'
              expect(fs.exists(newPath)).toBeTruthy()
              expect(fs.isDirectory(newPath)).toBeTruthy()
              expect(addDialog.parent()).not.toExist()
              expect(rootView.getActiveEditor().getPath()).not.toBe newPath
              expect(treeView).toMatchSelector(':focus')
              expect(rootView.getActiveEditor().isFocused).toBeFalsy()
              expect(dirView.find('.directory.selected:contains(new/)').length).toBe(1)

            it "selects the created directory", ->
              treeView.attachToDom()
              newPath = fs.join(dirPath, "new2/")
              addDialog.miniEditor.insertText("new2/")
              addDialog.trigger 'core:confirm'
              expect(fs.exists(newPath)).toBeTruthy()
              expect(fs.isDirectory(newPath)).toBeTruthy()
              expect(addDialog.parent()).not.toExist()
              expect(rootView.getActiveEditor().getPath()).not.toBe newPath
              expect(treeView).toMatchSelector(':focus')
              expect(rootView.getActiveEditor().isFocused).toBeFalsy()
              expect(dirView.find('.directory.selected:contains(new2/)').length).toBe(1)

          describe "when a file or directory already exists at the given path", ->
            it "shows an error message and does not close the dialog", ->
              newPath = fs.join(dirPath, "new-dir")
              fs.makeDirectory(newPath)
              addDialog.miniEditor.insertText("new-dir/")
              addDialog.trigger 'core:confirm'

              expect(addDialog.prompt.text()).toContain 'Error'
              expect(addDialog.prompt.text()).toContain 'already exists'
              expect(addDialog.prompt).toHaveClass('error')
              expect(addDialog.hasParent()).toBeTruthy()

        describe "when 'core:cancel' is triggered on the add dialog", ->
          it "removes the dialog and focuses the tree view", ->
            treeView.attachToDom()
            addDialog.trigger 'core:cancel'
            expect(addDialog.parent()).not.toExist()
            expect(treeView).toMatchSelector(':focus')

        describe "when the add dialog's editor loses focus", ->
          it "removes the dialog and focuses root view", ->
            rootView.attachToDom()
            rootView.focus()
            expect(addDialog.parent()).not.toExist()
            expect(rootView.getActiveEditor().isFocused).toBeTruthy()

      describe "when a directory is selected", ->
        it "opens an add dialog with the directory's path populated", ->
          addDialog.cancel()
          dirView.click()
          treeView.trigger "tree-view:add"
          addDialog = rootView.find(".tree-view-dialog").view()

          expect(addDialog).toExist()
          expect(addDialog.prompt.text()).toBeTruthy()
          expect(project.relativize(dirPath)).toMatch(/[^\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(project.relativize(dirPath) + "/")
          expect(addDialog.miniEditor.getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor.isFocused).toBeTruthy()

      describe "when the root directory is selected", ->
        it "opens an add dialog with no path populated", ->
          addDialog.cancel()
          treeView.root.click()
          treeView.trigger "tree-view:add"
          addDialog = rootView.find(".tree-view-dialog").view()

          expect(addDialog.miniEditor.getText().length).toBe 0

    describe "tree-view:move", ->
      describe "when a file is selected", ->
        moveDialog = null

        beforeEach ->
          fileView.click()
          treeView.trigger "tree-view:move"
          moveDialog = rootView.find(".tree-view-dialog").view()

        it "opens a move dialog with the file's current path (excluding extension) populated", ->
          extension = fs.extension(filePath)
          fileNameWithoutExtension = fs.base(filePath, extension)
          expect(moveDialog).toExist()
          expect(moveDialog.prompt.text()).toBe "Enter the new path for the file:"
          expect(moveDialog.miniEditor.getText()).toBe(project.relativize(filePath))
          expect(moveDialog.miniEditor.getSelectedText()).toBe fs.base(fileNameWithoutExtension)
          expect(moveDialog.miniEditor.isFocused).toBeTruthy()

        describe "when the path is changed and confirmed", ->
          describe "when all the directories along the new path exist", ->
            it "moves the file, updates the tree view, and closes the dialog", ->
              newPath = fs.join(rootDirPath, 'renamed-test-file.txt')
              moveDialog.miniEditor.setText(newPath)

              moveDialog.trigger 'core:confirm'

              expect(fs.exists(newPath)).toBeTruthy()
              expect(fs.exists(filePath)).toBeFalsy()
              expect(moveDialog.parent()).not.toExist()

              waitsFor "tree view to update", ->
                treeView.root.find('> .entries > .file:contains(renamed-test-file.txt)').length > 0

              runs ->
                dirView = treeView.root.entries.find('.directory:contains(test-dir)').view()
                dirView.expand()
                expect(dirView.entries.children().length).toBe 0

          describe "when the directories along the new path don't exist", ->
            it "creates the target directory before moving the file", ->
              newPath = fs.join(rootDirPath, 'new/directory', 'renamed-test-file.txt')
              moveDialog.miniEditor.setText(newPath)

              moveDialog.trigger 'core:confirm'

              waitsFor "tree view to update", ->
                treeView.root.find('> .entries > .directory:contains(new)').length > 0

              runs ->
                expect(fs.exists(newPath)).toBeTruthy()
                expect(fs.exists(filePath)).toBeFalsy()

          describe "when a file or directory already exists at the target path", ->
            it "shows an error message and does not close the dialog", ->
              runs ->
                fs.write(fs.join(rootDirPath, 'target.txt'), '')
                newPath = fs.join(rootDirPath, 'target.txt')
                moveDialog.miniEditor.setText(newPath)

                moveDialog.trigger 'core:confirm'

                expect(moveDialog.prompt.text()).toContain 'Error'
                expect(moveDialog.prompt.text()).toContain 'already exists'
                expect(moveDialog.prompt).toHaveClass('error')
                expect(moveDialog.hasParent()).toBeTruthy()

        describe "when 'core:cancel' is triggered on the move dialog", ->
          it "removes the dialog and focuses the tree view", ->
            treeView.attachToDom()
            moveDialog.trigger 'core:cancel'
            expect(moveDialog.parent()).not.toExist()
            expect(treeView).toMatchSelector(':focus')

        describe "when the move dialog's editor loses focus", ->
          it "removes the dialog and focuses root view", ->
            rootView.attachToDom()
            rootView.focus()
            expect(moveDialog.parent()).not.toExist()
            expect(rootView.getActiveEditor().isFocused).toBeTruthy()

    describe "tree-view:remove", ->
      it "shows the native alert dialog", ->
        fileView.click()
        spyOn(atom, 'confirm')
        treeView.trigger 'tree-view:remove'
        expect(atom.confirm).toHaveBeenCalled()

  describe "file system events", ->
    temporaryFilePath = null

    beforeEach ->
      temporaryFilePath = fs.join(require.resolve('fixtures/tree-view'), 'temporary')
      if fs.exists(temporaryFilePath)
        fs.remove(temporaryFilePath)
        waits(20)

    afterEach ->
      fs.remove(temporaryFilePath) if fs.exists(temporaryFilePath)

    describe "when a file is added or removed in an expanded directory", ->
      it "updates the directory view to display the directory's new contents", ->
        entriesCountBefore = null

        runs ->
          expect(fs.exists(temporaryFilePath)).toBeFalsy()
          entriesCountBefore = treeView.root.entries.find('.entry').length
          fs.write temporaryFilePath, 'hi'

        waitsFor "directory view contens to refresh", ->
          treeView.root.entries.find('.entry').length == entriesCountBefore + 1

        runs ->
          expect(treeView.root.entries.find('.entry').length).toBe entriesCountBefore + 1
          expect(treeView.root.entries.find('.file:contains(temporary)')).toExist()
          fs.remove(temporaryFilePath)

        waitsFor "directory view contens to refresh", ->
          treeView.root.entries.find('.entry').length == entriesCountBefore

  describe "ignored files", ->
    [ignoreFile] = []

    beforeEach ->
      ignoreFile = fs.join(require.resolve('fixtures/tree-view'), '.gitignore')
      fs.write(ignoreFile, 'tree-view.js')
      project.setHideIgnoredFiles(false)

    afterEach ->
      fs.remove(ignoreFile) if fs.exists(ignoreFile)

    it "toggles display of ignored path when setting is toggled", ->
      expect(treeView.find('.file:contains(tree-view.js)').length).toBe 1
      rootView.trigger 'window:toggle-ignored-files'
      expect(treeView.find('.file:contains(tree-view.js)').length).toBe 0
      rootView.trigger 'window:toggle-ignored-files'
      expect(treeView.find('.file:contains(tree-view.js)').length).toBe 1
