RootView = require 'root-view'
Vim = require 'vim/lib/vim-view'

fdescribe "Vim package", ->

  [editor] = []

  beforeEach ->
    config.set("vim.enabled", true)
    window.rootView = new RootView()
    rootView.open('sample.js')
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
      expect(editor.vim.inCommandMode()).toBeTruthy()

    it "enters ex mode", ->
      editor.trigger 'vim:ex-mode'
      expect(editor.vim.inCommandMode()).toBeFalsy()

    it "enters visual mode", ->
      editor.trigger 'vim:visual-mode'
      expect(editor.vim.inCommandMode()).toBeTruthy()
      expect(editor.vim.inVisualMode()).toBeTruthy()

    it "awaits input then resets to command mode", ->
      editor.trigger 'vim:command-mode'
      expect(editor.vim.inCommandMode()).toBeTruthy()
      editor.vim.enterAwaitInputMode()
      expect(editor.vim.inCommandMode()).toBeFalsy()
      expect(editor.vim.awaitingInput()).toBeTruthy()
      event = jQuery.Event("textInput", {originalEvent:{data: "a"}})
      editor.trigger(event)
      expect(editor.vim.inCommandMode()).toBeTruthy()

  describe "insert mode", ->
    it "enters insert mode", ->
      editor.trigger 'vim:insert-mode'
      expect(editor.vim.inInsertMode()).toBeTruthy()
