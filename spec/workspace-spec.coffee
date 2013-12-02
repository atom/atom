{join} = require 'path'
{Model} = require 'telepath'
Project = require '../src/project'
Workspace = require '../src/workspace'

describe "Workspace", ->
  [project, workspace] = []

  beforeEach ->
    project = new Project(path: join(@specDirectory, 'fixtures', 'dir'))
    workspace = Workspace.createAsRoot({project})

  afterEach ->
    project.destroy()

  describe "::open(uri, options)", ->
    it "asynchronously finds or opens an editor for the given uri on the active pane", ->
      [editor1, editor2, editor3] = []

      waitsForPromise ->
        workspace.open('a').then (editor) -> editor1 = editor

      runs ->
        expect(workspace.activePane.items).toEqual [editor1]
        expect(workspace.activePaneItem).toBe editor1

      waitsForPromise ->
        workspace.open().then (editor) -> editor2 = editor

      runs ->
        expect(workspace.activePane.items).toEqual [editor1, editor2]
        expect(workspace.activePaneItem).toBe editor2

      # don't recycle editors it the uri isn't defined
      waitsForPromise ->
        workspace.open().then (editor) -> editor3 = editor

      runs ->
        expect(editor3).not.toBe editor2
        expect(workspace.activePane.items).toEqual [editor1, editor2, editor3]
        expect(workspace.activePaneItem).toBe editor3

      # recycle editors with the same uri
      waitsForPromise ->
        workspace.open('a').then (editor) -> expect(editor).toBe editor1

      runs ->
        expect(workspace.activePane.items).toEqual [editor1, editor2, editor3]
        expect(workspace.activePaneItem).toBe editor1

    it "focuses the pane after opening if the 'changeFocus' option is not false", ->
      expect(workspace.activePane.hasFocus).toBe false
      waitsForPromise -> workspace.open('a', changeFocus: false)
      runs -> expect(workspace.activePane.hasFocus).toBe false
      waitsForPromise -> workspace.open('a')
      runs -> expect(workspace.activePane.hasFocus).toBe true

  describe "::openSync(uri, options)", ->
    it "synchronously finds or opens an editor for the given uri on the active pane", ->
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

    it "focuses the pane after opening if the 'changeFocus' option is not false", ->
      expect(workspace.activePane.hasFocus).toBe false
      editor1 = workspace.openSync('a', changeFocus: false)
      expect(workspace.activePane.hasFocus).toBe false
      editor1 = workspace.openSync('a')
      expect(workspace.activePane.hasFocus).toBe true

  describe "::editors", ->
    class Item extends Model

    it "contains all editor pane items", ->
      editor1 = workspace.openSync()
      editor2 = workspace.openSync('a', split: 'right')
      otherItem = new Item
      workspace.activePane.addItem(otherItem)

      expect(workspace.paneItems).toEqual [editor1, editor2, otherItem]
      expect(workspace.editors).toEqual [editor1, editor2]
