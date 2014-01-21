Workspace = require '../src/workspace'

describe "Workspace", ->
  workspace = null

  beforeEach ->
    atom.project.setPath(atom.project.resolve('dir'))
    workspace = new Workspace

  describe "::openSync(uri, options)", ->
    [activePane, initialItemCount] = []

    beforeEach ->
      activePane = workspace.activePane
      spyOn(activePane, 'activate')
      initialItemCount = activePane.items.length

    describe "when called without a uri", ->
      it "adds and activates an empty editor on the active pane", ->
        editor = workspace.openSync()
        expect(activePane.items.length).toBe initialItemCount + 1
        expect(activePane.activeItem).toBe editor
        expect(editor.getPath()).toBeUndefined()
        expect(activePane.activate).toHaveBeenCalled()

    describe "when called with a uri", ->
      describe "when the active pane already has an editor for the given uri", ->
        it "activates the existing editor on the active pane", ->
          editor1 = workspace.openSync('a')
          editor2 = workspace.openSync('b')
          expect(activePane.activeItem).toBe editor2
          expect(activePane.items.length).toBe 2

          editor = workspace.openSync(editor1.getPath())
          expect(editor).toBe editor1
          expect(activePane.activeItem).toBe editor
          expect(activePane.activate).toHaveBeenCalled()
          expect(activePane.items.length).toBe 2

      describe "when the active pane does not have an editor for the given uri", ->
        it "adds and activates a new editor for the given path on the active pane", ->
          editor = workspace.openSync('a')
          expect(activePane.items.length).toBe 1
          expect(activePane.activeItem).toBe editor
          expect(activePane.activate).toHaveBeenCalled()

    describe "when the 'activatePane' option is false", ->
      it "does not activate the active pane", ->
        workspace.openSync('b', activatePane: false)
        expect(activePane.activate).not.toHaveBeenCalled()

    describe "when the 'split' option is specified", ->
      it "activates the editor on the active pane if it has a sibling and otherwise creates a new pane", ->
        pane1 = workspace.activePane

        editor = workspace.openSync('a', split: 'right')
        pane2 = workspace.activePane
        expect(pane2).not.toBe pane1

        expect(workspace.paneContainer.root.children).toEqual [pane1, pane2]

        editor = workspace.openSync('file1', split: 'right')
        expect(workspace.activePane).toBe pane2

        expect(workspace.paneContainer.root.children).toEqual [pane1, pane2]
        expect(pane1.items.length).toBe 0
        expect(pane2.items.length).toBe 2
