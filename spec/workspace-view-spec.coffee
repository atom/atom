{$, $$, WorkspaceView, View} = require 'atom'
Q = require 'q'
path = require 'path'
temp = require 'temp'
EditorView = require '../src/editor-view'
PaneView = require '../src/pane-view'
Workspace = require '../src/workspace'

describe "WorkspaceView", ->
  pathToOpen = null

  beforeEach ->
    atom.project.setPath(atom.project.resolve('dir'))
    pathToOpen = atom.project.resolve('a')
    atom.workspace = new Workspace
    atom.workspaceView = new WorkspaceView(atom.workspace)
    atom.workspaceView.enableKeymap()
    atom.workspaceView.focus()

    waitsForPromise ->
      atom.workspace.open(pathToOpen)

  describe "@deserialize()", ->
    viewState = null

    simulateReload = ->
      workspaceState = atom.workspace.serialize()
      projectState = atom.project.serialize()
      atom.workspaceView.remove()
      atom.project = atom.deserializers.deserialize(projectState)
      atom.workspace = Workspace.deserialize(workspaceState)
      atom.workspaceView = new WorkspaceView(atom.workspace)
      atom.workspaceView.attachToDom()

    describe "when the serialized WorkspaceView has an unsaved buffer", ->
      it "constructs the view with the same panes", ->
        atom.workspaceView.attachToDom()

        waitsForPromise ->
          atom.workspace.open()

        runs ->
          editorView1 = atom.workspaceView.getActiveView()
          buffer = editorView1.getEditor().getBuffer()
          editorView1.splitRight()
          expect(atom.workspaceView.getActivePaneView()).toBe atom.workspaceView.getPaneViews()[1]

          simulateReload()

          expect(atom.workspaceView.getEditorViews().length).toBe 2
          expect(atom.workspaceView.getActivePaneView()).toBe atom.workspaceView.getPaneViews()[1]
          expect(atom.workspaceView.title).toBe "untitled - #{atom.project.getPath()}"

    describe "when there are open editors", ->
      it "constructs the view with the same panes", ->
        atom.workspaceView.attachToDom()
        pane1 = atom.workspaceView.getActivePaneView()
        pane2 = pane1.splitRight()
        pane3 = pane2.splitRight()
        pane4 = null

        waitsForPromise ->
          atom.workspace.open('b').then (editor) ->
            pane2.activateItem(editor)

        waitsForPromise ->
          atom.workspace.open('../sample.js').then (editor) ->
            pane3.activateItem(editor)

        runs ->
          pane3.activeItem.setCursorScreenPosition([2, 4])
          pane4 = pane2.splitDown()

        waitsForPromise ->
          atom.workspace.open('../sample.txt').then (editor) ->
            pane4.activateItem(editor)

        runs ->
          pane4.activeItem.setCursorScreenPosition([0, 2])
          pane2.focus()

          simulateReload()

          expect(atom.workspaceView.getEditorViews().length).toBe 4
          editorView1 = atom.workspaceView.panes.find('.pane-row > .pane .editor:eq(0)').view()
          editorView3 = atom.workspaceView.panes.find('.pane-row > .pane .editor:eq(1)').view()
          editorView2 = atom.workspaceView.panes.find('.pane-row > .pane-column > .pane .editor:eq(0)').view()
          editorView4 = atom.workspaceView.panes.find('.pane-row > .pane-column > .pane .editor:eq(1)').view()

          expect(editorView1.getEditor().getPath()).toBe atom.project.resolve('a')
          expect(editorView2.getEditor().getPath()).toBe atom.project.resolve('b')
          expect(editorView3.getEditor().getPath()).toBe atom.project.resolve('../sample.js')
          expect(editorView3.getEditor().getCursorScreenPosition()).toEqual [2, 4]
          expect(editorView4.getEditor().getPath()).toBe atom.project.resolve('../sample.txt')
          expect(editorView4.getEditor().getCursorScreenPosition()).toEqual [0, 2]

          # ensure adjust pane dimensions is called
          expect(editorView1.width()).toBeGreaterThan 0
          expect(editorView2.width()).toBeGreaterThan 0
          expect(editorView3.width()).toBeGreaterThan 0
          expect(editorView4.width()).toBeGreaterThan 0

          # ensure correct editorView is focused again
          expect(editorView2).toHaveFocus()
          expect(editorView1).not.toHaveFocus()
          expect(editorView3).not.toHaveFocus()
          expect(editorView4).not.toHaveFocus()

          expect(atom.workspaceView.title).toBe "#{path.basename(editorView2.getEditor().getPath())} - #{atom.project.getPath()}"

    describe "where there are no open editors", ->
      it "constructs the view with no open editors", ->
        atom.workspaceView.getActivePaneView().remove()
        expect(atom.workspaceView.getEditorViews().length).toBe 0
        simulateReload()
        expect(atom.workspaceView.getEditorViews().length).toBe 0

  describe "focus", ->
    beforeEach ->
      atom.workspaceView.attachToDom()

    it "hands off focus to the active pane", ->
      activePane = atom.workspaceView.getActivePaneView()
      $('body').focus()
      expect(activePane).not.toHaveFocus()
      atom.workspaceView.focus()
      expect(activePane).toHaveFocus()

  describe "keymap wiring", ->
    commandHandler = null
    beforeEach ->
      commandHandler = jasmine.createSpy('commandHandler')
      atom.workspaceView.on('foo-command', commandHandler)

      atom.keymaps.add('name', '*': {'x': 'foo-command'})

    describe "when a keydown event is triggered in the WorkspaceView", ->
      it "triggers matching keybindings for that event", ->
        event = keydownEvent 'x', target: atom.workspaceView[0]

        atom.workspaceView.trigger(event)
        expect(commandHandler).toHaveBeenCalled()

  describe "window title", ->
    describe "when the project has no path", ->
      it "sets the title to 'untitled'", ->
        atom.project.setPath(undefined)
        expect(atom.workspaceView.title).toBe 'untitled'

    describe "when the project has a path", ->
      beforeEach ->
        waitsForPromise ->
          atom.workspace.open('b')

      describe "when there is an active pane item", ->
        it "sets the title to the pane item's title plus the project path", ->
          item = atom.workspace.getActivePaneItem()
          expect(atom.workspaceView.title).toBe "#{item.getTitle()} - #{atom.project.getPath()}"

      describe "when the title of the active pane item changes", ->
        it "updates the window title based on the item's new title", ->
          editor = atom.workspace.getActivePaneItem()
          editor.buffer.setPath(path.join(temp.dir, 'hi'))
          expect(atom.workspaceView.title).toBe "#{editor.getTitle()} - #{atom.project.getPath()}"

      describe "when the active pane's item changes", ->
        it "updates the title to the new item's title plus the project path", ->
          atom.workspaceView.getActivePaneView().activateNextItem()
          item = atom.workspace.getActivePaneItem()
          expect(atom.workspaceView.title).toBe "#{item.getTitle()} - #{atom.project.getPath()}"

      describe "when the last pane item is removed", ->
        it "updates the title to contain the project's path", ->
          atom.workspaceView.getActivePaneView().remove()
          expect(atom.workspace.getActivePaneItem()).toBeUndefined()
          expect(atom.workspaceView.title).toBe atom.project.getPath()

      describe "when an inactive pane's item changes", ->
        it "does not update the title", ->
          pane = atom.workspaceView.getActivePaneView()
          pane.splitRight()
          initialTitle = atom.workspaceView.title
          pane.activateNextItem()
          expect(atom.workspaceView.title).toBe initialTitle

    describe "when the root view is deserialized", ->
      it "updates the title to contain the project's path", ->
        workspaceView2 = new WorkspaceView(atom.workspace.testSerialization())
        item = atom.workspace.getActivePaneItem()
        expect(workspaceView2.title).toBe "#{item.getTitle()} - #{atom.project.getPath()}"
        workspaceView2.remove()

  describe "window:toggle-invisibles event", ->
    it "shows/hides invisibles in all open and future editors", ->
      atom.workspaceView.height(200)
      atom.workspaceView.attachToDom()
      rightEditorView = atom.workspaceView.getActiveView()
      rightEditorView.getEditor().setText("\t  \n")
      leftEditorView = rightEditorView.splitLeft()
      expect(rightEditorView.find(".line:first").text()).toBe "    "
      expect(leftEditorView.find(".line:first").text()).toBe "    "

      {space, tab, eol} = atom.config.get('editor.invisibles')
      withInvisiblesShowing = "#{tab} #{space}#{space}#{eol}"

      atom.workspaceView.trigger "window:toggle-invisibles"
      expect(rightEditorView.find(".line:first").text()).toBe withInvisiblesShowing
      expect(leftEditorView.find(".line:first").text()).toBe withInvisiblesShowing

      lowerLeftEditorView = leftEditorView.splitDown()
      expect(lowerLeftEditorView.find(".line:first").text()).toBe withInvisiblesShowing

      atom.workspaceView.trigger "window:toggle-invisibles"
      expect(rightEditorView.find(".line:first").text()).toBe "    "
      expect(leftEditorView.find(".line:first").text()).toBe "    "

      lowerRightEditorView = rightEditorView.splitDown()
      expect(lowerRightEditorView.find(".line:first").text()).toBe "    "

  describe ".eachEditorView(callback)", ->
    beforeEach ->
      atom.workspaceView.attachToDom()

    it "invokes the callback for existing editor", ->
      count = 0
      callbackEditor = null
      callback = (editor) ->
        callbackEditor = editor
        count++
      atom.workspaceView.eachEditorView(callback)
      expect(count).toBe 1
      expect(callbackEditor).toBe atom.workspaceView.getActiveView()

    it "invokes the callback for new editor", ->
      count = 0
      callbackEditor = null
      callback = (editor) ->
        callbackEditor = editor
        count++

      atom.workspaceView.eachEditorView(callback)
      count = 0
      callbackEditor = null
      atom.workspaceView.getActiveView().splitRight()
      expect(count).toBe 1
      expect(callbackEditor).toBe atom.workspaceView.getActiveView()

    it "does not invoke the callback for mini editors", ->
      editorViewCreatedHandler = jasmine.createSpy('editorViewCreatedHandler')
      atom.workspaceView.eachEditorView(editorViewCreatedHandler)
      editorViewCreatedHandler.reset()
      miniEditor = new EditorView(mini: true)
      atom.workspaceView.append(miniEditor)
      expect(editorViewCreatedHandler).not.toHaveBeenCalled()

    it "returns a subscription that can be disabled", ->
      count = 0
      callback = (editor) -> count++

      subscription = atom.workspaceView.eachEditorView(callback)
      expect(count).toBe 1
      atom.workspaceView.getActiveView().splitRight()
      expect(count).toBe 2
      subscription.off()
      atom.workspaceView.getActiveView().splitRight()
      expect(count).toBe 2

  describe "core:close", ->
    it "closes the active pane item until all that remains is a single empty pane", ->
      atom.config.set('core.destroyEmptyPanes', true)

      paneView1 = atom.workspaceView.getActivePaneView()
      editorView = atom.workspaceView.getActiveView()
      editorView.splitRight()
      paneView2 = atom.workspaceView.getActivePaneView()

      expect(paneView1).not.toBe paneView2
      expect(atom.workspaceView.getPaneViews()).toHaveLength 2
      atom.workspaceView.trigger('core:close')

      expect(atom.workspaceView.getActivePaneView().getItems()).toHaveLength 1
      expect(atom.workspaceView.getPaneViews()).toHaveLength 1
      atom.workspaceView.trigger('core:close')

      expect(atom.workspaceView.getActivePaneView().getItems()).toHaveLength 0
      expect(atom.workspaceView.getPaneViews()).toHaveLength 1

  describe "the scrollbar visibility class", ->
    it "has a class based on the style of the scrollbar", ->
      scrollbarStyle = require 'scrollbar-style'
      scrollbarStyle.emitValue 'legacy'
      expect(atom.workspaceView).toHaveClass 'scrollbars-visible-always'
      scrollbarStyle.emitValue 'overlay'
      expect(atom.workspaceView).toHaveClass 'scrollbars-visible-when-scrolling'

  describe "editor font styling", ->
    [editorNode, editor] = []

    beforeEach ->
      atom.workspaceView.attachToDom()
      editorNode = atom.workspaceView.find('.editor')[0]
      editor = atom.workspaceView.find('.editor').view().getEditor()

    it "updates the font-size based on the 'editor.fontSize' config value", ->
      initialCharWidth = editor.getDefaultCharWidth()
      expect(getComputedStyle(editorNode).fontSize).toBe atom.config.get('editor.fontSize') + 'px'
      atom.config.set('editor.fontSize', atom.config.get('editor.fontSize') + 5)
      expect(getComputedStyle(editorNode).fontSize).toBe atom.config.get('editor.fontSize') + 'px'
      expect(editor.getDefaultCharWidth()).toBeGreaterThan initialCharWidth

    it "updates the font-family based on the 'editor.fontFamily' config value", ->
      initialCharWidth = editor.getDefaultCharWidth()
      expect(getComputedStyle(editorNode).fontFamily).toBe atom.config.get('editor.fontFamily')
      atom.config.set('editor.fontFamily', 'sans-serif')
      expect(getComputedStyle(editorNode).fontFamily).toBe atom.config.get('editor.fontFamily')
      expect(editor.getDefaultCharWidth()).not.toBe initialCharWidth

    it "updates the line-height based on the 'editor.lineHeight' config value", ->
      initialLineHeight = editor.getLineHeightInPixels()
      atom.config.set('editor.lineHeight', '30px')
      expect(getComputedStyle(editorNode).lineHeight).toBe atom.config.get('editor.lineHeight')
      expect(editor.getLineHeightInPixels()).not.toBe initialLineHeight
