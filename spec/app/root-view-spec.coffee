$ = require 'jquery'
fs = require 'fs'
RootView = require 'root-view'
Buffer = require 'buffer'
Editor = require 'editor'
{View, $$} = require 'space-pen'

describe "RootView", ->
  rootView = null
  path = null

  beforeEach ->
    path = require.resolve 'fixtures/dir/a'
    rootView = new RootView(path)
    rootView.enableKeymap()
    rootView.focus()

  afterEach ->
    rootView.deactivate()

  describe ".initialize(pathToOpen)", ->
    describe "when called with a pathToOpen", ->
      describe "when pathToOpen references a file", ->
        it "creates a project for the file's parent directory, then sets the title and opens the file in an editor", ->
          expect(rootView.project.getPath()).toBe fs.directory(path)
          expect(rootView.getEditors().length).toBe 1
          expect(rootView.getEditors()[0]).toHaveClass 'active'
          expect(rootView.getActiveEditor().getPath()).toBe path
          expect(rootView.getActiveEditor().editSessions.length).toBe 1
          expect(rootView.getTitle()).toBe "#{fs.base(path)} – #{rootView.project.getPath()}"

      describe "when pathToOpen references a directory", ->
        beforeEach ->
          rootView.remove()

        it "creates a project for the directory and sets the title, but does not open an editor", ->
          path = require.resolve 'fixtures/dir'
          rootView = new RootView(path)
          rootView.focus()

          expect(rootView.project.getPath()).toBe path
          expect(rootView.getEditors().length).toBe 0
          expect(rootView.getTitle()).toBe rootView.project.getPath()

    describe "when called with no pathToOpen", ->
      it "opens an empty buffer", ->
        rootView.remove()
        rootView = new RootView
        expect(rootView.getEditors().length).toBe 1
        expect(rootView.getEditors()[0].getText()).toEqual ""
        expect(rootView.getTitle()).toBe 'untitled'

  describe "@deserialize()", ->
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
        expect(rootView.getTitle()).toBe 'untitled'

    describe "when the serialized RootView has a project", ->
      beforeEach ->
        path = require.resolve 'fixtures'
        rootView.remove()
        rootView = new RootView(path)

      describe "when there are open editors", ->
        beforeEach ->
          rootView.open('dir/a')
          editor1 = rootView.getActiveEditor()
          editor2 = editor1.splitRight()
          editor3 = editor2.splitRight()
          editor4 = editor2.splitDown()
          editor2.edit(rootView.project.buildEditSessionForPath('dir/b'))
          editor3.edit(rootView.project.buildEditSessionForPath('sample.js'))
          editor3.setCursorScreenPosition([2, 4])
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
          expect(editor3.getCursorScreenPosition()).toEqual [2, 4]
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

          expect(rootView.getTitle()).toBe "#{fs.base(editor2.getPath())} – #{rootView.project.getPath()}"

      describe "where there are no open editors", ->
        beforeEach ->
          rootView.attachToDom()
          viewState = rootView.serialize()
          rootView.remove()

        it "constructs the view with no open editors", ->
            rootView = RootView.deserialize(viewState)
            rootView.attachToDom()

            expect(rootView.getEditors().length).toBe 0

    describe "when a pane's wrapped view cannot be deserialized", ->
      fit "renders an empty pane", ->
        viewState =
          panesViewState:
            viewClass: "Pane",
            wrappedView:
              viewClass: "BogusView"

        rootView.remove()
        rootView = RootView.deserialize(viewState)
        expect(rootView.find('.pane').length).toBe 1
        expect(rootView.find('.pane').children().length).toBe 0

  describe ".serialize()", ->
    it "absorbs exceptions that are thrown by the package module's serialize methods", ->
      spyOn(console, 'error')

      rootView.activatePackage("bad-egg",
        activate: ->
        serialize: -> throw new Error("I'm broken")
      )

      rootView.activatePackage("good-egg"
        activate: ->
        serialize: -> "I still get called"
      )

      data = rootView.serialize()
      expect(data.packageStates['good-egg']).toBe "I still get called"
      expect(data.packageStates['bad-egg']).toBeUndefined()
      expect(console.error).toHaveBeenCalled()

  describe "focus", ->
    describe "when there is an active editor", ->
      it "hands off focus to the active editor", ->
        rootView.remove()
        rootView = new RootView(require.resolve 'fixtures')
        rootView.attachToDom()

        rootView.open() # create an editor
        expect(rootView).not.toMatchSelector(':focus')
        expect(rootView.getActiveEditor().isFocused).toBeTruthy()

        rootView.focus()
        expect(rootView).not.toMatchSelector(':focus')
        expect(rootView.getActiveEditor().isFocused).toBeTruthy()

    describe "when there is no active editor", ->
      describe "when are visible focusable elements (with a -1 tabindex)", ->
        it "passes focus to the first focusable element", ->
          rootView.remove()
          rootView = new RootView(require.resolve 'fixtures')

          rootView.horizontal.append $$ ->
            @div "One", id: 'one', tabindex: -1
            @div "Two", id: 'two', tabindex: -1

          rootView.attachToDom()
          expect(rootView).not.toMatchSelector(':focus')
          expect(rootView.find('#one')).toMatchSelector(':focus')
          expect(rootView.find('#two')).not.toMatchSelector(':focus')

      describe "when there are no visible focusable elements", ->
        it "retains focus itself", ->
          rootView.remove()
          rootView = new RootView(require.resolve 'fixtures')
          rootView.attachToDom()
          expect(rootView).toMatchSelector(':focus')

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
        expect(column1.outerWidth()).toBe Math.round(2/3 * rootView.panes.width())
        expect(column1.outerHeight()).toBe rootView.height()
        expect(pane1.outerWidth()).toBe Math.round(1/3 * rootView.panes.width())
        expect(pane1.outerHeight()).toBe rootView.height()
        expect(Math.round(pane1.position().left)).toBe column1.outerWidth()

        expect(column1.children().length).toBe 2
        row2 = column1.children(':eq(0)').view()
        pane2 = column1.children(':eq(1)').view()
        expect(row2.outerWidth()).toBe column1.outerWidth()
        expect(row2.height()).toBe 2/3 * rootView.panes.height()
        expect(pane2.outerWidth()).toBe column1.outerWidth()
        expect(pane2.outerHeight()).toBe 1/3 * rootView.panes.height()
        expect(pane2.position().top).toBe row2.height()

        expect(row2.children().length).toBe 2
        column3 = row2.children(':eq(0)').view()
        pane3 = row2.children(':eq(1)').view()
        expect(column3.outerWidth()).toBe Math.round(1/3 * rootView.panes.width())
        expect(column3.outerHeight()).toBe row2.outerHeight()
        # the built in rounding seems to be rounding x.5 down, but we need to go up. this sucks.
        expect(Math.round(pane3.trueWidth())).toBe Math.round(1/3 * rootView.panes.width())
        expect(pane3.height()).toBe row2.outerHeight()
        expect(Math.round(pane3.position().left)).toBe column3.width()

        expect(column3.children().length).toBe 2
        pane4 = column3.children(':eq(0)').view()
        pane5 = column3.children(':eq(1)').view()
        expect(pane4.outerWidth()).toBe column3.width()
        expect(pane4.outerHeight()).toBe 1/3 * rootView.panes.height()
        expect(pane5.outerWidth()).toBe column3.width()
        expect(pane5.position().top).toBe pane4.outerHeight()
        expect(pane5.outerHeight()).toBe 1/3 * rootView.panes.height()

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

  describe "packages", ->
    packageModule = null

    beforeEach ->
      packageModule =
        configDefaults: foo: { bar: 2, baz: 3 }
        activate: jasmine.createSpy("activate")
        deactivate: ->
        serialize: -> "it worked"

    describe ".activatePackage(name, packageModule)", ->
      it "calls activate on the package module", ->
        rootView.activatePackage('package', packageModule)
        expect(packageModule.activate).toHaveBeenCalledWith(rootView, undefined)

      it "calls activate on the package module with its previous state", ->
        rootView.activatePackage('package', packageModule)
        packageModule.activate.reset()

        newRootView = RootView.deserialize(rootView.serialize())
        newRootView.activatePackage('package', packageModule)
        expect(packageModule.activate).toHaveBeenCalledWith(newRootView, "it worked")
        newRootView.remove()

      it "loads config defaults based on the `configDefaults` key", ->
        expect(config.get('foo.bar')).toBeUndefined()
        rootView.activatePackage('package', packageModule)
        config.set("package.foo.bar", 1)
        expect(config.get('package.foo.bar')).toBe 1
        expect(config.get('package.foo.baz')).toBe 3

    describe ".deactivatePackage(packageName)", ->
      it "deactivates and removes the package module from the package module map", ->
        rootView.activatePackage('package', packageModule)
        expect(rootView.packageModules['package']).toBeTruthy()
        spyOn(packageModule, "deactivate").andCallThrough()
        rootView.deactivatePackage('package')
        expect(packageModule.deactivate).toHaveBeenCalled()
        expect(rootView.packageModules['package']).toBeFalsy()

      it "is called when the rootView is deactivated to deactivate all packages", ->
        rootView.activatePackage('package', packageModule)
        spyOn(rootView, "deactivatePackage").andCallThrough()
        spyOn(packageModule, "deactivate").andCallThrough()
        rootView.deactivate()
        expect(rootView.deactivatePackage).toHaveBeenCalled()
        expect(packageModule.deactivate).toHaveBeenCalled()

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
    it "changes the title and emits an root-view:active-path-changed event", ->
      pathChangeHandler = jasmine.createSpy 'pathChangeHandler'
      rootView.on 'root-view:active-path-changed', pathChangeHandler

      editor1 = rootView.getActiveEditor()
      expect(rootView.getTitle()).toBe "#{fs.base(editor1.getPath())} – #{rootView.project.getPath()}"

      editor2 = rootView.getActiveEditor().splitLeft()

      path = rootView.project.resolve('b')
      editor2.edit(rootView.project.buildEditSessionForPath(path))
      expect(pathChangeHandler).toHaveBeenCalled()
      expect(rootView.getTitle()).toBe "#{fs.base(editor2.getPath())} – #{rootView.project.getPath()}"

      pathChangeHandler.reset()
      editor1.getBuffer().saveAs("/tmp/should-not-be-title.txt")
      expect(pathChangeHandler).not.toHaveBeenCalled()
      expect(rootView.getTitle()).toBe "#{fs.base(editor2.getPath())} – #{rootView.project.getPath()}"

    it "creates a project if there isn't one yet and the buffer was previously unsaved", ->
      rootView.remove()
      rootView = new RootView
      rootView.open()
      expect(rootView.project.getPath()?).toBeFalsy()
      rootView.getActiveEditor().getBuffer().saveAs('/tmp/ignore-me')
      expect(rootView.project.getPath()).toBe '/tmp'

  describe "when editors are focused", ->
    it "triggers 'root-view:active-path-changed' events if the path of the active editor actually changes", ->
      pathChangeHandler = jasmine.createSpy 'pathChangeHandler'
      rootView.on 'root-view:active-path-changed', pathChangeHandler

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
    it "updates the title to the project path", ->
      rootView.getEditors()[0].remove()
      expect(rootView.getTitle()).toBe rootView.project.getPath()

  describe "font size adjustment", ->
    editor = null
    beforeEach ->
      editor = rootView.getActiveEditor()

    it "increases/decreases font size when increase/decrease-font-size events are triggered", ->
      editor = rootView.getActiveEditor()
      fontSizeBefore = editor.getFontSize()
      rootView.trigger 'window:increase-font-size'
      expect(editor.getFontSize()).toBe fontSizeBefore + 1
      rootView.trigger 'window:increase-font-size'
      expect(editor.getFontSize()).toBe fontSizeBefore + 2
      rootView.trigger 'window:decrease-font-size'
      expect(editor.getFontSize()).toBe fontSizeBefore + 1
      rootView.trigger 'window:decrease-font-size'
      expect(editor.getFontSize()).toBe fontSizeBefore

    it "does not allow the font size to be less than 1", ->
      config.set("editor.fontSize", 1)
      rootView.trigger 'window:decrease-font-size'
      expect(editor.getFontSize()).toBe 1

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

  describe ".saveAll()", ->
    it "saves all open editors", ->
      rootView.remove()
      file1 = '/tmp/atom-temp1.txt'
      file2 = '/tmp/atom-temp2.txt'
      fs.write(file1, "file1")
      fs.write(file2, "file2")
      rootView = new RootView(file1)

      editor1 = rootView.getActiveEditor()
      buffer1 = editor1.activeEditSession.buffer
      expect(buffer1.getText()).toBe("file1")
      expect(buffer1.isModified()).toBe(false)
      buffer1.setText('edited1')
      expect(buffer1.isModified()).toBe(true)

      editor2 = editor1.splitRight()
      editor2.edit(rootView.project.buildEditSessionForPath('atom-temp2.txt'))
      buffer2 = editor2.activeEditSession.buffer
      expect(buffer2.getText()).toBe("file2")
      expect(buffer2.isModified()).toBe(false)
      buffer2.setText('edited2')
      expect(buffer2.isModified()).toBe(true)

      rootView.saveAll()

      expect(buffer1.isModified()).toBe(false)
      expect(fs.read(buffer1.getPath())).toBe("edited1")
      expect(buffer2.isModified()).toBe(false)
      expect(fs.read(buffer2.getPath())).toBe("edited2")

  describe "window:toggle-invisibles event", ->
    it "shows/hides invisibles in all open and future editors", ->
      rootView.height(200)
      rootView.attachToDom()
      rightEditor = rootView.getActiveEditor()
      rightEditor.setText(" \t ")
      leftEditor = rightEditor.splitLeft()
      expect(rightEditor.find(".line:first").text()).toBe "    "
      expect(leftEditor.find(".line:first").text()).toBe "    "

      withInvisiblesShowing = "#{rightEditor.invisibles.space}#{rightEditor.invisibles.tab} #{rightEditor.invisibles.space}#{rightEditor.invisibles.eol}"

      rootView.trigger "window:toggle-invisibles"
      expect(rightEditor.find(".line:first").text()).toBe withInvisiblesShowing
      expect(leftEditor.find(".line:first").text()).toBe withInvisiblesShowing

      lowerLeftEditor = leftEditor.splitDown()
      expect(lowerLeftEditor.find(".line:first").text()).toBe withInvisiblesShowing

      rootView.trigger "window:toggle-invisibles"
      expect(rightEditor.find(".line:first").text()).toBe "    "
      expect(leftEditor.find(".line:first").text()).toBe "    "

      lowerRightEditor = rightEditor.splitDown()
      expect(lowerRightEditor.find(".line:first").text()).toBe "    "

  describe ".eachEditor(callback)", ->
    beforeEach ->
      rootView.attachToDom()

    it "invokes the callback for existing editor", ->
      count = 0
      callbackEditor = null
      callback = (editor) ->
        callbackEditor = editor
        count++
      rootView.eachEditor(callback)
      expect(count).toBe 1
      expect(callbackEditor).toBe rootView.getActiveEditor()

    it "invokes the callback for new editor", ->
      count = 0
      callbackEditor = null
      callback = (editor) ->
        callbackEditor = editor
        count++

      rootView.eachEditor(callback)
      count = 0
      callbackEditor = null
      rootView.getActiveEditor().splitRight()
      expect(count).toBe 1
      expect(callbackEditor).toBe rootView.getActiveEditor()

  describe ".eachBuffer(callback)", ->
    beforeEach ->
      rootView.attachToDom()

    it "invokes the callback for existing buffer", ->
      count = 0
      callbackBuffer = null
      callback = (buffer) ->
        callbackBuffer = buffer
        count++
      rootView.eachBuffer(callback)
      expect(count).toBe 1
      expect(callbackBuffer).toBe rootView.getActiveEditor().getBuffer()

    it "invokes the callback for new buffer", ->
      count = 0
      callbackBuffer = null
      callback = (buffer) ->
        callbackBuffer = buffer
        count++

      rootView.eachBuffer(callback)
      count = 0
      callbackBuffer = null
      rootView.open(require.resolve('fixtures/sample.txt'))
      expect(count).toBe 1
      expect(callbackBuffer).toBe rootView.getActiveEditor().getBuffer()
