TreeView = require 'tree-view'
RootView = require 'root-view'
Directory = require 'directory'

describe "TreeView", ->
  [rootView, project, treeView, rootDirectoryView] = []

  beforeEach ->
    rootView = new RootView(pathToOpen: require.resolve('fixtures/'))
    project = rootView.project
    treeView = new TreeView(rootView)
    rootDirectoryView = treeView.find('> li:first')

  describe ".initialize(project)", ->
    it "renders the root of the project and its contents alphabetically with subdirectories first in a collapsed state", ->
      expect(rootDirectoryView.find('> .disclosure-arrow')).toHaveText('▾')
      expect(rootDirectoryView.find('> .name')).toHaveText('fixtures/')

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
      subdir = rootDirectoryView.find('.entries > li:contains(dir/)')

      disclosureArrow = subdir.find('.disclosure-arrow')
      expect(disclosureArrow).toHaveText('▸')
      expect(subdir.find('.entries')).not.toExist()

      disclosureArrow.click()

      expect(disclosureArrow).toHaveText('▾')
      expect(subdir.find('.entries')).toExist()

      disclosureArrow.click()
      expect(disclosureArrow).toHaveText('▸')
      expect(subdir.find('.entries')).not.toExist()

    it "restores the expansion state of descendant directories", ->
      child = rootDirectoryView.find('.entries > li:contains(dir/)')
      child.find('> .disclosure-arrow').click()

      grandchild = child.find('.entries > li:contains(a-dir/)')
      grandchild.find('> .disclosure-arrow').click()

      rootDirectoryView.find('> .disclosure-arrow').click()
      rootDirectoryView.find('> .disclosure-arrow').click()

      # previously expanded descendants remain expanded
      expect(rootDirectoryView.find('> .entries > li:contains(dir/) > .entries > li:contains(a-dir/) > .entries').length).toBe 1

      # collapsed descendants remain collapsed
      expect(rootDirectoryView.find('> .entries > li.contains(zed/) > .entries')).not.toExist()

  describe "when a file is clicked", ->
    it "opens it in the active editor and selects it", ->
      sampleJs = treeView.find('.file:contains(sample.js)')
      sampleTxt = treeView.find('.file:contains(sample.txt)')

      expect(rootView.activeEditor()).toBeUndefined()
      sampleJs.click()
      expect(sampleJs).toHaveClass 'selected'
      expect(rootView.activeEditor().buffer.path).toBe require.resolve('fixtures/sample.js')

      sampleTxt.click()
      expect(sampleTxt).toHaveClass 'selected'
      expect(treeView.find('.selected').length).toBe 1
      expect(rootView.activeEditor().buffer.path).toBe require.resolve('fixtures/sample.txt')

