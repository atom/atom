path = require 'path'
temp = require 'temp'
Workspace = require '../src/workspace'
Pane = require '../src/pane'
{View} = require '../src/space-pen-extensions'
platform = require './spec-helper-platform'
_ = require 'underscore-plus'
fstream = require 'fstream'
fs = require 'fs-plus'
Grim = require 'grim'

describe "Workspace", ->
  workspace = null

  beforeEach ->
    atom.project.setPaths([atom.project.getDirectories()[0]?.resolve('dir')])
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
                  uri: atom.project.getDirectories()[0]?.resolve('a')
                  item: editor1
                  pane: atom.workspace.getActivePane()
                  index: 0
                }
                {
                  uri: atom.project.getDirectories()[0]?.resolve('b')
                  item: editor2
                  pane: atom.workspace.getActivePane()
                  index: 1
                }
                {
                  uri: atom.project.getDirectories()[0]?.resolve('a')
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
              expect(editor.getURI()).toBe atom.project.getDirectories()[0]?.resolve('a')
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
          pathToOpen = atom.project.getDirectories()[0]?.resolve('a.foo')
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

    it "records a deprecation warning on the appropriate package if the item has a ::getUri method instead of ::getURI", ->
      jasmine.snapshotDeprecations()

      waitsForPromise -> atom.packages.activatePackage('package-with-deprecated-pane-item-method')

      waitsForPromise ->
        atom.workspace.open("test")

      runs ->
        deprecations = Grim.getDeprecations()
        expect(deprecations.length).toBe 1
        expect(deprecations[0].message).toBe "Pane item with class `TestItem` should implement `::getURI` instead of `::getUri`."
        expect(deprecations[0].getStacks()[0].metadata.packageName).toBe "package-with-deprecated-pane-item-method"
        jasmine.restoreDeprecationsSnapshot()

    describe "when there is an error opening the file", ->
      notificationSpy = null
      beforeEach ->
        atom.notifications.onDidAddNotification notificationSpy = jasmine.createSpy()

      describe "when a large file is opened", ->
        beforeEach ->
          spyOn(fs, 'getSizeSync').andReturn 2 * 1048577 # 2MB

        it "creates a notification", ->
          waitsForPromise ->
            workspace.open('file1')

          runs ->
            expect(notificationSpy).toHaveBeenCalled()
            notification = notificationSpy.mostRecentCall.args[0]
            expect(notification.getType()).toBe 'warning'
            expect(notification.getMessage()).toContain '< 2MB'

      describe "when a file does not exist", ->
        it "creates an empty buffer for the specified path", ->
          waitsForPromise ->
            workspace.open('not-a-file.md')

          runs ->
            editor = workspace.getActiveTextEditor()
            expect(notificationSpy).not.toHaveBeenCalled()
            expect(editor.getPath()).toContain 'not-a-file.md'

      describe "when the user does not have access to the file", ->
        beforeEach ->
          spyOn(fs, 'openSync').andCallFake (path) ->
            error = new Error("EACCES, permission denied '#{path}'")
            error.path = path
            error.code = 'EACCES'
            throw error

        it "creates a notification", ->
          waitsForPromise ->
            workspace.open('file1')

          runs ->
            expect(notificationSpy).toHaveBeenCalled()
            notification = notificationSpy.mostRecentCall.args[0]
            expect(notification.getType()).toBe 'warning'
            expect(notification.getMessage()).toContain 'Permission denied'
            expect(notification.getMessage()).toContain 'file1'

      describe "when the the operation is not permitted", ->
        beforeEach ->
          spyOn(fs, 'openSync').andCallFake (path) ->
            error = new Error("EPERM, operation not permitted '#{path}'")
            error.path = path
            error.code = 'EPERM'
            throw error

        it "creates a notification", ->
          waitsForPromise ->
            workspace.open('file1')

          runs ->
            expect(notificationSpy).toHaveBeenCalled()
            notification = notificationSpy.mostRecentCall.args[0]
            expect(notification.getType()).toBe 'warning'
            expect(notification.getMessage()).toContain 'Unable to open'
            expect(notification.getMessage()).toContain 'file1'

      describe "when the the file is already open in windows", ->
        beforeEach ->
          spyOn(fs, 'openSync').andCallFake (path) ->
            error = new Error("EBUSY, resource busy or locked '#{path}'")
            error.path = path
            error.code = 'EBUSY'
            throw error

        it "creates a notification", ->
          waitsForPromise ->
            workspace.open('file1')

          runs ->
            expect(notificationSpy).toHaveBeenCalled()
            notification = notificationSpy.mostRecentCall.args[0]
            expect(notification.getType()).toBe 'warning'
            expect(notification.getMessage()).toContain 'Unable to open'
            expect(notification.getMessage()).toContain 'file1'

      describe "when there is an unhandled error", ->
        beforeEach ->
          spyOn(fs, 'openSync').andCallFake (path) ->
            throw new Error("I dont even know what is happening right now!!")

        it "creates a notification", ->
          open = -> workspace.open('file1', workspace.getActivePane())
          expect(open).toThrow()

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
        expect(workspace.getActivePaneItem().getURI()).toBeUndefined()
        pane.destroyActiveItem()

      waitsForPromise ->
        workspace.reopenItem()

      runs ->
        expect(workspace.getActivePaneItem().getURI()).not.toBeUndefined()

        # destroy all items
        expect(workspace.getActivePaneItem().getURI()).toBe atom.project.getDirectories()[0]?.resolve('file1')
        pane.destroyActiveItem()
        expect(workspace.getActivePaneItem().getURI()).toBe atom.project.getDirectories()[0]?.resolve('b')
        pane.destroyActiveItem()
        expect(workspace.getActivePaneItem().getURI()).toBe atom.project.getDirectories()[0]?.resolve('a')
        pane.destroyActiveItem()

        # reopens items with uris
        expect(workspace.getActivePaneItem()).toBeUndefined()

      waitsForPromise ->
        workspace.reopenItem()

      runs ->
        expect(workspace.getActivePaneItem().getURI()).toBe atom.project.getDirectories()[0]?.resolve('a')

      # does not reopen items that are already open
      waitsForPromise ->
        workspace.open('b')

      runs ->
        expect(workspace.getActivePaneItem().getURI()).toBe atom.project.getDirectories()[0]?.resolve('b')

      waitsForPromise ->
        workspace.reopenItem()

      runs ->
        expect(workspace.getActivePaneItem().getURI()).toBe atom.project.getDirectories()[0]?.resolve('file1')

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

  describe "::scan(regex, options, callback)", ->
    describe "when called with a regex", ->
      it "calls the callback with all regex results in all files in the project", ->
        results = []
        waitsForPromise ->
          atom.workspace.scan /(a)+/, (result) ->
            results.push(result)

        runs ->
          expect(results).toHaveLength(3)
          expect(results[0].filePath).toBe atom.project.getDirectories()[0]?.resolve('a')
          expect(results[0].matches).toHaveLength(3)
          expect(results[0].matches[0]).toEqual
            matchText: 'aaa'
            lineText: 'aaa bbb'
            lineTextOffset: 0
            range: [[0, 0], [0, 3]]

      it "works with with escaped literals (like $ and ^)", ->
        results = []
        waitsForPromise ->
          atom.workspace.scan /\$\w+/, (result) -> results.push(result)

        runs ->
          expect(results.length).toBe 1

          {filePath, matches} = results[0]
          expect(filePath).toBe atom.project.getDirectories()[0]?.resolve('a')
          expect(matches).toHaveLength 1
          expect(matches[0]).toEqual
            matchText: '$bill'
            lineText: 'dollar$bill'
            lineTextOffset: 0
            range: [[2, 6], [2, 11]]

      it "works on evil filenames", ->
        platform.generateEvilFiles()
        atom.project.setPaths([path.join(__dirname, 'fixtures', 'evil-files')])
        paths = []
        matches = []
        waitsForPromise ->
          atom.workspace.scan /evil/, (result) ->
            paths.push(result.filePath)
            matches = matches.concat(result.matches)

        runs ->
          _.each(matches, (m) -> expect(m.matchText).toEqual 'evil')

          if platform.isWindows()
            expect(paths.length).toBe 3
            expect(paths[0]).toMatch /a_file_with_utf8.txt$/
            expect(paths[1]).toMatch /file with spaces.txt$/
            expect(path.basename(paths[2])).toBe "utfa\u0306.md"
          else
            expect(paths.length).toBe 5
            expect(paths[0]).toMatch /a_file_with_utf8.txt$/
            expect(paths[1]).toMatch /file with spaces.txt$/
            expect(paths[2]).toMatch /goddam\nnewlines$/m
            expect(paths[3]).toMatch /quote".txt$/m
            expect(path.basename(paths[4])).toBe "utfa\u0306.md"

      it "ignores case if the regex includes the `i` flag", ->
        results = []
        waitsForPromise ->
          atom.workspace.scan /DOLLAR/i, (result) -> results.push(result)

        runs ->
          expect(results).toHaveLength 1

      describe "when the core.excludeVcsIgnoredPaths config is truthy", ->
        [projectPath, ignoredPath] = []

        beforeEach ->
          sourceProjectPath = path.join(__dirname, 'fixtures', 'git', 'working-dir')
          projectPath = path.join(temp.mkdirSync("atom"))

          writerStream = fstream.Writer(projectPath)
          fstream.Reader(sourceProjectPath).pipe(writerStream)

          waitsFor (done) ->
            writerStream.on 'close', done
            writerStream.on 'error', done

          runs ->
            fs.rename(path.join(projectPath, 'git.git'), path.join(projectPath, '.git'))
            ignoredPath = path.join(projectPath, 'ignored.txt')
            fs.writeFileSync(ignoredPath, 'this match should not be included')

        afterEach ->
          fs.removeSync(projectPath) if fs.existsSync(projectPath)

        it "excludes ignored files", ->
          atom.project.setPaths([projectPath])
          atom.config.set('core.excludeVcsIgnoredPaths', true)
          resultHandler = jasmine.createSpy("result found")
          waitsForPromise ->
            atom.workspace.scan /match/, (results) ->
              resultHandler()

          runs ->
            expect(resultHandler).not.toHaveBeenCalled()

      it "includes only files when a directory filter is specified", ->
        projectPath = path.join(path.join(__dirname, 'fixtures', 'dir'))
        atom.project.setPaths([projectPath])

        filePath = path.join(projectPath, 'a-dir', 'oh-git')

        paths = []
        matches = []
        waitsForPromise ->
          atom.workspace.scan /aaa/, paths: ["a-dir#{path.sep}"], (result) ->
            paths.push(result.filePath)
            matches = matches.concat(result.matches)

        runs ->
          expect(paths.length).toBe 1
          expect(paths[0]).toBe filePath
          expect(matches.length).toBe 1

      it "includes files and folders that begin with a '.'", ->
        projectPath = temp.mkdirSync()
        filePath = path.join(projectPath, '.text')
        fs.writeFileSync(filePath, 'match this')
        atom.project.setPaths([projectPath])
        paths = []
        matches = []
        waitsForPromise ->
          atom.workspace.scan /match this/, (result) ->
            paths.push(result.filePath)
            matches = matches.concat(result.matches)

        runs ->
          expect(paths.length).toBe 1
          expect(paths[0]).toBe filePath
          expect(matches.length).toBe 1

      it "excludes values in core.ignoredNames", ->
        projectPath = path.join(__dirname, 'fixtures', 'git', 'working-dir')
        ignoredNames = atom.config.get("core.ignoredNames")
        ignoredNames.push("a")
        atom.config.set("core.ignoredNames", ignoredNames)

        resultHandler = jasmine.createSpy("result found")
        waitsForPromise ->
          atom.workspace.scan /dollar/, (results) ->
            resultHandler()

        runs ->
          expect(resultHandler).not.toHaveBeenCalled()

      it "scans buffer contents if the buffer is modified", ->
        editor = null
        results = []

        waitsForPromise ->
          atom.project.open('a').then (o) ->
            editor = o
            editor.setText("Elephant")

        waitsForPromise ->
          atom.workspace.scan /a|Elephant/, (result) -> results.push result

        runs ->
          expect(results).toHaveLength 3
          resultForA = _.find results, ({filePath}) -> path.basename(filePath) == 'a'
          expect(resultForA.matches).toHaveLength 1
          expect(resultForA.matches[0].matchText).toBe 'Elephant'

      it "ignores buffers outside the project", ->
        editor = null
        results = []

        waitsForPromise ->
          atom.project.open(temp.openSync().path).then (o) ->
            editor = o
            editor.setText("Elephant")

        waitsForPromise ->
          atom.workspace.scan /Elephant/, (result) -> results.push result

        runs ->
          expect(results).toHaveLength 0

      describe "when the project has multiple root directories", ->
        [dir1, dir2, file1, file2] = []

        beforeEach ->
          [dir1] = atom.project.getPaths()
          file1 = path.join(dir1, "a-dir", "oh-git")

          dir2 = temp.mkdirSync("a-second-dir")
          aDir2 = path.join(dir2, "a-dir")
          file2 = path.join(aDir2, "a-file")
          fs.mkdirSync(aDir2)
          fs.writeFileSync(file2, "ccc aaaa")

          atom.project.addPath(dir2)

        it "searches matching files in all of the project's root directories", ->
          resultPaths = []
          waitsForPromise ->
            atom.workspace.scan /aaaa/, ({filePath}) ->
              resultPaths.push(filePath)

          runs ->
            expect(resultPaths.sort()).toEqual([file1, file2].sort())

        describe "when an inclusion path starts with the basename of a root directory", ->
          it "interprets the inclusion path as starting from that directory", ->
            waitsForPromise ->
              resultPaths = []
              atom.workspace
                .scan /aaaa/, paths: ["dir"], ({filePath}) ->
                  resultPaths.push(filePath) unless filePath in resultPaths
                .then ->
                  expect(resultPaths).toEqual([file1])

            waitsForPromise ->
              resultPaths = []
              atom.workspace
                .scan /aaaa/, paths: [path.join("dir", "a-dir")], ({filePath}) ->
                  resultPaths.push(filePath) unless filePath in resultPaths
                .then ->
                  expect(resultPaths).toEqual([file1])

            waitsForPromise ->
              resultPaths = []
              atom.workspace
                .scan /aaaa/, paths: [path.basename(dir2)], ({filePath}) ->
                  resultPaths.push(filePath) unless filePath in resultPaths
                .then ->
                  expect(resultPaths).toEqual([file2])

            waitsForPromise ->
              resultPaths = []
              atom.workspace
                .scan /aaaa/, paths: [path.join(path.basename(dir2), "a-dir")], ({filePath}) ->
                  resultPaths.push(filePath) unless filePath in resultPaths
                .then ->
                  expect(resultPaths).toEqual([file2])

  describe "::replace(regex, replacementText, paths, iterator)", ->
    [filePath, commentFilePath, sampleContent, sampleCommentContent] = []

    beforeEach ->
      atom.project.setPaths([atom.project.getDirectories()[0]?.resolve('../')])

      filePath = atom.project.getDirectories()[0]?.resolve('sample.js')
      commentFilePath = atom.project.getDirectories()[0]?.resolve('sample-with-comments.js')
      sampleContent = fs.readFileSync(filePath).toString()
      sampleCommentContent = fs.readFileSync(commentFilePath).toString()

    afterEach ->
      fs.writeFileSync(filePath, sampleContent)
      fs.writeFileSync(commentFilePath, sampleCommentContent)

    describe "when a file doesn't exist", ->
      it "calls back with an error", ->
        errors = []
        missingPath = path.resolve('/not-a-file.js')
        expect(fs.existsSync(missingPath)).toBeFalsy()

        waitsForPromise ->
          atom.workspace.replace /items/gi, 'items', [missingPath], (result, error) ->
            errors.push(error)

        runs ->
          expect(errors).toHaveLength 1
          expect(errors[0].path).toBe missingPath

    describe "when called with unopened files", ->
      it "replaces properly", ->
        results = []
        waitsForPromise ->
          atom.workspace.replace /items/gi, 'items', [filePath], (result) ->
            results.push(result)

        runs ->
          expect(results).toHaveLength 1
          expect(results[0].filePath).toBe filePath
          expect(results[0].replacements).toBe 6

    describe "when a buffer is already open", ->
      it "replaces properly and saves when not modified", ->
        editor = null
        results = []

        waitsForPromise ->
          atom.project.open('sample.js').then (o) -> editor = o

        runs ->
          expect(editor.isModified()).toBeFalsy()

        waitsForPromise ->
          atom.workspace.replace /items/gi, 'items', [filePath], (result) ->
            results.push(result)

        runs ->
          expect(results).toHaveLength 1
          expect(results[0].filePath).toBe filePath
          expect(results[0].replacements).toBe 6

          expect(editor.isModified()).toBeFalsy()

      it "does not replace when the path is not specified", ->
        editor = null
        results = []

        waitsForPromise ->
          atom.project.open('sample-with-comments.js').then (o) -> editor = o

        waitsForPromise ->
          atom.workspace.replace /items/gi, 'items', [commentFilePath], (result) ->
            results.push(result)

        runs ->
          expect(results).toHaveLength 1
          expect(results[0].filePath).toBe commentFilePath

      it "does NOT save when modified", ->
        editor = null
        results = []

        waitsForPromise ->
          atom.project.open('sample.js').then (o) -> editor = o

        runs ->
          editor.buffer.setTextInRange([[0,0],[0,0]], 'omg')
          expect(editor.isModified()).toBeTruthy()

        waitsForPromise ->
          atom.workspace.replace /items/gi, 'okthen', [filePath], (result) ->
            results.push(result)

        runs ->
          expect(results).toHaveLength 1
          expect(results[0].filePath).toBe filePath
          expect(results[0].replacements).toBe 6

          expect(editor.isModified()).toBeTruthy()

  describe "::saveActivePaneItem()", ->
    editor = null
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('sample.js').then (o) -> editor = o

    describe "when there is an error", ->
      it "emits a warning notification when the file cannot be saved", ->
        spyOn(editor, 'save').andCallFake ->
          throw new Error("'/some/file' is a directory")

        atom.notifications.onDidAddNotification addedSpy = jasmine.createSpy()
        atom.workspace.saveActivePaneItem()
        expect(addedSpy).toHaveBeenCalled()
        expect(addedSpy.mostRecentCall.args[0].getType()).toBe 'warning'

      it "emits a warning notification when the directory cannot be written to", ->
        spyOn(editor, 'save').andCallFake ->
          throw new Error("ENOTDIR, not a directory '/Some/dir/and-a-file.js'")

        atom.notifications.onDidAddNotification addedSpy = jasmine.createSpy()
        atom.workspace.saveActivePaneItem()
        expect(addedSpy).toHaveBeenCalled()
        expect(addedSpy.mostRecentCall.args[0].getType()).toBe 'warning'

      it "emits a warning notification when the user does not have permission", ->
        spyOn(editor, 'save').andCallFake ->
          error = new Error("EACCES, permission denied '/Some/dir/and-a-file.js'")
          error.code = 'EACCES'
          error.path = '/Some/dir/and-a-file.js'
          throw error

        atom.notifications.onDidAddNotification addedSpy = jasmine.createSpy()
        atom.workspace.saveActivePaneItem()
        expect(addedSpy).toHaveBeenCalled()
        expect(addedSpy.mostRecentCall.args[0].getType()).toBe 'warning'

      it "emits a warning notification when the operation is not permitted", ->
        spyOn(editor, 'save').andCallFake ->
          error = new Error("EPERM, operation not permitted '/Some/dir/and-a-file.js'")
          error.code = 'EPERM'
          error.path = '/Some/dir/and-a-file.js'
          throw error

      it "emits a warning notification when the file is already open by another app", ->
        spyOn(editor, 'save').andCallFake ->
          error = new Error("EBUSY, resource busy or locked '/Some/dir/and-a-file.js'")
          error.code = 'EBUSY'
          error.path = '/Some/dir/and-a-file.js'
          throw error

        atom.notifications.onDidAddNotification addedSpy = jasmine.createSpy()
        atom.workspace.saveActivePaneItem()
        expect(addedSpy).toHaveBeenCalled()

        notificaiton = addedSpy.mostRecentCall.args[0]
        expect(notificaiton.getType()).toBe 'warning'
        expect(notificaiton.getMessage()).toContain 'Unable to save'

      it "emits a warning notification when the file system is read-only", ->
        spyOn(editor, 'save').andCallFake ->
          error = new Error("EROFS, read-only file system '/Some/dir/and-a-file.js'")
          error.code = 'EROFS'
          error.path = '/Some/dir/and-a-file.js'
          throw error

        atom.notifications.onDidAddNotification addedSpy = jasmine.createSpy()
        atom.workspace.saveActivePaneItem()
        expect(addedSpy).toHaveBeenCalled()

        notification = addedSpy.mostRecentCall.args[0]
        expect(notification.getType()).toBe 'warning'
        expect(notification.getMessage()).toContain 'Unable to save'

      it "emits a warning notification when the file cannot be saved", ->
        spyOn(editor, 'save').andCallFake ->
          throw new Error("no one knows")

        save = -> atom.workspace.saveActivePaneItem()
        expect(save).toThrow()
