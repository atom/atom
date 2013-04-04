$ = require 'jquery'
_ = require 'underscore'
RootView = require 'root-view'
StatusBar = require 'status-bar/lib/status-bar-view'
fsUtils = require 'fs-utils'

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
        rootView.remove()
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
      fsUtils.write(path, "")
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
      fsUtils.remove('/tmp/.git') if fsUtils.isDirectory('/tmp/.git')
      rootView.attachToDom()

    it "displays the current branch for files in repositories", ->
      path = require.resolve('fixtures/git/master.git/HEAD')
      project.setPath(fsUtils.resolveOnLoadPath('fixtures/git/master.git'))
      rootView.open(path)
      expect(statusBar.branchArea).toBeVisible()
      expect(statusBar.branchLabel.text()).toBe 'master'

    it "doesn't display the current branch for a file not in a repository", ->
      project.setPath('/tmp')
      rootView.open('/tmp/temp.txt')
      expect(statusBar.branchArea).toBeHidden()
      expect(statusBar.branchLabel.text()).toBe ''

  describe "git status label", ->
    [repo, path, originalPathText, newPath, ignoredPath] = []

    beforeEach ->
      path = require.resolve('fixtures/git/working-dir/file.txt')
      newPath = fsUtils.join(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'), 'new.txt')
      fsUtils.write(newPath, "I'm new here")
      ignoredPath = fsUtils.join(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'), 'ignored.txt')
      fsUtils.write(ignoredPath, 'ignored.txt')
      git.getPathStatus(path)
      git.getPathStatus(newPath)
      originalPathText = fsUtils.read(path)
      rootView.attachToDom()

    afterEach ->
      fsUtils.write(path, originalPathText)
      fsUtils.remove(newPath) if fsUtils.exists(newPath)
      fsUtils.remove(ignoredPath) if fsUtils.exists(ignoredPath)

    it "displays the modified icon for a changed file", ->
      fsUtils.write(path, "i've changed for the worse")
      git.getPathStatus(path)
      rootView.open(path)
      expect(statusBar.gitStatusIcon).toHaveClass('modified-status-icon')

    it "doesn't display the modified icon for an unchanged file", ->
      rootView.open(path)
      expect(statusBar.gitStatusIcon).toHaveText('')

    it "displays the new icon for a new file", ->
      rootView.open(newPath)
      expect(statusBar.gitStatusIcon).toHaveClass('new-status-icon')

    it "displays the ignored icon for an ignored file", ->
      rootView.open(ignoredPath)
      expect(statusBar.gitStatusIcon).toHaveClass('ignored-status-icon')

    it "updates when a status-changed event occurs", ->
      fsUtils.write(path, "i've changed for the worse")
      git.getPathStatus(path)
      rootView.open(path)
      expect(statusBar.gitStatusIcon).toHaveClass('modified-status-icon')
      fsUtils.write(path, originalPathText)
      git.getPathStatus(path)
      expect(statusBar.gitStatusIcon).not.toHaveClass('modified-status-icon')

    it "displays the diff stat for modified files", ->
      fsUtils.write(path, "i've changed for the worse")
      git.getPathStatus(path)
      rootView.open(path)
      expect(statusBar.gitStatusIcon).toHaveText('+1,-1')

    it "displays the diff stat for new files", ->
      rootView.open(newPath)
      expect(statusBar.gitStatusIcon).toHaveText('+1')

  describe "grammar label", ->
    beforeEach ->
      atom.activatePackage('text.tmbundle', sync: true)
      atom.activatePackage('javascript.tmbundle', sync: true)

    it "displays the name of the current grammar", ->
      expect(statusBar.find('.grammar-name').text()).toBe 'JavaScript'

    it "hides the label when the current grammar is the null grammar", ->
      rootView.attachToDom()
      editor.activeEditSession.languageMode.grammar = syntax.nullGrammar
      editor.activeEditSession.trigger 'grammar-changed'
      expect(statusBar.find('.grammar-name')).toBeHidden()
      expect(statusBar.find('.grammar-name').text()).toBe ''
      editor.reloadGrammar()
      expect(statusBar.find('.grammar-name')).toBeVisible()
      expect(statusBar.find('.grammar-name').text()).toBe 'JavaScript'

    describe "when the editor's grammar changes", ->
      it "displays the new grammar of the editor", ->
        syntax.setGrammarOverrideForPath(editor.getPath(), 'text.plain')
        editor.reloadGrammar()
        expect(statusBar.find('.grammar-name').text()).toBe 'Plain Text'

    describe "when clicked", ->
      it "toggles the grammar-selector:show event", ->
        eventHandler = jasmine.createSpy('eventHandler')
        editor.on 'grammar-selector:show', eventHandler
        statusBar.find('.grammar-name').click()
        expect(eventHandler).toHaveBeenCalled()
