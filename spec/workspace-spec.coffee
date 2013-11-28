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

  describe "::openSync(filePath, options)", ->
    describe "when the 'focus' option is true (the default)", ->
      it "sets the opened item as the active item of the active pane and focuses it", ->
        expect(workspace.activePane.hasFocus).toBe false
        editor1 = workspace.openSync()
        expect(workspace.activePane.items).toEqual [editor1]
        expect(workspace.activePaneItem).toBe editor1
        expect(workspace.activePane.hasFocus).toBe true
        editor2 = workspace.openSync('a')
        expect(workspace.activePane.items).toEqual [editor1, editor2]
        expect(workspace.activePaneItem).toBe editor2

    describe "when the 'changeFocus' option is false", ->
      it "sets the opened item as the active item of the active pane and focuses it", ->
        expect(workspace.activePane.hasFocus).toBe false
        editor1 = workspace.openSync('a', changeFocus: false)
        expect(workspace.activePane.items).toEqual [editor1]
        expect(workspace.activePaneItem).toBe editor1
        expect(workspace.activePane.hasFocus).toBe false
