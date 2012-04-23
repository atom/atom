TreeView = require 'tree-view'
Directory = require 'directory'

describe "TreeView", ->
  [project, treeView, rootDirectoryView] = []

  beforeEach ->
    project = new Directory(require.resolve('fixtures/'))
    treeView = new TreeView(project)
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

      expect(subdir.find('.disclosure-arrow')).toHaveText('▸')
      expect(subdir.find('.entries')).not.toExist()

      subdir.find('.disclosure-arrow').click()

      expect(subdir.find('> .disclosure-arrow')).toHaveText('▾')
      expect(subdir.find('.entries')).toExist()

