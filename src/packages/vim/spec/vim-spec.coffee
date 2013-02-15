RootView = require 'root-view'
Vim = require 'vim/lib/vim-view'

fdescribe "Vim package", ->

  [rootView, editor] = []

  beforeEach ->
    config.set("vim.enabled", true)
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

    it "enters ex mode", ->
      editor.trigger 'vim:ex-mode'
      expect(editor.vim.inCommandMode()).toBe false

    it "enters visual mode", ->
      editor.trigger 'vim:visual-mode'
      expect(editor.vim.inCommandMode()).toBe true
      expect(editor.vim.inVisualMode()).toBe true

    it "awaits input then resets to command mode", ->
      editor.trigger 'vim:command-mode'
      expect(editor.vim.inCommandMode()).toBe true
      editor.vim.enterAwaitInputMode()
      expect(editor.vim.inCommandMode()).toBe false
      expect(editor.vim.awaitingInput()).toBe true
      event = jQuery.Event("textInput", {originalEvent:{data: "a"}})
      editor.trigger(event)
      expect(editor.vim.inCommandMode()).toBe true

  describe "insert mode", ->
    it "enters insert mode", ->
      editor.trigger 'vim:insert-mode'
      expect(editor.vim.inInsertMode()).toBe true
