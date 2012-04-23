TreeView = require 'tree-view'
Directory = require 'directory'

describe "TreeView", ->
  [project, treeView] = []

  beforeEach ->
    project = new Directory(require.resolve('fixtures/'))
    treeView = new TreeView(project)

  describe ".initialize(project)", ->
    it "renders the root of the project and its contents alphabetically with subdirectories first in a collapsed state", ->
      root = treeView.find('> li:first')
      expect(root.find('> .disclosure')).toHaveText('▾')
      expect(root.find('> .name')).toHaveText('fixtures/')

      rootEntries = root.find('.entries')
      subdir1 = rootEntries.find('> li:eq(0)')
      expect(subdir1.find('.disclosure')).toHaveText('▸')
      expect(subdir1.find('.name')).toHaveText('dir/')
      expect(subdir1.find('.entries')).not.toExist()

      subdir2 = rootEntries.find('> li:eq(1)')
      expect(subdir2.find('.disclosure')).toHaveText('▸')
      expect(subdir2.find('.name')).toHaveText('zed/')
      expect(subdir2.find('.entries')).not.toExist()

      expect(rootEntries.find('> .file:contains(sample.js)')).toExist()
      expect(rootEntries.find('> .file:contains(sample.txt)')).toExist()
