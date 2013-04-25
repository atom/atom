RootView = require 'root-view'
_ = require 'underscore'

describe "GitDiff package", ->
  editor = null

  beforeEach ->
    window.rootView = new RootView
    rootView.attachToDom()
    rootView.open('sample.js')
    atom.activatePackage('git-diff')
    editor = rootView.getActiveView()

  describe "when the editor has modified lines", ->
    it "highlights the modified lines", ->
      expect(editor.find('.git-line-modified').length).toBe 0
      editor.insertText('a')
      advanceClock(editor.getBuffer().stoppedChangingDelay)
      expect(editor.find('.git-line-modified').length).toBe 1
      expect(editor.find('.git-line-modified').attr('lineNumber')).toBe '0'

  describe "when the editor has added lines", ->
    it "highlights the added lines", ->
      expect(editor.find('.git-line-added').length).toBe 0
      editor.moveCursorToEndOfLine()
      editor.insertNewline()
      editor.insertText('a')
      advanceClock(editor.getBuffer().stoppedChangingDelay)
      expect(editor.find('.git-line-added').length).toBe 1
      expect(editor.find('.git-line-added').attr('lineNumber')).toBe '1'

  describe "when the editor has removed lines", ->
    it "highlights the line preceeding the deleted lines", ->
      expect(editor.find('.git-line-added').length).toBe 0
      editor.setCursorBufferPosition([5])
      editor.deleteLine()
      advanceClock(editor.getBuffer().stoppedChangingDelay)
      expect(editor.find('.git-line-removed').length).toBe 1
      expect(editor.find('.git-line-removed').attr('lineNumber')).toBe '4'

  describe "when a modified line is restored to the HEAD version contents", ->
    it "removes the diff highlight", ->
      expect(editor.find('.git-line-modified').length).toBe 0
      editor.insertText('a')
      advanceClock(editor.getBuffer().stoppedChangingDelay)
      expect(editor.find('.git-line-modified').length).toBe 1
      editor.backspace()
      advanceClock(editor.getBuffer().stoppedChangingDelay)
      expect(editor.find('.git-line-modified').length).toBe 0

  describe "when a modified file is opened", ->
    it "highlights the changed lines", ->
      path = project.resolve('sample.txt')
      buffer = project.buildBuffer(path)
      buffer.setText("Some different text.")
      rootView.open('sample.txt')
      nextTick = false
      _.nextTick -> nextTick = true
      waitsFor -> nextTick
      runs ->
        expect(editor.find('.git-line-modified').length).toBe 1
        expect(editor.find('.git-line-modified').attr('lineNumber')).toBe '0'
