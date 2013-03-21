$ = require 'jquery'
_ = require 'underscore'
RootView = require 'root-view'
StatusBar = require 'status-bar/lib/status-bar-view'
fs = require 'fs-utils'

describe "StatusBar", ->
  [editor, statusBar, buffer] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    rootView.simulateDomAttachment()
    StatusBar.activate()
    editor = rootView.getActiveView()
    statusBar = rootView.find('.status-bar').view()
    buffer = editor.getBuffer()

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
        rootView.deactivate()
        window.rootView = new RootView
        rootView.open()
        rootView.simulateDomAttachment()
        StatusBar.activate()
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
      editor.getBuffer().save()
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
      project.setPath(fs.resolveOnLoadPath('fixtures/git/master.git'))
      rootView.open(path)
      expect(statusBar.branchArea).toBeVisible()
      expect(statusBar.branchLabel.text()).toBe 'master'

    it "doesn't display the current branch for a file not in a repository", ->
      project.setPath('/tmp')
      rootView.open('/tmp/temp.txt')
      expect(statusBar.branchArea).toBeHidden()
      expect(statusBar.branchLabel.text()).toBe ''

  describe "git status label", ->
    [repo, path, originalPathText, newPath] = []

    beforeEach ->
      path = require.resolve('fixtures/git/working-dir/file.txt')
      newPath = fs.join(fs.resolveOnLoadPath('fixtures/git/working-dir'), 'new.txt')
      fs.write(newPath, "I'm new here")
      git.getPathStatus(path)
      git.getPathStatus(newPath)
      originalPathText = fs.read(path)
      rootView.attachToDom()

    afterEach ->
      fs.write(path, originalPathText)
      fs.remove(newPath) if fs.exists(newPath)

    it "displays the modified icon for a changed file", ->
      fs.write(path, "i've changed for the worse")
      git.getPathStatus(path)
      rootView.open(path)
      expect(statusBar.gitStatusIcon).toHaveClass('modified-status-icon')

    it "doesn't display the modified icon for an unchanged file", ->
      rootView.open(path)
      expect(statusBar.gitStatusIcon).toHaveText('')

    it "displays the new icon for a new file", ->
      rootView.open(newPath)
      expect(statusBar.gitStatusIcon).toHaveClass('new-status-icon')

    it "updates when a status-changed event occurs", ->
      fs.write(path, "i've changed for the worse")
      git.getPathStatus(path)
      rootView.open(path)
      expect(statusBar.gitStatusIcon).toHaveClass('modified-status-icon')
      fs.write(path, originalPathText)
      git.getPathStatus(path)
      expect(statusBar.gitStatusIcon).not.toHaveClass('modified-status-icon')

    it "displays the diff stat for modified files", ->
      fs.write(path, "i've changed for the worse")
      git.getPathStatus(path)
      rootView.open(path)
      expect(statusBar.gitStatusIcon).toHaveText('+1,-1')

    it "displays the diff stat for new files", ->
      rootView.open(newPath)
      expect(statusBar.gitStatusIcon).toHaveText('+1')

  describe "grammar label", ->
    it "displays the name of the current grammar", ->
      expect(statusBar.find('.grammar-name').text()).toBe 'JavaScript'

    describe "when the editor's grammar changes", ->
      it "displays the new grammar of the editor", ->
        textGrammar = _.find syntax.grammars, (grammar) -> grammar.name is 'Plain Text'
        project.addGrammarOverrideForPath(editor.getPath(), textGrammar)
        editor.reloadGrammar()
        expect(statusBar.find('.grammar-name').text()).toBe textGrammar.name

    describe "when clicked", ->
      it "toggles the editor:select-grammar event", ->
        eventHandler = jasmine.createSpy('eventHandler')
        editor.on 'editor:select-grammar', eventHandler
        statusBar.find('.grammar-name').click()
        expect(eventHandler).toHaveBeenCalled()
