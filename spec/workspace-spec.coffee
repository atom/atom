{join} = require 'path'
Project = require '../src/project'
Workspace = require '../src/workspace'

describe "Workspace", ->
  [project, workspace] = []

  beforeEach ->
    project = new Project(path: join(@specDirectory, 'fixtures', 'dir'))
    workspace = Workspace.createAsRoot({project})

  afterEach ->
    project.destroy()

  describe "::openSync(uri, options)", ->
    it "finds or opens an editor for the given uri on the active pane", ->
      editor1 = workspace.openSync('a')
      expect(workspace.activePane.items).toEqual [editor1]
      expect(workspace.activePaneItem).toBe editor1

      editor2 = workspace.openSync()
      expect(workspace.activePane.items).toEqual [editor1, editor2]
      expect(workspace.activePaneItem).toBe editor2

      # don't recycle editors it the uri isn't defined
      editor3 = workspace.openSync()
      expect(editor3).not.toBe editor2
      expect(workspace.activePane.items).toEqual [editor1, editor2, editor3]
      expect(workspace.activePaneItem).toBe editor3

      # recycle editors with the same uri
      expect(workspace.openSync('a').id).toBe editor1.id
      expect(workspace.activePane.items).toEqual [editor1, editor2, editor3]
      expect(workspace.activePaneItem).toBe editor1

    it "focuses the pane if the 'changeFocus' option is not false", ->
      expect(workspace.activePane.hasFocus).toBe false
      editor1 = workspace.openSync('a', changeFocus: false)
      expect(workspace.activePane.hasFocus).toBe false
      editor1 = workspace.openSync('a')
      expect(workspace.activePane.hasFocus).toBe true
