TreeView = require 'tree-view'
RootView = require 'root-view'
Directory = require 'directory'
fs = require 'fs'

describe "TreeView", ->
  [rootView, project, treeView, sampleJs, sampleTxt] = []

  beforeEach ->
    rootView = new RootView(pathToOpen: require.resolve('fixtures/'))
    project = rootView.project
    treeView = new TreeView(rootView)
    treeView.root = treeView.find('> li:first').view()
    sampleJs = treeView.find('.file:contains(sample.js)')
    sampleTxt = treeView.find('.file:contains(sample.txt)')

    expect(treeView.root.directory.subscriptionCount()).toBeGreaterThan 0

  afterEach ->
    treeView.deactivate()

  describe ".initialize(project)", ->
    it "renders the root of the project and its contents alphabetically with subdirectories first in a collapsed state", ->
      expect(treeView.root.find('> .header .disclosure-arrow')).toHaveText('▾')
      expect(treeView.root.find('> .header .name')).toHaveText('fixtures/')

      rootEntries = treeView.root.find('.entries')
      subdir1 = rootEntries.find('> li:eq(0)')
      expect(subdir1.find('.disclosure-arrow')).toHaveText('▸')
      expect(subdir1.find('.name')).toHaveText('dir/')
      expect(subdir1.find('.entries')).not.toExist()

      subdir2 = rootEntries.find('> li:eq(1)')
      expect(subdir2.find('.disclosure-arrow')).toHaveText('▸')
      expect(subdir2.find('.name')).toHaveText('zed/')
      expect(subdir2.find('.entries')).not.toExist()

      expect(rootEntries.find('> .file:contains(sample.js)')).toExist()
      expect(rootEntries.find('> .file:contains(sample.txt)')).toExist()

  describe "when a directory's disclosure arrow is clicked", ->
    it "expands / collapses the associated directory", ->
      subdir = treeView.root.find('.entries > li:contains(dir/)').view()

      expect(subdir.disclosureArrow).toHaveText('▸')
      expect(subdir.find('.entries')).not.toExist()

      subdir.disclosureArrow.click()

      expect(subdir.disclosureArrow).toHaveText('▾')
      expect(subdir.find('.entries')).toExist()

      subdir.disclosureArrow.click()
      expect(subdir.disclosureArrow).toHaveText('▸')
      expect(subdir.find('.entries')).not.toExist()

    it "restores the expansion state of descendant directories", ->
      child = treeView.root.find('.entries > li:contains(dir/)').view()
      child.disclosureArrow.click()

      grandchild = child.find('.entries > li:contains(a-dir/)').view()
      grandchild.disclosureArrow.click()

      treeView.root.disclosureArrow.click()
      expect(treeView.root.find('.entries')).not.toExist()
      treeView.root.disclosureArrow.click()

      # previously expanded descendants remain expanded
      expect(treeView.root.find('> .entries > li:contains(dir/) > .entries > li:contains(a-dir/) > .entries').length).toBe 1

      # collapsed descendants remain collapsed
      expect(treeView.root.find('> .entries > li.contains(zed/) > .entries')).not.toExist()

    it "when collapsing a directory, removes change subscriptions from the collapsed directory and its descendants", ->
      child = treeView.root.entries.find('li:contains(dir/)').view()
      child.disclosureArrow.click()

      grandchild = child.entries.find('li:contains(a-dir/)').view()
      grandchild.disclosureArrow.click()

      expect(treeView.root.directory.subscriptionCount()).toBe 1
      expect(child.directory.subscriptionCount()).toBe 1
      expect(grandchild.directory.subscriptionCount()).toBe 1

      treeView.root.disclosureArrow.click()

      expect(treeView.root.directory.subscriptionCount()).toBe 0
      expect(child.directory.subscriptionCount()).toBe 0
      expect(grandchild.directory.subscriptionCount()).toBe 0

  describe "when a file is clicked", ->
    it "opens it in the active editor and selects it", ->
      expect(rootView.activeEditor()).toBeUndefined()

      sampleJs.click()
      expect(sampleJs).toHaveClass 'selected'
      expect(rootView.activeEditor().buffer.path).toBe require.resolve('fixtures/sample.js')

      sampleTxt.click()
      expect(sampleTxt).toHaveClass 'selected'
      expect(treeView.find('.selected').length).toBe 1
      expect(rootView.activeEditor().buffer.path).toBe require.resolve('fixtures/sample.txt')

  describe "when a directory is clicked", ->
    it "is selected", ->
      subdir = treeView.root.find('.directory:first').view()
      subdir.click()
      expect(subdir).toHaveClass 'selected'

  describe "when a new file is opened in the active editor", ->
    it "is selected in the tree view if visible", ->
      sampleJs.click()
      rootView.open(require.resolve('fixtures/sample.txt'))

      expect(sampleTxt).toHaveClass 'selected'
      expect(treeView.find('.selected').length).toBe 1

  describe "when a different editor becomes active", ->
    it "selects the file in that is open in that editor", ->
      sampleJs.click()
      leftEditor = rootView.activeEditor()
      rightEditor = leftEditor.splitRight()
      sampleTxt.click()

      expect(sampleTxt).toHaveClass('selected')
      leftEditor.focus()
      expect(sampleJs).toHaveClass('selected')

  describe "keyboard navigation", ->
    afterEach ->
      expect(treeView.find('.selected').length).toBeLessThan 2

    describe "move-down", ->
      describe "when nothing is selected", ->
        it "selects the first entry", ->
          treeView.trigger 'move-down'
          expect(treeView.root).toHaveClass 'selected'

      describe "when a collapsed directory is selected", ->
        it "skips to the next directory", ->
          treeView.root.find('.directory:eq(0)').click()
          treeView.trigger 'move-down'
          expect(treeView.root.find('.directory:eq(1)')).toHaveClass 'selected'

      describe "when an expanded directory is selected", ->
        it "selects the first entry of the directory", ->
          subdir = treeView.root.find('.directory:eq(1)').view()
          subdir.expand()
          subdir.click()

          treeView.trigger 'move-down'

          expect(subdir.entries.find('.entry:first')).toHaveClass 'selected'

      describe "when the last entry of an expanded directory is selected", ->
        it "selects the entry after its parent directory", ->
          subdir1 = treeView.root.find('.directory:eq(1)').view()
          subdir1.expand()
          subdir1.entries.find('.entry:last').click()

          treeView.trigger 'move-down'

          expect(treeView.root.find('.entries > .entry:eq(2)')).toHaveClass 'selected'

      describe "when the last entry of the last directory is selected", ->
        it "does not change the selection", ->
          lastEntry = treeView.root.find('> .entries .entry:last')
          lastEntry.click()

          treeView.trigger 'move-down'

          expect(lastEntry).toHaveClass 'selected'

    describe "move-up", ->
      describe "when nothing is selected", ->
        it "selects the last entry", ->
          treeView.trigger 'move-up'
          expect(treeView.root.find('.entry:last')).toHaveClass 'selected'

      describe "when there is an entry before the currently selected entry", ->
        it "selects the previous entry", ->
          lastEntry = treeView.root.find('.entry:last')
          lastEntry.click()

          treeView.trigger 'move-up'

          expect(lastEntry.prev()).toHaveClass 'selected'

      describe "when there is no entry before the currently selected entry, but there is a parent directory", ->
        it "selects the parent directory", ->
          subdir = treeView.root.find('.directory:first').view()
          subdir.expand()
          subdir.find('> .entries > .entry:first').click()


          treeView.trigger 'move-up'

          expect(subdir).toHaveClass 'selected'

      describe "when there is no parent directory or previous entry", ->
        it "does not change the selection", ->
          treeView.root.click()
          treeView.trigger 'move-up'
          expect(treeView.root).toHaveClass 'selected'

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

      describe "when a file is selected", ->
        it "collapses and selects the selected file's parent directory", ->
          subdir.find('.file').click()
          treeView.trigger 'tree-view:collapse-directory'

          expect(subdir).not.toHaveClass 'expanded'
          expect(subdir).toHaveClass 'selected'
          expect(treeView.root).toHaveClass 'expanded'

    describe "tree-view:open-selected-entry", ->
      describe "when a file is selected", ->
        it "opens the file in the editor", ->
          treeView.root.find('.file:contains(sample.js)').click()
          treeView.root.trigger 'tree-view:open-selected-entry'
          expect(rootView.activeEditor().buffer.path).toBe require.resolve('fixtures/sample.js')

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
          expect(rootView.activeEditor()).toBeUndefined()

  describe "file modification", ->
    [dirView, fileView, rootDirPath, dirPath, filePath] = []

    beforeEach ->
      treeView.deactivate()

      rootDirPath = "/tmp/atom-tests"
      fs.remove(rootDirPath) if fs.exists(rootDirPath)

      dirPath = fs.join(rootDirPath, "test-dir")
      filePath = fs.join(dirPath, "test-file.txt")
      fs.makeDirectory(rootDirPath)
      fs.makeDirectory(dirPath)
      fs.write(filePath, "doesn't matter")

      rootView = new RootView(pathToOpen: rootDirPath)
      project = rootView.project
      treeView = new TreeView(rootView)
      treeView.root = treeView.root
      dirView = treeView.root.entries.find('.directory:contains(test-dir)').view()
      dirView.expand()
      fileView = treeView.find('.file:contains(test-file.txt)').view()

    afterEach ->
      fs.remove(rootDirPath) if fs.exists(rootDirPath)

    describe "tree-view:add", ->
      addDialog = null

      beforeEach ->
        fileView.click()
        treeView.trigger "tree-view:add"
        addDialog = rootView.find(".add-dialog").view()

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
            dirView.on "tree-view:directory-change", directoryChangeHandler

            dirView.directory.trigger 'contents-change'
            expect(directoryChangeHandler).toHaveBeenCalled()
            expect(treeView.find('.selected').text()).toBe fs.base(filePath)

        describe "when the path without a trailing '/' is changed and confirmed", ->
          it "add a file, closes the dialog and selects the file in the tree-view", ->
            newPath = fs.join(dirPath, "new-test-file.txt")
            addDialog.miniEditor.insertText(fs.base(newPath))
            addDialog.trigger 'tree-view:confirm'
            expect(fs.exists(newPath)).toBeTruthy()
            expect(fs.isFile(newPath)).toBeTruthy()
            expect(addDialog.parent()).not.toExist()
            expect(rootView.activeEditor().buffer.path).toBe newPath

            waitsFor "tree view to be updated", ->
              dirView.entries.find("> .file").length > 1

            runs ->
              expect(treeView.find('.selected').text()).toBe fs.base(newPath)

        describe "when the path with a trailing '/' is changed and confirmed", ->
          it "adds a directory and closes the dialog", ->
            newPath = fs.join(dirPath, "new-dir")
            addDialog.miniEditor.insertText("new-dir/")
            addDialog.trigger 'tree-view:confirm'
            expect(fs.exists(newPath)).toBeTruthy()
            expect(fs.isDirectory(newPath)).toBeTruthy()
            expect(addDialog.parent()).not.toExist()
            expect(rootView.activeEditor().buffer.path).not.toBe newPath

        describe "when 'tree-view:cancel' is triggered on the add dialog", ->
          it "removes the dialog and focuses the tree view", ->
            treeView.attachToDom()
            addDialog.trigger 'tree-view:cancel'
            expect(addDialog.parent()).not.toExist()
            expect(treeView).toMatchSelector(':focus')

        describe "when the add dialog's editor loses focus", ->
          it "removes the dialog and focuses root view", ->
            rootView.attachToDom()
            rootView.focus()
            expect(addDialog.parent()).not.toExist()
            expect(rootView.activeEditor().isFocused).toBeTruthy()

      describe "when a directory is selected", ->
        it "opens an add dialog with the directory's path populated", ->
          addDialog.cancel()
          dirView.click()
          treeView.trigger "tree-view:add"
          addDialog = rootView.find(".add-dialog").view()

          expect(addDialog).toExist()
          expect(addDialog.prompt.text()).toBeTruthy()
          expect(project.relativize(dirPath)).toMatch(/[^\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(project.relativize(dirPath) + "/")
          expect(addDialog.miniEditor.getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor.isFocused).toBeTruthy()

    describe "tree-view:move", ->
      describe "when a file is selected", ->
        moveDialog = null

        beforeEach ->
          fileView.click()
          treeView.trigger "tree-view:move"
          moveDialog = rootView.find(".move-dialog").view()

        it "opens a move dialog with the file's current path (excluding extension) populated", ->
          extension = fs.extension(filePath)
          fileNameWithoutExtension = fs.base(filePath, extension)
          expect(moveDialog).toExist()
          expect(moveDialog.prompt.text()).toBe "Enter the new path for the file:"
          expect(moveDialog.editor.getText()).toBe(project.relativize(filePath))
          expect(moveDialog.editor.getSelectedText()).toBe fs.base(fileNameWithoutExtension)
          expect(moveDialog.editor.isFocused).toBeTruthy()

        describe "when the path is changed and confirmed", ->
          it "moves the file, updates the tree view, and closes the dialog", ->
            runs ->
              newPath = fs.join(rootDirPath, 'renamed-test-file.txt')
              moveDialog.editor.setText(newPath)

              moveDialog.trigger 'tree-view:confirm'

              expect(fs.exists(newPath)).toBeTruthy()
              expect(fs.exists(filePath)).toBeFalsy()
              expect(moveDialog.parent()).not.toExist()

            waitsFor "tree view to update", ->
              treeView.root.find('> .entries > .file:contains(renamed-test-file.txt)').length > 0

            runs ->
              dirView = treeView.root.entries.find('.directory:contains(test-dir)').view()
              dirView.expand()
              expect(dirView.entries.children().length).toBe 0

        describe "when 'tree-view:cancel' is triggered on the move dialog", ->
          it "removes the dialog and focuses the tree view", ->
            treeView.attachToDom()
            moveDialog.trigger 'tree-view:cancel'
            expect(moveDialog.parent()).not.toExist()
            expect(treeView).toMatchSelector(':focus')

        describe "when the move dialog's editor loses focus", ->
          it "removes the dialog and focuses root view", ->
            rootView.attachToDom()
            rootView.focus()
            expect(moveDialog.parent()).not.toExist()
            expect(rootView.activeEditor().isFocused).toBeTruthy()

  describe "file system events", ->
    temporaryFilePath = null

    beforeEach ->
      temporaryFilePath = fs.join(require.resolve('fixtures'), 'temporary')
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
