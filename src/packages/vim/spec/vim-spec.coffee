RootView = require 'root-view'
Vim = require 'vim/lib/vim-view'

fdescribe "Vim package", ->

  [rootView, editor] = []

  beforeEach ->
    filePath = fixturesProject.resolve('sample.js')
    rootView = new RootView(filePath)
    rootView.simulateDomAttachment()
    Vim.activate(rootView)
    editor = rootView.getActiveEditor()
    vim = rootView.find('.vim').view()

  afterEach ->
    rootView.deactivate()

  describe "vim mode pane", ->
    it "attaches to the current and all future editors", ->
      expect(rootView.panes.find('.pane').length).toBe 1
      expect(rootView.panes.find('.pane > .vim').length).toBe 1
      editor.splitRight()
      expect(rootView.find('.pane').length).toBe 2
      expect(rootView.panes.find('.pane > .vim').length).toBe 2


  describe "command mode", ->
    it "enters command mode", ->
      editor.trigger 'vim:command-mode'
      expect(editor.vim.inCommandMode()).toBe true

    describe "transition to insert mode", ->
      beforeEach ->
        editor.trigger 'vim:command-mode'
      it "i key", ->
        editor.vim.miniEditor.setText("i")
        expect(editor.vim.inInsertMode()).toBe true

  describe "insert mode", ->
    it "enters insert mode", ->
      editor.trigger 'vim:insert-mode'
      expect(editor.vim.inInsertMode()).toBe true
