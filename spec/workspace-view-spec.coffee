{$, $$, View} = require '../src/space-pen-extensions'
Q = require 'q'
path = require 'path'
temp = require 'temp'
TextEditorView = require '../src/text-editor-view'
PaneView = require '../src/pane-view'
Workspace = require '../src/workspace'

describe "WorkspaceView", ->
  pathToOpen = null

  beforeEach ->
    jasmine.snapshotDeprecations()

    atom.project.setPaths([atom.project.getDirectories()[0]?.resolve('dir')])
    pathToOpen = atom.project.getDirectories()[0]?.resolve('a')
    atom.workspace = new Workspace
    atom.workspaceView = atom.views.getView(atom.workspace).__spacePenView
    atom.workspaceView.enableKeymap()
    atom.workspaceView.focus()

    waitsForPromise ->
      atom.workspace.open(pathToOpen)

  afterEach ->
    jasmine.restoreDeprecationsSnapshot()

  describe "focus", ->
    beforeEach ->
      atom.workspaceView.attachToDom()

    it "hands off focus to the active pane", ->
      activePane = atom.workspaceView.getActivePaneView()
      $('body').focus()
      expect(activePane).not.toHaveFocus()
      atom.workspaceView.focus()
      expect(activePane).toHaveFocus()

  describe "window:toggle-invisibles event", ->
    it "shows/hides invisibles in all open and future editors", ->
      atom.workspaceView.height(200)
      atom.workspaceView.attachToDom()
      rightEditorView = atom.workspaceView.getActiveView()
      rightEditorView.getEditor().setText("\t  \n")
      rightEditorView.getPaneView().getModel().splitLeft(copyActiveItem: true)
      leftEditorView = atom.workspaceView.getActiveView()
      expect(rightEditorView.find(".line:first").text()).toBe "    "
      expect(leftEditorView.find(".line:first").text()).toBe "    "

      {space, tab, eol} = atom.config.get('editor.invisibles')
      withInvisiblesShowing = "#{tab} #{space}#{space}#{eol}"

      atom.workspaceView.trigger "window:toggle-invisibles"
      expect(rightEditorView.find(".line:first").text()).toBe withInvisiblesShowing
      expect(leftEditorView.find(".line:first").text()).toBe withInvisiblesShowing

      leftEditorView.getPaneView().getModel().splitDown(copyActiveItem: true)
      lowerLeftEditorView = atom.workspaceView.getActiveView()
      expect(lowerLeftEditorView.find(".line:first").text()).toBe withInvisiblesShowing

      atom.workspaceView.trigger "window:toggle-invisibles"
      expect(rightEditorView.find(".line:first").text()).toBe "    "
      expect(leftEditorView.find(".line:first").text()).toBe "    "

      rightEditorView.getPaneView().getModel().splitDown(copyActiveItem: true)
      lowerRightEditorView = atom.workspaceView.getActiveView()
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
      atom.workspaceView.getActiveView().getPaneView().getModel().splitRight(copyActiveItem: true)
      expect(count).toBe 1
      expect(callbackEditor).toBe atom.workspaceView.getActiveView()

    it "does not invoke the callback for mini editors", ->
      editorViewCreatedHandler = jasmine.createSpy('editorViewCreatedHandler')
      atom.workspaceView.eachEditorView(editorViewCreatedHandler)
      editorViewCreatedHandler.reset()
      miniEditor = new TextEditorView(mini: true)
      atom.workspaceView.append(miniEditor)
      expect(editorViewCreatedHandler).not.toHaveBeenCalled()

    it "returns a subscription that can be disabled", ->
      count = 0
      callback = (editor) -> count++

      subscription = atom.workspaceView.eachEditorView(callback)
      expect(count).toBe 1
      atom.workspaceView.getActiveView().getPaneView().getModel().splitRight(copyActiveItem: true)
      expect(count).toBe 2
      subscription.off()
      atom.workspaceView.getActiveView().getPaneView().getModel().splitRight(copyActiveItem: true)
      expect(count).toBe 2

  describe "core:close", ->
    it "closes the active pane item until all that remains is a single empty pane", ->
      atom.config.set('core.destroyEmptyPanes', true)

      paneView1 = atom.workspaceView.getActivePaneView()
      editorView = atom.workspaceView.getActiveView()
      editorView.getPaneView().getModel().splitRight(copyActiveItem: true)
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
      style = 'legacy'
      scrollbarStyle = require 'scrollbar-style'
      spyOn(scrollbarStyle, 'getPreferredScrollbarStyle').andCallFake -> style

      atom.workspaceView.element.observeScrollbarStyle()
      expect(atom.workspaceView).toHaveClass 'scrollbars-visible-always'

      style = 'overlay'
      atom.workspaceView.element.observeScrollbarStyle()
      expect(atom.workspaceView).toHaveClass 'scrollbars-visible-when-scrolling'

  describe "editor font styling", ->
    [editorNode, editor] = []

    beforeEach ->
      atom.workspaceView.attachToDom()
      editorNode = atom.workspaceView.find('atom-text-editor')[0]
      editor = atom.workspaceView.find('atom-text-editor').view().getEditor()

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

  describe 'panel containers', ->
    workspaceElement = null
    beforeEach ->
      workspaceElement = atom.views.getView(atom.workspace)

    it 'inserts panel container elements in the correct places in the DOM', ->
      leftContainer = workspaceElement.querySelector('atom-panel-container.left')
      rightContainer = workspaceElement.querySelector('atom-panel-container.right')
      expect(leftContainer.nextSibling).toBe workspaceElement.verticalAxis
      expect(rightContainer.previousSibling).toBe workspaceElement.verticalAxis

      topContainer = workspaceElement.querySelector('atom-panel-container.top')
      bottomContainer = workspaceElement.querySelector('atom-panel-container.bottom')
      expect(topContainer.nextSibling).toBe workspaceElement.paneContainer
      expect(bottomContainer.previousSibling).toBe workspaceElement.paneContainer

      modalContainer = workspaceElement.querySelector('atom-panel-container.modal')
      expect(modalContainer.parentNode).toBe workspaceElement
