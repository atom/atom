$ = require 'jquery'
fs = require 'fs'
RootView = require 'root-view'
Buffer = require 'buffer'
Editor = require 'editor'
{View} = require 'space-pen'

describe "RootView", ->
  rootView = null
  path = null

  beforeEach ->
    path = require.resolve 'fixtures/dir/a'
    rootView = new RootView(path)
    rootView.enableKeymap()
    rootView.focus()

  afterEach ->
    rootView.remove()

  describe "initialize(pathToOpen)", ->
    describe "when called with a pathToOpen", ->
      describe "when pathToOpen references a file", ->
        it "creates a project for the file's parent directory, then sets the document.title and opens the file in an editor", ->
          expect(rootView.project.getPath()).toBe fs.directory(path)
          expect(rootView.getEditors().length).toBe 1
          expect(rootView.getEditors()[0]).toHaveClass 'active'
          expect(rootView.getActiveEditor().getPath()).toBe path
          expect(rootView.getActiveEditor().editSessions.length).toBe 1
          expect(document.title).toBe path

      describe "when pathToOpen references a directory", ->
        beforeEach ->
          rootView.remove()

        it "creates a project for the directory and sets the document.title, but does not open an editor", ->
          path = require.resolve 'fixtures/dir'
          rootView = new RootView(path)
          rootView.focus()

          expect(rootView.project.getPath()).toBe path
          expect(rootView.getEditors().length).toBe 0
          expect(document.title).toBe path

    describe "when called with view state data returned from a previous call to RootView.prototype.serialize", ->
      viewState = null

      describe "when the serialized RootView has an unsaved buffer", ->
        buffer = null

        beforeEach ->
          rootView.remove()
          rootView = new RootView
          rootView.open()
          editor1 = rootView.getActiveEditor()
          buffer = editor1.getBuffer()
          editor1.splitRight()
          viewState = rootView.serialize()

        it "constructs the view with the same panes", ->
          rootView = RootView.deserialize(viewState)
          expect(rootView.project.getPath()?).toBeFalsy()
          expect(rootView.getEditors().length).toBe 2
          expect(rootView.getActiveEditor().getText()).toBe buffer.getText()
          expect(document.title).toBe 'untitled'

      describe "when the serialized RootView has a project", ->
        beforeEach ->
          path = require.resolve 'fixtures'
          rootView.remove()
          rootView = new RootView(path)
          rootView.open('dir/a')

          editor1 = rootView.getActiveEditor()
          editor2 = editor1.splitRight()
          editor3 = editor2.splitRight()
          editor4 = editor2.splitDown()
          editor2.edit(rootView.project.buildEditSessionForPath('dir/b'))
          editor3.edit(rootView.project.buildEditSessionForPath('sample.js'))
          editor3.setCursorScreenPosition([2, 3])
          editor4.edit(rootView.project.buildEditSessionForPath('sample.txt'))
          editor4.setCursorScreenPosition([0, 2])
          rootView.attachToDom()
          editor2.focus()
          viewState = rootView.serialize()
          rootView.remove()

        it "constructs the view with the same project and panes", ->
          rootView = RootView.deserialize(viewState)
          rootView.attachToDom()

          expect(rootView.getEditors().length).toBe 4
          editor1 = rootView.panes.find('.row > .pane .editor:eq(0)').view()
          editor3 = rootView.panes.find('.row > .pane .editor:eq(1)').view()
          editor2 = rootView.panes.find('.row > .column > .pane .editor:eq(0)').view()
          editor4 = rootView.panes.find('.row > .column > .pane .editor:eq(1)').view()

          expect(editor1.getPath()).toBe require.resolve('fixtures/dir/a')
          expect(editor2.getPath()).toBe require.resolve('fixtures/dir/b')
          expect(editor3.getPath()).toBe require.resolve('fixtures/sample.js')
          expect(editor3.getCursorScreenPosition()).toEqual [2, 3]
          expect(editor4.getPath()).toBe require.resolve('fixtures/sample.txt')
          expect(editor4.getCursorScreenPosition()).toEqual [0, 2]

          # ensure adjust pane dimensions is called
          expect(editor1.width()).toBeGreaterThan 0
          expect(editor2.width()).toBeGreaterThan 0
          expect(editor3.width()).toBeGreaterThan 0
          expect(editor4.width()).toBeGreaterThan 0

          # ensure correct editor is focused again
          expect(editor2.isFocused).toBeTruthy()
          expect(editor1.isFocused).toBeFalsy()
          expect(editor3.isFocused).toBeFalsy()
          expect(editor4.isFocused).toBeFalsy()

          expect(document.title).toBe editor2.getPath()

    describe "when called with no pathToOpen", ->
      it "opens no buffer", ->
        rootView.remove()
        rootView = new RootView
        expect(rootView.getEditors().length).toBe 0
        expect(document.title).toBe 'untitled'

  describe ".serialize()", ->
    it "absorbs exceptions that are thrown by extension serialize methods", ->
      spyOn(console, 'error')

      rootView.activateExtension(
        name: "bad-egg"
        activate: ->
        serialize: -> throw new Error("I'm broken")
      )

      rootView.activateExtension(
        name: "good-egg"
        activate: ->
        serialize: -> "I still get called"
      )

      data = rootView.serialize()
      expect(data.extensionStates['good-egg']).toBe "I still get called"
      expect(data.extensionStates['bad-egg']).toBeUndefined()
      expect(console.error).toHaveBeenCalled()

  describe "focus", ->
    it "can receive focus if there is no active editor, but otherwise hands off focus to the active editor", ->
      rootView.remove()
      rootView = new RootView(require.resolve 'fixtures')
      rootView.attachToDom()
      expect(rootView).toMatchSelector(':focus')

      rootView.open() # create an editor
      expect(rootView).not.toMatchSelector(':focus')
      expect(rootView.getActiveEditor().isFocused).toBeTruthy()

      rootView.focus()
      expect(rootView).not.toMatchSelector(':focus')
      expect(rootView.getActiveEditor().isFocused).toBeTruthy()

  describe "panes", ->
    [pane1, newPaneContent] = []

    beforeEach ->
      rootView.attachToDom()
      rootView.width(800)
      rootView.height(600)
      pane1 = rootView.find('.pane').view()
      pane1.attr('id', 'pane-1')
      newPaneContent = $("<div>New pane content</div>")
      spyOn(newPaneContent, 'focus')

    describe "vertical splits", ->
      describe "when .splitRight(view) is called on a pane", ->
        it "places a new pane to the right of the current pane in a .row div", ->
          expect(rootView.panes.find('.row')).not.toExist()

          pane2 = pane1.splitRight(newPaneContent)
          expect(newPaneContent.focus).toHaveBeenCalled()

          expect(rootView.panes.find('.row')).toExist()
          expect(rootView.panes.find('.row .pane').length).toBe 2
          [leftPane, rightPane] = rootView.panes.find('.row .pane').map -> $(this)
          expect(rightPane[0]).toBe pane2[0]
          expect(leftPane.attr('id')).toBe 'pane-1'
          expect(rightPane.html()).toBe "<div>New pane content</div>"

          expectedColumnWidth = Math.floor(rootView.panes.width() / 2)
          expect(leftPane.outerWidth()).toBe expectedColumnWidth
          expect(rightPane.position().left).toBe expectedColumnWidth
          expect(rightPane.outerWidth()).toBe expectedColumnWidth

          pane2.remove()

          expect(rootView.panes.find('.row')).not.toExist()
          expect(rootView.panes.find('.pane').length).toBe 1
          expect(pane1.outerWidth()).toBe rootView.panes.width()

      describe "when splitLeft(view) is called on a pane", ->
        it "places a new pane to the left of the current pane in a .row div", ->
          expect(rootView.find('.row')).not.toExist()

          pane2 = pane1.splitLeft(newPaneContent)
          expect(newPaneContent.focus).toHaveBeenCalled()

          expect(rootView.find('.row')).toExist()
          expect(rootView.find('.row .pane').length).toBe 2
          [leftPane, rightPane] = rootView.find('.row .pane').map -> $(this)
          expect(leftPane[0]).toBe pane2[0]
          expect(rightPane.attr('id')).toBe 'pane-1'
          expect(leftPane.html()).toBe "<div>New pane content</div>"

          expectedColumnWidth = Math.floor(rootView.panes.width() / 2)
          expect(leftPane.outerWidth()).toBe expectedColumnWidth
          expect(rightPane.position().left).toBe expectedColumnWidth
          expect(rightPane.outerWidth()).toBe expectedColumnWidth

          pane2.remove()

          expect(rootView.panes.find('.row')).not.toExist()
          expect(rootView.panes.find('.pane').length).toBe 1
          expect(pane1.outerWidth()).toBe rootView.panes.width()
          expect(pane1.position().left).toBe 0

    describe "horizontal splits", ->
      describe "when splitUp(view) is called on a pane", ->
        it "places a new pane above the current pane in a .column div", ->
          expect(rootView.find('.column')).not.toExist()

          pane2 = pane1.splitUp(newPaneContent)
          expect(newPaneContent.focus).toHaveBeenCalled()

          expect(rootView.find('.column')).toExist()
          expect(rootView.find('.column .pane').length).toBe 2
          [topPane, bottomPane] = rootView.find('.column .pane').map -> $(this)
          expect(topPane[0]).toBe pane2[0]
          expect(bottomPane.attr('id')).toBe 'pane-1'
          expect(topPane.html()).toBe "<div>New pane content</div>"

          expectedRowHeight = Math.floor(rootView.panes.height() / 2)
          expect(topPane.outerHeight()).toBe expectedRowHeight
          expect(bottomPane.position().top).toBe expectedRowHeight
          expect(bottomPane.outerHeight()).toBe expectedRowHeight

          pane2.remove()

          expect(rootView.panes.find('.column')).not.toExist()
          expect(rootView.panes.find('.pane').length).toBe 1
          expect(pane1.outerHeight()).toBe rootView.panes.height()
          expect(pane1.position().top).toBe 0

      describe "when splitDown(view) is called on a pane", ->
        it "places a new pane below the current pane in a .column div", ->
          expect(rootView.find('.column')).not.toExist()

          pane2 = pane1.splitDown(newPaneContent)
          expect(newPaneContent.focus).toHaveBeenCalled()

          expect(rootView.find('.column')).toExist()
          expect(rootView.find('.column .pane').length).toBe 2
          [topPane, bottomPane] = rootView.find('.column .pane').map -> $(this)
          expect(bottomPane[0]).toBe pane2[0]
          expect(topPane.attr('id')).toBe 'pane-1'
          expect(bottomPane.html()).toBe "<div>New pane content</div>"

          expectedRowHeight = Math.floor(rootView.panes.height() / 2)
          expect(topPane.outerHeight()).toBe expectedRowHeight
          expect(bottomPane.position().top).toBe expectedRowHeight
          expect(bottomPane.outerHeight()).toBe expectedRowHeight

          pane2.remove()

          expect(rootView.panes.find('.column')).not.toExist()
          expect(rootView.panes.find('.pane').length).toBe 1
          expect(pane1.outerHeight()).toBe rootView.panes.height()

    describe "layout of nested vertical and horizontal splits", ->
      it "lays out rows and columns with a consistent width", ->
        pane1.html("1")

        pane1
          .splitLeft("2")
          .splitUp("3")
          .splitLeft("4")
          .splitDown("5")

        row1 = rootView.panes.children(':eq(0)')
        expect(row1.children().length).toBe 2
        column1 = row1.children(':eq(0)').view()
        pane1 = row1.children(':eq(1)').view()
        expect(column1.outerWidth()).toBe Math.floor(2/3 * rootView.panes.width())
        expect(column1.outerHeight()).toBe rootView.height()
        expect(pane1.outerWidth()).toBe Math.floor(1/3 * rootView.panes.width())
        expect(pane1.outerHeight()).toBe rootView.height()
        expect(pane1.position().left).toBe column1.outerWidth()

        expect(column1.children().length).toBe 2
        row2 = column1.children(':eq(0)').view()
        pane2 = column1.children(':eq(1)').view()
        expect(row2.outerWidth()).toBe column1.outerWidth()
        expect(row2.height()).toBe Math.floor(2/3 * rootView.panes.height())
        expect(pane2.outerWidth()).toBe column1.outerWidth()
        expect(pane2.outerHeight()).toBe Math.floor(1/3 * rootView.panes.height())
        expect(pane2.position().top).toBe row2.height()

        expect(row2.children().length).toBe 2
        column3 = row2.children(':eq(0)').view()
        pane3 = row2.children(':eq(1)').view()
        expect(column3.outerWidth()).toBe Math.floor(1/3 * rootView.panes.width())
        expect(column3.outerHeight()).toBe row2.outerHeight()
        expect(pane3.outerWidth()).toBe Math.floor(1/3 * rootView.panes.width())
        expect(pane3.height()).toBe row2.outerHeight()
        expect(pane3.position().left).toBe column3.width()

        expect(column3.children().length).toBe 2
        pane4 = column3.children(':eq(0)').view()
        pane5 = column3.children(':eq(1)').view()
        expect(pane4.outerWidth()).toBe column3.width()
        expect(pane4.outerHeight()).toBe Math.floor(1/3 * rootView.panes.height())
        expect(pane5.outerWidth()).toBe column3.width()
        expect(pane5.position().top).toBe pane4.outerHeight()
        expect(pane5.outerHeight()).toBe Math.floor(1/3 * rootView.panes.height())

        pane5.remove()

        expect(column3.parent()).not.toExist()
        expect(pane2.outerHeight()).toBe Math.floor(1/2 * rootView.panes.height())
        expect(pane3.outerHeight()).toBe Math.floor(1/2 * rootView.panes.height())
        expect(pane4.outerHeight()).toBe Math.floor(1/2 * rootView.panes.height())

        pane4.remove()
        expect(row2.parent()).not.toExist()
        expect(pane1.outerWidth()).toBe Math.floor(1/2 * rootView.panes.width())
        expect(pane2.outerWidth()).toBe Math.floor(1/2 * rootView.panes.width())
        expect(pane3.outerWidth()).toBe Math.floor(1/2 * rootView.panes.width())

        pane3.remove()
        expect(column1.parent()).not.toExist()
        expect(pane2.outerHeight()).toBe rootView.panes.height()

        pane2.remove()
        expect(row1.parent()).not.toExist()
        expect(rootView.panes.children().length).toBe 1
        expect(rootView.panes.children('.pane').length).toBe 1
        expect(pane1.outerWidth()).toBe rootView.panes.width()

    describe ".focusNextPane()", ->
      it "focuses the wrapped view of the pane after the currently focused pane", ->
        class DummyView extends View
          @content: (number) -> @div(number, tabindex: -1)

        view1 = pane1.wrappedView
        view2 = new DummyView(2)
        view3 = new DummyView(3)
        pane2 = pane1.splitDown(view2)
        pane3 = pane2.splitRight(view3)
        rootView.attachToDom()
        view1.focus()

        spyOn(view1, 'focus').andCallThrough()
        spyOn(view2, 'focus').andCallThrough()
        spyOn(view3, 'focus').andCallThrough()

        rootView.focusNextPane()
        expect(view2.focus).toHaveBeenCalled()
        rootView.focusNextPane()
        expect(view3.focus).toHaveBeenCalled()
        rootView.focusNextPane()
        expect(view1.focus).toHaveBeenCalled()

  describe "extensions", ->
    extension = null

    beforeEach ->
      extension =
        name: 'extension'
        deactivate: ->
        activate: jasmine.createSpy("activate")
        serialize: -> "it worked"

    describe "activation", ->
      it "calls activate on the extension", ->
        rootView.activateExtension(extension)
        expect(extension.activate).toHaveBeenCalledWith(rootView, undefined)

      it "calls activate on the extension with its previous state", ->
        rootView.activateExtension(extension)
        extension.activate.reset()

        newRootView = RootView.deserialize(rootView.serialize())
        newRootView.activateExtension(extension)
        expect(extension.activate).toHaveBeenCalledWith(newRootView, "it worked")
        newRootView.remove()

      it "throws an exception if the extension has no 'name' property", ->
        expect(-> rootView.activateExtension({ activate: -> })).toThrow()

    describe "deactivation", ->
      it "is deactivated and removed from the extension list", ->
        rootView.activateExtension(extension)
        expect(rootView.extensions[extension.name]).toBeTruthy()
        spyOn(extension, "deactivate").andCallThrough()
        rootView.deactivateExtension(extension)
        expect(extension.deactivate).toHaveBeenCalled()
        expect(rootView.extensions[extension.name]).toBeFalsy()

      it "is deactivated when the rootView is deactivated", ->
        rootView.activateExtension(extension)
        spyOn(extension, "deactivate").andCallThrough()
        rootView.deactivate()
        expect(extension.deactivate).toHaveBeenCalled()

  describe "keymap wiring", ->
    commandHandler = null
    beforeEach ->
      commandHandler = jasmine.createSpy('commandHandler')
      rootView.on('foo-command', commandHandler)

      window.keymap.bindKeys('*', 'x': 'foo-command')

    describe "when a keydown event is triggered on the RootView (not originating from Ace)", ->
      it "triggers matching keybindings for that event", ->
        event = keydownEvent 'x', target: rootView[0]

        rootView.trigger(event)
        expect(commandHandler).toHaveBeenCalled()

    describe ".activeKeybindings()", ->
      originalKeymap = null
      keymap = null
      editor = null

      beforeEach ->
        rootView.attachToDom()
        editor = rootView.getActiveEditor()
        keymap = new (require 'keymap')
        originalKeymap = window.keymap
        window.keymap = keymap

      afterEach ->
        window.keymap = originalKeymap

      it "returns all keybindings available for focused element", ->
        editor.on 'test-event-a', => # nothing

        keymap.bindKeys ".editor",
          "meta-a": "test-event-a"
          "meta-b": "test-event-b"

        keybindings = rootView.activeKeybindings()
        expect(Object.keys(keybindings).length).toBe 2
        expect(keybindings["meta-a"]).toEqual "test-event-a"

  describe "when the focused editor changes", ->
    it "changes the document.title and emits an active-editor-path-change event", ->
      pathChangeHandler = jasmine.createSpy 'pathChangeHandler'
      rootView.on 'active-editor-path-change', pathChangeHandler

      editor1 = rootView.getActiveEditor()
      expect(document.title).toBe path

      editor2 = rootView.getActiveEditor().splitLeft()

      path = rootView.project.resolve('b')
      editor2.edit(rootView.project.buildEditSessionForPath(path))
      expect(pathChangeHandler).toHaveBeenCalled()
      expect(document.title).toBe rootView.project.resolve(path)

      pathChangeHandler.reset()
      editor1.getBuffer().saveAs("/tmp/should-not-be-title.txt")
      expect(pathChangeHandler).not.toHaveBeenCalled()
      expect(document.title).toBe rootView.project.resolve(path)

    it "creates a project if there isn't one yet and the buffer was previously unsaved", ->
      rootView.remove()
      rootView = new RootView
      rootView.open()
      expect(rootView.project.getPath()?).toBeFalsy()
      rootView.getActiveEditor().getBuffer().saveAs('/tmp/ignore-me')
      expect(rootView.project.getPath()).toBe '/tmp'

  describe "when editors are focused", ->
    it "triggers 'active-editor-path-change' events if the path of the active editor actually changes", ->
      pathChangeHandler = jasmine.createSpy 'pathChangeHandler'
      rootView.on 'active-editor-path-change', pathChangeHandler

      editor1 = rootView.getActiveEditor()
      editor2 = rootView.getActiveEditor().splitLeft()

      rootView.open(require.resolve('fixtures/sample.txt'))
      expect(pathChangeHandler).toHaveBeenCalled()
      pathChangeHandler.reset()

      editor1.focus()
      expect(pathChangeHandler).toHaveBeenCalled()
      pathChangeHandler.reset()

      rootView.focus()
      expect(pathChangeHandler).not.toHaveBeenCalled()

      editor2.edit(editor1.activeEditSession.copy())
      editor2.focus()
      expect(pathChangeHandler).not.toHaveBeenCalled()

  describe "when the last editor is removed", ->
    it   "updates the title to the project path", ->
      rootView.getEditors()[0].remove()
      expect(document.title).toBe rootView.project.getPath()

  describe "font size adjustment", ->
    it "increases/decreases font size when increase/decrease-font-size events are triggered", ->
      fontSizeBefore = rootView.getFontSize()
      rootView.trigger 'increase-font-size'
      expect(rootView.getFontSize()).toBe fontSizeBefore + 1
      rootView.trigger 'increase-font-size'
      expect(rootView.getFontSize()).toBe fontSizeBefore + 2
      rootView.trigger 'decrease-font-size'
      expect(rootView.getFontSize()).toBe fontSizeBefore + 1
      rootView.trigger 'decrease-font-size'
      expect(rootView.getFontSize()).toBe fontSizeBefore

    it "does not allow the font size to be less than 1", ->
      rootView.setFontSize(1)
      expect(rootView.getFontSize()).toBe 1

      rootView.setFontSize(0)
      expect(rootView.getFontSize()).toBe 1

  describe ".open(path, options)", ->
    describe "when there is no active editor", ->
      beforeEach ->
        rootView.getActiveEditor().destroyActiveEditSession()
        expect(rootView.getActiveEditor()).toBeUndefined()

      describe "when called with no path", ->
        it "opens / returns an edit session for an empty buffer in a new editor", ->
          editSession = rootView.open()
          expect(rootView.getActiveEditor()).toBeDefined()
          expect(rootView.getActiveEditor().getPath()).toBeUndefined()
          expect(editSession).toBe rootView.getActiveEditor().activeEditSession

      describe "when called with a path", ->
        it "opens a buffer with the given path in a new editor", ->
          editSession = rootView.open('b')
          expect(rootView.getActiveEditor()).toBeDefined()
          expect(rootView.getActiveEditor().getPath()).toBe require.resolve('fixtures/dir/b')
          expect(editSession).toBe rootView.getActiveEditor().activeEditSession

    describe "when there is an active editor", ->
      beforeEach ->
        expect(rootView.getActiveEditor()).toBeDefined()

      describe "when called with no path", ->
        it "opens an empty buffer in the active editor", ->
          editSession = rootView.open()
          expect(rootView.getActiveEditor().getPath()).toBeUndefined()
          expect(editSession).toBe rootView.getActiveEditor().activeEditSession

      describe "when called with a path", ->
        [editor1, editor2] = []
        beforeEach ->
          rootView.attachToDom()
          editor1 = rootView.getActiveEditor()
          editor2 = editor1.splitRight()
          rootView.open('b')
          editor2.loadPreviousEditSession()
          editor1.focus()

        describe "when allowActiveEditorChange is false (the default)", ->
          activeEditor = null
          beforeEach ->
            activeEditor = rootView.getActiveEditor()

          describe "when the active editor has an edit session for the given path", ->
            it "re-activates the existing edit session", ->
              expect(activeEditor.getPath()).toBe require.resolve('fixtures/dir/a')
              previousEditSession = activeEditor.activeEditSession

              editSession = rootView.open('b')
              expect(activeEditor.activeEditSession).not.toBe previousEditSession
              expect(editSession).toBe rootView.getActiveEditor().activeEditSession

              editSession = rootView.open('a')
              expect(activeEditor.activeEditSession).toBe previousEditSession
              expect(editSession).toBe previousEditSession

          describe "when the active editor does not have an edit session for the given path", ->
            it "creates a new edit session for the given path in the active editor", ->
              editSession = rootView.open('b')
              expect(activeEditor.editSessions.length).toBe 2
              expect(editSession).toBe rootView.getActiveEditor().activeEditSession

        describe "when the 'allowActiveEditorChange' option is true", ->
          describe "when the active editor has an edit session for the given path", ->
            it "re-activates the existing edit session regardless of whether any other editor also has an edit session for the path", ->
              activeEditor = rootView.getActiveEditor()
              expect(activeEditor.getPath()).toBe require.resolve('fixtures/dir/a')
              previousEditSession = activeEditor.activeEditSession

              editSession = rootView.open('b')
              expect(activeEditor.activeEditSession).not.toBe previousEditSession
              expect(editSession).toBe activeEditor.activeEditSession

              editSession = rootView.open('a', allowActiveEditorChange: true)
              expect(activeEditor.activeEditSession).toBe previousEditSession
              expect(editSession).toBe activeEditor.activeEditSession

          describe "when the active editor does *not* have an edit session for the given path", ->
            describe "when another editor has an edit session for the path", ->
              it "focuses the other editor and activates its edit session for the path", ->
                expect(rootView.getActiveEditor()).toBe editor1
                editSession = rootView.open('b', allowActiveEditorChange: true)
                expect(rootView.getActiveEditor()).toBe editor2
                expect(editor2.getPath()).toBe require.resolve('fixtures/dir/b')
                expect(editSession).toBe rootView.getActiveEditor().activeEditSession

            describe "when no other editor has an edit session for the path either", ->
              it "creates a new edit session for the path on the current active editor", ->
                path = require.resolve('fixtures/sample.js')
                editSession = rootView.open(path, allowActiveEditorChange: true)
                expect(rootView.getActiveEditor()).toBe editor1
                expect(editor1.getPath()).toBe path
                expect(editSession).toBe rootView.getActiveEditor().activeEditSession
