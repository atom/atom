Workspace = require '../src/workspace'

describe "Workspace", ->
  workspace = null

  beforeEach ->
    atom.project.setPath(atom.project.resolve('dir'))
    workspace = new Workspace

  describe "::open(uri, options)", ->
    beforeEach ->
      spyOn(workspace.activePane, 'activate').andCallThrough()

    describe "when the 'searchAllPanes' option is false (default)", ->
      describe "when called without a uri", ->
        it "adds and activates an empty editor on the active pane", ->
          editor = null
          waitsForPromise ->
            workspace.open().then (o) -> editor = o

          runs ->
            expect(editor.getPath()).toBeUndefined()
            expect(workspace.activePane.items).toEqual [editor]
            expect(workspace.activePaneItem).toBe editor
            expect(workspace.activePane.activate).toHaveBeenCalled()

      describe "when called with a uri", ->
        describe "when the active pane already has an editor for the given uri", ->
          it "activates the existing editor on the active pane", ->
            editor1 = workspace.openSync('a')
            editor2 = workspace.openSync('b')

            editor = null
            waitsForPromise ->
              workspace.open('a').then (o) -> editor = o

            runs ->
              expect(editor).toBe editor1
              expect(workspace.activePaneItem).toBe editor
              expect(workspace.activePane.activate).toHaveBeenCalled()

        describe "when the active pane does not have an editor for the given uri", ->
          it "adds and activates a new editor for the given path on the active pane", ->
            editor = null
            waitsForPromise ->
              workspace.open('a').then (o) -> editor = o

            runs ->
              expect(editor.getUri()).toBe atom.project.resolve('a')
              expect(workspace.activePaneItem).toBe editor
              expect(workspace.activePane.items).toEqual [editor]
              expect(workspace.activePane.activate).toHaveBeenCalled()

    describe "when the 'searchAllPanes' option is true", ->
      describe "when an editor for the given uri is already open on an inactive pane", ->
        it "activates the existing editor on the inactive pane, then activates that pane", ->
          editor1 = workspace.openSync('a')
          pane1 = workspace.activePane
          pane2 = workspace.activePane.splitRight()
          editor2 = workspace.openSync('b')
          expect(workspace.activePaneItem).toBe editor2

          waitsForPromise ->
            workspace.open('a', searchAllPanes: true)

          runs ->
            expect(workspace.activePane).toBe pane1
            expect(workspace.activePaneItem).toBe editor1

      describe "when no editor for the given uri is open in any pane", ->
        it "opens an editor for the given uri in the active pane", ->
          editor = null
          waitsForPromise ->
            workspace.open('a', searchAllPanes: true).then (o) -> editor = o

          runs ->
            expect(workspace.activePaneItem).toBe editor

    describe "when the 'split' option is set", ->
      describe "when the 'split' option is 'left'", ->
        it "opens the editor in the leftmost pane of the current pane axis", ->
          pane1 = workspace.activePane
          pane2 = pane1.splitRight()
          expect(workspace.activePane).toBe pane2

          editor = null
          waitsForPromise ->
            workspace.open('a', split: 'left').then (o) -> editor = o

          runs ->
            expect(workspace.activePane).toBe pane1
            expect(pane1.items).toEqual [editor]
            expect(pane2.items).toEqual []

          # Focus right pane and reopen the file on the left
          waitsForPromise ->
            pane2.focus()
            workspace.open('a', split: 'left').then (o) -> editor = o

          runs ->
            expect(workspace.activePane).toBe pane1
            expect(pane1.items).toEqual [editor]
            expect(pane2.items).toEqual []

      describe "when the 'split' option is 'right'", ->
        it "opens the editor in the rightmost pane of the current pane axis", ->
          editor = null
          pane1 = workspace.activePane
          pane2 = null
          waitsForPromise ->
            workspace.open('a', split: 'right').then (o) -> editor = o

          runs ->
            pane2 = workspace.getPanes().filter((p) -> p != pane1)[0]
            expect(workspace.activePane).toBe pane2
            expect(pane1.items).toEqual []
            expect(pane2.items).toEqual [editor]

          # Focus right pane and reopen the file on the right
          waitsForPromise ->
            pane1.focus()
            workspace.open('a', split: 'right').then (o) -> editor = o

          runs ->
            expect(workspace.activePane).toBe pane2
            expect(pane1.items).toEqual []
            expect(pane2.items).toEqual [editor]

    describe "when passed a path that matches a custom opener", ->
      it "returns the resource returned by the custom opener", ->
        fooOpener = (pathToOpen, options) -> { foo: pathToOpen, options } if pathToOpen?.match(/\.foo/)
        barOpener = (pathToOpen) -> { bar: pathToOpen } if pathToOpen?.match(/^bar:\/\//)
        workspace.registerOpener(fooOpener)
        workspace.registerOpener(barOpener)

        waitsForPromise ->
          pathToOpen = atom.project.resolve('a.foo')
          workspace.open(pathToOpen, hey: "there").then (item) ->
            expect(item).toEqual { foo: pathToOpen, options: {hey: "there"} }

        waitsForPromise ->
          workspace.open("bar://baz").then (item) ->
            expect(item).toEqual { bar: "bar://baz" }

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

  describe "::reopenItemSync()", ->
    it "opens the uri associated with the last closed pane that isn't currently open", ->
      pane = workspace.activePane
      workspace.openSync('a')
      workspace.openSync('b')
      workspace.openSync('file1')
      workspace.openSync()

      # does not reopen items with no uri
      expect(workspace.activePaneItem.getUri()).toBeUndefined()
      pane.destroyActiveItem()
      workspace.reopenItemSync()
      expect(workspace.activePaneItem.getUri()).not.toBeUndefined()

      # destroy all items
      expect(workspace.activePaneItem.getUri()).toBe atom.project.resolve('file1')
      pane.destroyActiveItem()
      expect(workspace.activePaneItem.getUri()).toBe atom.project.resolve('b')
      pane.destroyActiveItem()
      expect(workspace.activePaneItem.getUri()).toBe atom.project.resolve('a')
      pane.destroyActiveItem()

      # reopens items with uris
      expect(workspace.activePaneItem).toBeUndefined()
      workspace.reopenItemSync()
      expect(workspace.activePaneItem.getUri()).toBe atom.project.resolve('a')

      # does not reopen items that are already open
      workspace.openSync('b')
      expect(workspace.activePaneItem.getUri()).toBe atom.project.resolve('b')
      workspace.reopenItemSync()
      expect(workspace.activePaneItem.getUri()).toBe atom.project.resolve('file1')

  describe "::increase/decreaseFontSize()", ->
    it "increases/decreases the font size without going below 1", ->
      atom.config.set('editor.fontSize', 1)
      workspace.increaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe 2
      workspace.increaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe 3
      workspace.decreaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe 2
      workspace.decreaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe 1
      workspace.decreaseFontSize()
      expect(atom.config.get('editor.fontSize')).toBe 1

  describe "::openLicense()", ->
    it "opens the license as plain-text in a buffer", ->
      waitsForPromise -> workspace.openLicense()
      runs -> expect(workspace.activePaneItem.getText()).toMatch /Copyright/
