TreeView = require 'tree-view'
Directory = require 'directory'

describe "TreeView", ->
  [project, treeView] = []

  beforeEach ->
    project = new Directory(require.resolve('fixtures/'))
    treeView = new TreeView(project)

  describe ".initialize(project)", ->
    it "renders the root of the project and its contents, with subdirectories collapsed", ->
      root = treeView.find('> li:first')
      expect(root.find('> .disclosure')).toHaveText('▾')
      expect(root.find('> .name')).toHaveText('fixtures/')

      rootEntries = root.find('.entries')
      subdir = rootEntries.find('> li.directory:contains(dir/)')
      expect(subdir).toExist()
      expect(subdir.find('.disclosure')).toHaveText('▸')
      expect(subdir.find('.entries')).not.toExist()

      expect(rootEntries.find('> .file:contains(sample.js)')).toExist()
      expect(rootEntries.find('> .file:contains(sample.txt)')).toExist()
