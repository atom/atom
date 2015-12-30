Workspace = require '../src/workspace'

describe "Workspace", ->
  workspace = null

  beforeEach ->
    atom.project.setPath(atom.project.resolve('dir'))
    atom.workspace = workspace = new Workspace

  describe "::open(uri, options)", ->
    beforeEach ->
      spyOn(workspace.activePane, 'activate').andCallThrough()

    describe "when the 'searchAllPanes' option is false (default)", ->
      describe "when called without a uri", ->
        it "adds and activates an empty editor on the active pane", ->
          [editor1, editor2] = []

          waitsForPromise ->
            workspace.open().then (editor) -> editor1 = editor

          runs ->
            expect(editor1.getPath()).toBeUndefined()
            expect(workspace.activePane.items).toEqual [editor1]
            expect(workspace.activePaneItem).toBe editor1
            expect(workspace.activePane.activate).toHaveBeenCalled()

          waitsForPromise ->
            workspace.open().then (editor) -> editor2 = editor

          runs ->
            expect(editor2.getPath()).toBeUndefined()
            expect(workspace.activePane.items).toEqual [editor1, editor2]
            expect(workspace.activePaneItem).toBe editor2
            expect(workspace.activePane.activate).toHaveBeenCalled()

      describe "when called with a uri", ->
        describe "when the active pane already has an editor for the given uri", ->
          it "activates the existing editor on the active pane", ->
            editor = null
            editor1 = null
            editor2 = null

            waitsForPromise ->
              workspace.open('a').then (o) ->
                editor1 = o
                workspace.open('b').then (o) ->
                  editor2 = o
                  workspace.open('a').then (o) ->
                    editor = o

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
          editor1 = null
          editor2 = null
          pane1 = workspace.getActivePane()
          pane2 = workspace.getActivePane().splitRight()

          waitsForPromise ->
            pane1.activate()
            workspace.open('a').then (o) -> editor1 = o

          waitsForPromise ->
            pane2.activate()
            workspace.open('b').then (o) -> editor2 = o

          runs ->
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

      describe "when a pane axis is the leftmost sibling of the current pane", ->
        it "opens the new item in the current pane", ->
          editor = null
          pane1 = workspace.activePane
          pane2 = pane1.splitLeft()
          pane3 = pane2.splitDown()
          pane1.activate()
          expect(workspace.activePane).toBe pane1

          waitsForPromise ->
            workspace.open('a', split: 'left').then (o) -> editor = o

          runs ->
            expect(workspace.activePane).toBe pane1
            expect(pane1.items).toEqual [editor]

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

        describe "when a pane axis is the rightmost sibling of the current pane", ->
          it "opens the new item in a new pane split to the right of the current pane", ->
            editor = null
            pane1 = workspace.activePane
            pane2 = pane1.splitRight()
            pane3 = pane2.splitDown()
            pane1.activate()
            expect(workspace.activePane).toBe pane1
            pane4 = null

            waitsForPromise ->
              workspace.open('a', split: 'right').then (o) -> editor = o

            runs ->
              pane4 = workspace.getPanes().filter((p) -> p != pane1)[0]
              expect(workspace.activePane).toBe pane4
              expect(pane4.items).toEqual [editor]
              expect(workspace.paneContainer.root.children[0]).toBe pane1
              expect(workspace.paneContainer.root.children[1]).toBe pane4

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

    it "emits an 'editor-created' event", ->
      absolutePath = require.resolve('./fixtures/dir/a')
      newEditorHandler = jasmine.createSpy('newEditorHandler')
      workspace.on 'editor-created', newEditorHandler

      editor = null
      waitsForPromise ->
        workspace.open(absolutePath).then (e) -> editor = e

      runs ->
        expect(newEditorHandler).toHaveBeenCalledWith editor

  describe "::reopenItem()", ->
    it "opens the uri associated with the last closed pane that isn't currently open", ->
      pane = workspace.activePane
      waitsForPromise ->
        workspace.open('a').then ->
          workspace.open('b').then ->
            workspace.open('file1').then ->
              workspace.open()

      runs ->
        # does not reopen items with no uri
        expect(workspace.activePaneItem.getUri()).toBeUndefined()
        pane.destroyActiveItem()

      waitsForPromise ->
        workspace.reopenItem()

      runs ->
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

      waitsForPromise ->
        workspace.reopenItem()

      runs ->
        expect(workspace.activePaneItem.getUri()).toBe atom.project.resolve('a')

      # does not reopen items that are already open
      waitsForPromise ->
        workspace.open('b')

      runs ->
        expect(workspace.activePaneItem.getUri()).toBe atom.project.resolve('b')

      waitsForPromise ->
        workspace.reopenItem()

      runs ->
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

  describe "when an editor is destroyed", ->
    it "removes the editor", ->
      editor = null

      waitsForPromise ->
        workspace.open("a").then (e) -> editor = e

      runs ->
        expect(workspace.getEditors()).toHaveLength 1
        editor.destroy()
        expect(workspace.getEditors()).toHaveLength 0

  describe "when an editor is copied", ->
    it "emits an 'editor-created' event", ->
      editor = null
      handler = jasmine.createSpy('editorCreatedHandler')
      workspace.on 'editor-created', handler

      waitsForPromise ->
        workspace.open("a").then (o) -> editor = o

      runs ->
        expect(handler.callCount).toBe 1
        editorCopy = editor.copy()
        expect(handler.callCount).toBe 2

  it "stores the active grammars used by all the open editors", ->
    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.packages.activatePackage('language-coffee-script')

    waitsForPromise ->
      atom.workspace.open('sample.coffee')

    runs ->
      atom.workspace.getActiveEditor().setText('i = /test/;')

      state = atom.workspace.serialize()
      expect(state.packagesWithActiveGrammars).toEqual ['language-coffee-script', 'language-javascript']

      jsPackage = atom.packages.getLoadedPackage('language-javascript')
      coffeePackage = atom.packages.getLoadedPackage('language-coffee-script')
      spyOn(jsPackage, 'loadGrammarsSync')
      spyOn(coffeePackage, 'loadGrammarsSync')

      workspace2 = Workspace.deserialize(state)
      expect(jsPackage.loadGrammarsSync.callCount).toBe 1
      expect(coffeePackage.loadGrammarsSync.callCount).toBe 1
