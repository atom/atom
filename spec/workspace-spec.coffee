path = require 'path'
temp = require 'temp'
Workspace = require '../src/workspace'
{View} = require '../src/space-pen-extensions'

describe "Workspace", ->
  workspace = null

  beforeEach ->
    atom.project.setPaths([atom.project.resolve('dir')])
    atom.workspace = workspace = new Workspace

  describe "::open(uri, options)", ->
    openEvents = null

    beforeEach ->
      openEvents = []
      workspace.onDidOpen (event) -> openEvents.push(event)
      spyOn(workspace.getActivePane(), 'activate').andCallThrough()

    describe "when the 'searchAllPanes' option is false (default)", ->
      describe "when called without a uri", ->
        it "adds and activates an empty editor on the active pane", ->
          [editor1, editor2] = []

          waitsForPromise ->
            workspace.open().then (editor) -> editor1 = editor

          runs ->
            expect(editor1.getPath()).toBeUndefined()
            expect(workspace.getActivePane().items).toEqual [editor1]
            expect(workspace.getActivePaneItem()).toBe editor1
            expect(workspace.getActivePane().activate).toHaveBeenCalled()
            expect(openEvents).toEqual [{uri: undefined, pane: workspace.getActivePane(), item: editor1, index: 0}]
            openEvents = []

          waitsForPromise ->
            workspace.open().then (editor) -> editor2 = editor

          runs ->
            expect(editor2.getPath()).toBeUndefined()
            expect(workspace.getActivePane().items).toEqual [editor1, editor2]
            expect(workspace.getActivePaneItem()).toBe editor2
            expect(workspace.getActivePane().activate).toHaveBeenCalled()
            expect(openEvents).toEqual [{uri: undefined, pane: workspace.getActivePane(), item: editor2, index: 1}]

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
              expect(workspace.getActivePaneItem()).toBe editor
              expect(workspace.getActivePane().activate).toHaveBeenCalled()

              expect(openEvents).toEqual [
                {
                  uri: atom.project.resolve('a')
                  item: editor1
                  pane: atom.workspace.getActivePane()
                  index: 0
                }
                {
                  uri: atom.project.resolve('b')
                  item: editor2
                  pane: atom.workspace.getActivePane()
                  index: 1
                }
                {
                  uri: atom.project.resolve('a')
                  item: editor1
                  pane: atom.workspace.getActivePane()
                  index: 0
                }
              ]

        describe "when the active pane does not have an editor for the given uri", ->
          it "adds and activates a new editor for the given path on the active pane", ->
            editor = null
            waitsForPromise ->
              workspace.open('a').then (o) -> editor = o

            runs ->
              expect(editor.getUri()).toBe atom.project.resolve('a')
              expect(workspace.getActivePaneItem()).toBe editor
              expect(workspace.getActivePane().items).toEqual [editor]
              expect(workspace.getActivePane().activate).toHaveBeenCalled()

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
            expect(workspace.getActivePaneItem()).toBe editor2

          waitsForPromise ->
            workspace.open('a', searchAllPanes: true)

          runs ->
            expect(workspace.getActivePane()).toBe pane1
            expect(workspace.getActivePaneItem()).toBe editor1

      describe "when no editor for the given uri is open in any pane", ->
        it "opens an editor for the given uri in the active pane", ->
          editor = null
          waitsForPromise ->
            workspace.open('a', searchAllPanes: true).then (o) -> editor = o

          runs ->
            expect(workspace.getActivePaneItem()).toBe editor

    describe "when the 'split' option is set", ->
      describe "when the 'split' option is 'left'", ->
        it "opens the editor in the leftmost pane of the current pane axis", ->
          pane1 = workspace.getActivePane()
          pane2 = pane1.splitRight()
          expect(workspace.getActivePane()).toBe pane2

          editor = null
          waitsForPromise ->
            workspace.open('a', split: 'left').then (o) -> editor = o

          runs ->
            expect(workspace.getActivePane()).toBe pane1
            expect(pane1.items).toEqual [editor]
            expect(pane2.items).toEqual []

          # Focus right pane and reopen the file on the left
          waitsForPromise ->
            pane2.focus()
            workspace.open('a', split: 'left').then (o) -> editor = o

          runs ->
            expect(workspace.getActivePane()).toBe pane1
            expect(pane1.items).toEqual [editor]
            expect(pane2.items).toEqual []

      describe "when a pane axis is the leftmost sibling of the current pane", ->
        it "opens the new item in the current pane", ->
          editor = null
          pane1 = workspace.getActivePane()
          pane2 = pane1.splitLeft()
          pane3 = pane2.splitDown()
          pane1.activate()
          expect(workspace.getActivePane()).toBe pane1

          waitsForPromise ->
            workspace.open('a', split: 'left').then (o) -> editor = o

          runs ->
            expect(workspace.getActivePane()).toBe pane1
            expect(pane1.items).toEqual [editor]

      describe "when the 'split' option is 'right'", ->
        it "opens the editor in the rightmost pane of the current pane axis", ->
          editor = null
          pane1 = workspace.getActivePane()
          pane2 = null
          waitsForPromise ->
            workspace.open('a', split: 'right').then (o) -> editor = o

          runs ->
            pane2 = workspace.getPanes().filter((p) -> p != pane1)[0]
            expect(workspace.getActivePane()).toBe pane2
            expect(pane1.items).toEqual []
            expect(pane2.items).toEqual [editor]

          # Focus right pane and reopen the file on the right
          waitsForPromise ->
            pane1.focus()
            workspace.open('a', split: 'right').then (o) -> editor = o

          runs ->
            expect(workspace.getActivePane()).toBe pane2
            expect(pane1.items).toEqual []
            expect(pane2.items).toEqual [editor]

        describe "when a pane axis is the rightmost sibling of the current pane", ->
          it "opens the new item in a new pane split to the right of the current pane", ->
            editor = null
            pane1 = workspace.getActivePane()
            pane2 = pane1.splitRight()
            pane3 = pane2.splitDown()
            pane1.activate()
            expect(workspace.getActivePane()).toBe pane1
            pane4 = null

            waitsForPromise ->
              workspace.open('a', split: 'right').then (o) -> editor = o

            runs ->
              pane4 = workspace.getPanes().filter((p) -> p != pane1)[0]
              expect(workspace.getActivePane()).toBe pane4
              expect(pane4.items).toEqual [editor]
              expect(workspace.paneContainer.root.children[0]).toBe pane1
              expect(workspace.paneContainer.root.children[1]).toBe pane4

    describe "when passed a path that matches a custom opener", ->
      it "returns the resource returned by the custom opener", ->
        fooOpener = (pathToOpen, options) -> { foo: pathToOpen, options } if pathToOpen?.match(/\.foo/)
        barOpener = (pathToOpen) -> { bar: pathToOpen } if pathToOpen?.match(/^bar:\/\//)
        workspace.addOpener(fooOpener)
        workspace.addOpener(barOpener)

        waitsForPromise ->
          pathToOpen = atom.project.resolve('a.foo')
          workspace.open(pathToOpen, hey: "there").then (item) ->
            expect(item).toEqual { foo: pathToOpen, options: {hey: "there"} }

        waitsForPromise ->
          workspace.open("bar://baz").then (item) ->
            expect(item).toEqual { bar: "bar://baz" }

    it "notifies ::onDidAddTextEditor observers", ->
      absolutePath = require.resolve('./fixtures/dir/a')
      newEditorHandler = jasmine.createSpy('newEditorHandler')
      workspace.onDidAddTextEditor newEditorHandler

      editor = null
      waitsForPromise ->
        workspace.open(absolutePath).then (e) -> editor = e

      runs ->
        expect(newEditorHandler.argsForCall[0][0].textEditor).toBe editor

  describe "::reopenItem()", ->
    it "opens the uri associated with the last closed pane that isn't currently open", ->
      pane = workspace.getActivePane()
      waitsForPromise ->
        workspace.open('a').then ->
          workspace.open('b').then ->
            workspace.open('file1').then ->
              workspace.open()

      runs ->
        # does not reopen items with no uri
        expect(workspace.getActivePaneItem().getUri()).toBeUndefined()
        pane.destroyActiveItem()

      waitsForPromise ->
        workspace.reopenItem()

      runs ->
        expect(workspace.getActivePaneItem().getUri()).not.toBeUndefined()

        # destroy all items
        expect(workspace.getActivePaneItem().getUri()).toBe atom.project.resolve('file1')
        pane.destroyActiveItem()
        expect(workspace.getActivePaneItem().getUri()).toBe atom.project.resolve('b')
        pane.destroyActiveItem()
        expect(workspace.getActivePaneItem().getUri()).toBe atom.project.resolve('a')
        pane.destroyActiveItem()

        # reopens items with uris
        expect(workspace.getActivePaneItem()).toBeUndefined()

      waitsForPromise ->
        workspace.reopenItem()

      runs ->
        expect(workspace.getActivePaneItem().getUri()).toBe atom.project.resolve('a')

      # does not reopen items that are already open
      waitsForPromise ->
        workspace.open('b')

      runs ->
        expect(workspace.getActivePaneItem().getUri()).toBe atom.project.resolve('b')

      waitsForPromise ->
        workspace.reopenItem()

      runs ->
        expect(workspace.getActivePaneItem().getUri()).toBe atom.project.resolve('file1')

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
      runs -> expect(workspace.getActivePaneItem().getText()).toMatch /Copyright/

  describe "::observeTextEditors()", ->
    it "invokes the observer with current and future text editors", ->
      observed = []

      waitsForPromise -> workspace.open()
      waitsForPromise -> workspace.open()
      waitsForPromise -> workspace.openLicense()

      runs ->
        workspace.observeTextEditors (editor) -> observed.push(editor)

      waitsForPromise -> workspace.open()

      expect(observed).toEqual workspace.getTextEditors()

  describe "when an editor is destroyed", ->
    it "removes the editor", ->
      editor = null

      waitsForPromise ->
        workspace.open("a").then (e) -> editor = e

      runs ->
        expect(workspace.getTextEditors()).toHaveLength 1
        editor.destroy()
        expect(workspace.getTextEditors()).toHaveLength 0

  it "stores the active grammars used by all the open editors", ->
    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

    waitsForPromise ->
      atom.packages.activatePackage('language-coffee-script')

    waitsForPromise ->
      atom.packages.activatePackage('language-todo')

    waitsForPromise ->
      atom.workspace.open('sample.coffee')

    runs ->
      atom.workspace.getActiveTextEditor().setText """
        i = /test/; #FIXME
      """

      state = atom.workspace.serialize()
      expect(state.packagesWithActiveGrammars).toEqual ['language-coffee-script', 'language-javascript', 'language-todo']

      jsPackage = atom.packages.getLoadedPackage('language-javascript')
      coffeePackage = atom.packages.getLoadedPackage('language-coffee-script')
      spyOn(jsPackage, 'loadGrammarsSync')
      spyOn(coffeePackage, 'loadGrammarsSync')

      workspace2 = Workspace.deserialize(state)
      expect(jsPackage.loadGrammarsSync.callCount).toBe 1
      expect(coffeePackage.loadGrammarsSync.callCount).toBe 1

  describe "document.title", ->
    describe "when the project has no path", ->
      it "sets the title to 'untitled'", ->
        atom.project.setPaths([])
        expect(document.title).toBe 'untitled - Atom'

    describe "when the project has a path", ->
      beforeEach ->
        waitsForPromise ->
          atom.workspace.open('b')

      describe "when there is an active pane item", ->
        it "sets the title to the pane item's title plus the project path", ->
          item = atom.workspace.getActivePaneItem()
          expect(document.title).toBe "#{item.getTitle()} - #{atom.project.getPaths()[0]} - Atom"

      describe "when the title of the active pane item changes", ->
        it "updates the window title based on the item's new title", ->
          editor = atom.workspace.getActivePaneItem()
          editor.buffer.setPath(path.join(temp.dir, 'hi'))
          expect(document.title).toBe "#{editor.getTitle()} - #{atom.project.getPaths()[0]} - Atom"

      describe "when the active pane's item changes", ->
        it "updates the title to the new item's title plus the project path", ->
          atom.workspace.getActivePane().activateNextItem()
          item = atom.workspace.getActivePaneItem()
          expect(document.title).toBe "#{item.getTitle()} - #{atom.project.getPaths()[0]} - Atom"

      describe "when the last pane item is removed", ->
        it "updates the title to contain the project's path", ->
          atom.workspace.getActivePane().destroy()
          expect(atom.workspace.getActivePaneItem()).toBeUndefined()
          expect(document.title).toBe "#{atom.project.getPaths()[0]} - Atom"

      describe "when an inactive pane's item changes", ->
        it "does not update the title", ->
          pane = atom.workspace.getActivePane()
          pane.splitRight()
          initialTitle = document.title
          pane.activateNextItem()
          expect(document.title).toBe initialTitle

    describe "when the workspace is deserialized", ->
      beforeEach ->
        waitsForPromise -> atom.workspace.open('a')

      it "updates the title to contain the project's path", ->
        document.title = null
        workspace2 = atom.workspace.testSerialization()
        item = atom.workspace.getActivePaneItem()
        expect(document.title).toBe "#{item.getTitle()} - #{atom.project.getPaths()[0]} - Atom"
        workspace2.destroy()

  describe "document edited status", ->
    [item1, item2] = []

    beforeEach ->
      waitsForPromise -> atom.workspace.open('a')
      waitsForPromise -> atom.workspace.open('b')
      runs ->
        [item1, item2] = atom.workspace.getPaneItems()
        spyOn(atom, 'setDocumentEdited')

    it "calls atom.setDocumentEdited when the active item changes", ->
      expect(atom.workspace.getActivePaneItem()).toBe item2
      item1.insertText('a')
      expect(item1.isModified()).toBe true
      atom.workspace.getActivePane().activateNextItem()

      expect(atom.setDocumentEdited).toHaveBeenCalledWith(true)

    it "calls atom.setDocumentEdited when the active item's modified status changes", ->
      expect(atom.workspace.getActivePaneItem()).toBe item2
      item2.insertText('a')
      advanceClock(item2.getBuffer().getStoppedChangingDelay())

      expect(item2.isModified()).toBe true
      expect(atom.setDocumentEdited).toHaveBeenCalledWith(true)

      item2.undo()
      advanceClock(item2.getBuffer().getStoppedChangingDelay())

      expect(item2.isModified()).toBe false
      expect(atom.setDocumentEdited).toHaveBeenCalledWith(false)

  describe "adding panels", ->
    class TestItem

    class TestItemElement extends HTMLElement
      constructor: ->
      initialize: (@model) -> this
      getModel: -> @model

    beforeEach ->
      atom.views.addViewProvider TestItem, (model) ->
        new TestItemElement().initialize(model)

    describe '::addLeftPanel(model)', ->
      it 'adds a panel to the correct panel container', ->
        expect(atom.workspace.getLeftPanels().length).toBe(0)
        atom.workspace.panelContainers.left.onDidAddPanel addPanelSpy = jasmine.createSpy()

        model = new TestItem
        panel = atom.workspace.addLeftPanel(item: model)

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        itemView = atom.views.getView(atom.workspace.getLeftPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        expect(itemView.getModel()).toBe(model)

    describe '::addRightPanel(model)', ->
      it 'adds a panel to the correct panel container', ->
        expect(atom.workspace.getRightPanels().length).toBe(0)
        atom.workspace.panelContainers.right.onDidAddPanel addPanelSpy = jasmine.createSpy()

        model = new TestItem
        panel = atom.workspace.addRightPanel(item: model)

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        itemView = atom.views.getView(atom.workspace.getRightPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        expect(itemView.getModel()).toBe(model)

    describe '::addTopPanel(model)', ->
      it 'adds a panel to the correct panel container', ->
        expect(atom.workspace.getTopPanels().length).toBe(0)
        atom.workspace.panelContainers.top.onDidAddPanel addPanelSpy = jasmine.createSpy()

        model = new TestItem
        panel = atom.workspace.addTopPanel(item: model)

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        itemView = atom.views.getView(atom.workspace.getTopPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        expect(itemView.getModel()).toBe(model)

    describe '::addBottomPanel(model)', ->
      it 'adds a panel to the correct panel container', ->
        expect(atom.workspace.getBottomPanels().length).toBe(0)
        atom.workspace.panelContainers.bottom.onDidAddPanel addPanelSpy = jasmine.createSpy()

        model = new TestItem
        panel = atom.workspace.addBottomPanel(item: model)

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        itemView = atom.views.getView(atom.workspace.getBottomPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        expect(itemView.getModel()).toBe(model)

    describe '::addModalPanel(model)', ->
      it 'adds a panel to the correct panel container', ->
        expect(atom.workspace.getModalPanels().length).toBe(0)
        atom.workspace.panelContainers.modal.onDidAddPanel addPanelSpy = jasmine.createSpy()

        model = new TestItem
        panel = atom.workspace.addModalPanel(item: model)

        expect(panel).toBeDefined()
        expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})

        itemView = atom.views.getView(atom.workspace.getModalPanels()[0].getItem())
        expect(itemView instanceof TestItemElement).toBe(true)
        expect(itemView.getModel()).toBe(model)

    describe "::panelForItem(item)", ->
      it "returns the panel associated with the item", ->
        item = new TestItem
        panel = atom.workspace.addLeftPanel(item: item)

        itemWithNoPanel = new TestItem

        expect(atom.workspace.panelForItem(item)).toBe panel
        expect(atom.workspace.panelForItem(itemWithNoPanel)).toBe null
