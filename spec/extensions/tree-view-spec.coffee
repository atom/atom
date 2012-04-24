TreeView = require 'tree-view'
RootView = require 'root-view'
Directory = require 'directory'

describe "TreeView", ->
  [rootView, project, treeView, rootDirectoryView, sampleJs, sampleTxt] = []

  beforeEach ->
    rootView = new RootView(pathToOpen: require.resolve('fixtures/'))
    project = rootView.project
    treeView = new TreeView(rootView)
    rootDirectoryView = treeView.find('> li:first').view()
    sampleJs = treeView.find('.file:contains(sample.js)')
    sampleTxt = treeView.find('.file:contains(sample.txt)')

  describe ".initialize(project)", ->
    it "renders the root of the project and its contents alphabetically with subdirectories first in a collapsed state", ->
      expect(rootDirectoryView.find('> .header .disclosure-arrow')).toHaveText('▾')
      expect(rootDirectoryView.find('> .header .name')).toHaveText('fixtures/')

      rootEntries = rootDirectoryView.find('.entries')
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
      subdir = rootDirectoryView.find('.entries > li:contains(dir/)').view()

      expect(subdir.disclosureArrow).toHaveText('▸')
      expect(subdir.find('.entries')).not.toExist()

      subdir.disclosureArrow.click()

      expect(subdir.disclosureArrow).toHaveText('▾')
      expect(subdir.find('.entries')).toExist()

      subdir.disclosureArrow.click()
      expect(subdir.disclosureArrow).toHaveText('▸')
      expect(subdir.find('.entries')).not.toExist()

    it "restores the expansion state of descendant directories", ->
      child = rootDirectoryView.find('.entries > li:contains(dir/)').view()
      child.disclosureArrow.click()

      grandchild = child.find('.entries > li:contains(a-dir/)').view()
      grandchild.disclosureArrow.click()

      rootDirectoryView.find('> .disclosure-arrow').click()
      rootDirectoryView.find('> .disclosure-arrow').click()

      # previously expanded descendants remain expanded
      expect(rootDirectoryView.find('> .entries > li:contains(dir/) > .entries > li:contains(a-dir/) > .entries').length).toBe 1

      # collapsed descendants remain collapsed
      expect(rootDirectoryView.find('> .entries > li.contains(zed/) > .entries')).not.toExist()

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
      subdir = rootDirectoryView.find('.directory:first').view()
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
          expect(rootDirectoryView).toHaveClass 'selected'

      describe "when a collapsed directory is selected", ->
        it "skips to the next directory", ->
          rootDirectoryView.find('.directory:eq(0)').click()
          treeView.trigger 'move-down'
          expect(rootDirectoryView.find('.directory:eq(1)')).toHaveClass 'selected'

      describe "when an expanded directory is selected", ->
        it "selects the first entry of the directory", ->
          subdir = rootDirectoryView.find('.directory:eq(1)').view()
          subdir.expand()
          subdir.click()

          treeView.trigger 'move-down'

          expect(subdir.entries.find('.entry:first')).toHaveClass 'selected'

      describe "when the last entry of an expanded directory is selected", ->
        it "selects the entry after its parent directory", ->
          subdir1 = rootDirectoryView.find('.directory:eq(1)').view()
          subdir1.expand()
          subdir1.entries.find('.entry:last').click()

          treeView.trigger 'move-down'

          expect(rootDirectoryView.find('.entries > .entry:eq(2)')).toHaveClass 'selected'

      describe "when the last entry of the last directory is selected", ->
        it "does not change the selection", ->
          lastEntry = rootDirectoryView.find('> .entries .entry:last')
          lastEntry.click()

          treeView.trigger 'move-down'

          expect(lastEntry).toHaveClass 'selected'

    describe "move-up", ->
      describe "when nothing is selected", ->
        it "selects the last entry", ->
          treeView.trigger 'move-up'
          expect(rootDirectoryView.find('.entry:last')).toHaveClass 'selected'

      describe "when there is an entry before the currently selected entry", ->
        it "selects the previous entry", ->
          lastEntry = rootDirectoryView.find('.entry:last')
          lastEntry.click()

          treeView.trigger 'move-up'

          expect(lastEntry.prev()).toHaveClass 'selected'

      describe "when there is no entry before the currently selected entry, but there is a parent directory", ->
        it "selects the parent directory", ->
          subdir = rootDirectoryView.find('.directory:first').view()
          subdir.expand()
          subdir.find('> .entries > .entry:first').click()


          treeView.trigger 'move-up'

          expect(subdir).toHaveClass 'selected'

      describe "when there is no parent directory or previous entry", ->
        it "does not change the selection", ->
          rootDirectoryView.click()
          treeView.trigger 'move-up'
          expect(rootDirectoryView).toHaveClass 'selected'

    describe "tree-view:expand-directory", ->
      describe "when a directory entry is selected", ->
        it "expands the current directory", ->
          subdir = rootDirectoryView.find('.directory:first')
          subdir.click()

          expect(subdir).not.toHaveClass 'expanded'
          treeView.trigger 'tree-view:expand-directory'
          expect(subdir).toHaveClass 'expanded'

      describe "when a file entry is selected", ->
        it "does nothing", ->
          rootDirectoryView.find('.file').click()
          treeView.trigger 'tree-view:expand-directory'
