$ = require 'jquery'
_ = require 'underscore'
RootView = require 'root-view'
StatusBar = require 'status-bar'
fs = require 'fs'

describe "StatusBar", ->
  [rootView, editor, statusBar, buffer] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    rootView.simulateDomAttachment()
    StatusBar.activate(rootView)
    editor = rootView.getActiveEditor()
    statusBar = rootView.find('.status-bar').view()
    buffer = editor.getBuffer()

  afterEach ->
    rootView.remove()

  describe "@initialize", ->
    it "appends a status bar to all existing and new editors", ->
      expect(rootView.panes.find('.pane').length).toBe 1
      expect(rootView.panes.find('.pane > .status-bar').length).toBe 1
      editor.splitRight()
      expect(rootView.find('.pane').length).toBe 2
      expect(rootView.panes.find('.pane > .status-bar').length).toBe 2

  describe ".initialize(editor)", ->
    it "displays the editor's buffer path, cursor buffer position, and buffer modified indicator", ->
      expect(statusBar.currentPath.text()).toBe 'sample.js'
      expect(statusBar.bufferModified.text()).toBe ''
      expect(statusBar.cursorPosition.text()).toBe '1,1'

    describe "when associated with an unsaved buffer", ->
      it "displays 'untitled' instead of the buffer's path, but still displays the buffer position", ->
        rootView.remove()
        rootView = new RootView
        rootView.open()
        rootView.simulateDomAttachment()
        StatusBar.activate(rootView)
        statusBar = rootView.find('.status-bar').view()
        expect(statusBar.currentPath.text()).toBe 'untitled'
        expect(statusBar.cursorPosition.text()).toBe '1,1'

  describe "when the associated editor's path changes", ->
    it "updates the path in the status bar", ->
      rootView.open(require.resolve 'fixtures/sample.txt')
      expect(statusBar.currentPath.text()).toBe 'sample.txt'

  describe "when the associated editor's buffer's content changes", ->
    it "enables the buffer modified indicator", ->
      expect(statusBar.bufferModified.text()).toBe ''
      editor.insertText("\n")
      advanceClock(buffer.stoppedChangingDelay)
      expect(statusBar.bufferModified.text()).toBe '*'
      editor.backspace()

  describe "when the buffer content has changed from the content on disk", ->
    it "disables the buffer modified indicator on save", ->
      path = "/tmp/atom-whitespace.txt"
      fs.write(path, "")
      rootView.open(path)
      expect(statusBar.bufferModified.text()).toBe ''
      editor.insertText("\n")
      advanceClock(buffer.stoppedChangingDelay)
      expect(statusBar.bufferModified.text()).toBe '*'
      editor.save()
      expect(statusBar.bufferModified.text()).toBe ''

    it "disables the buffer modified indicator if the content matches again", ->
      expect(statusBar.bufferModified.text()).toBe ''
      editor.insertText("\n")
      advanceClock(buffer.stoppedChangingDelay)
      expect(statusBar.bufferModified.text()).toBe '*'
      editor.backspace()
      advanceClock(buffer.stoppedChangingDelay)
      expect(statusBar.bufferModified.text()).toBe ''

    it "disables the buffer modified indicator when the change is undone", ->
      expect(statusBar.bufferModified.text()).toBe ''
      editor.insertText("\n")
      advanceClock(buffer.stoppedChangingDelay)
      expect(statusBar.bufferModified.text()).toBe '*'
      editor.undo()
      advanceClock(buffer.stoppedChangingDelay)
      expect(statusBar.bufferModified.text()).toBe ''

  describe "when the buffer changes", ->
    it "updates the buffer modified indicator for the new buffer", ->
      expect(statusBar.bufferModified.text()).toBe ''
      rootView.open(require.resolve('fixtures/sample.txt'))
      editor.insertText("\n")
      advanceClock(buffer.stoppedChangingDelay)
      expect(statusBar.bufferModified.text()).toBe '*'

    it "doesn't update the buffer modified indicator for the old buffer", ->
     oldBuffer = editor.getBuffer()
     expect(statusBar.bufferModified.text()).toBe ''
     rootView.open(require.resolve('fixtures/sample.txt'))
     oldBuffer.setText("new text")
     advanceClock(buffer.stoppedChangingDelay)
     expect(statusBar.bufferModified.text()).toBe ''

  describe "when the associated editor's cursor position changes", ->
    it "updates the cursor position in the status bar", ->
      editor.setCursorScreenPosition([1, 2])
      expect(statusBar.cursorPosition.text()).toBe '2,3'

  describe "git branch label", ->
    beforeEach ->
      fs.remove('/tmp/.git') if fs.isDirectory('/tmp/.git')
      rootView.attachToDom()

    it "displays the current branch for files in repositories", ->
      path = require.resolve('fixtures/git/master.git/HEAD')
      rootView.open(path)
      expect(statusBar.branchArea).toBeVisible()
      expect(statusBar.branchLabel.text()).toBe 'master'

    it "doesn't display the current branch for a file not in a repository", ->
      path = '/tmp/temp.txt'
      rootView.open(path)
      expect(statusBar.branchArea).toBeHidden()
      expect(statusBar.branchLabel.text()).toBe ''

  describe "git status label", ->
    [repo, path, originalPathText, newPath] = []

    beforeEach ->
      path = require.resolve('fixtures/git/working-dir/file.txt')
      newPath = fs.join(require.resolve('fixtures/git/working-dir'), 'new.txt')
      fs.write(newPath, "I'm new here")
      originalPathText = fs.read(path)
      rootView.attachToDom()

    afterEach ->
      fs.write(path, originalPathText)
      fs.remove(newPath) if fs.exists(newPath)

    it "displays the modified icon for a changed file", ->
      fs.write(path, "i've changed for the worse")
      rootView.open(path)
      expect(statusBar.gitStatusIcon).toHaveText('\uf26d')

    it "doesn't display the modified icon for an unchanged file", ->
      rootView.open(path)
      expect(statusBar.gitStatusIcon).toHaveText('')

    it "displays the new icon for a new file", ->
      rootView.open(newPath)
      expect(statusBar.gitStatusIcon).toHaveText('\uf26b')

    it "updates when a git-status-change event occurs", ->
      fs.write(path, "i've changed for the worse")
      rootView.open(path)
      expect(statusBar.gitStatusIcon).toHaveText('\uf26d')
      fs.write(path, originalPathText)
      rootView.getActiveEditor().getBuffer().trigger 'git-status-change'
      expect(statusBar.gitStatusIcon).toHaveText('')
