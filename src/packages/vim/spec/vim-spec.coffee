RootView = require 'root-view'
Vim = require 'vim/lib/vim-view'

fdescribe "Vim package", ->

  [editor, vim] = []

  beforeEach ->
    config.set("vim.enabled", true)
    window.rootView = new RootView
    rootView.open('sample.js')
    rootView.simulateDomAttachment()
    Vim.activate(rootView)
    editor = rootView.getActivePane().find(".editor").view()
    vim = editor.vim

  afterEach ->
    rootView.deactivate()

  describe "vim mode pane", ->
    it "attaches to the current and all future editors", ->
      expect(rootView.panes.find('.pane').length).toBe 1
      expect(rootView.panes.find('.pane > .vim').length).toBe 1
      rootView.getActivePane().splitRight()
      expect(rootView.find('.pane').length).toBe 2
      expect(rootView.panes.find('.pane > .vim').length).toBe 2

  describe "command mode", ->
    it "enters command mode", ->
      editor.trigger 'vim:command-mode'
      expect(vim.inCommandMode()).toBeTruthy()

    it "enters ex mode", ->
      editor.trigger 'vim:ex-mode'
      expect(vim.inCommandMode()).toBeFalsy()

    it "enters visual mode", ->
      editor.trigger 'vim:visual-mode'
      expect(vim.inCommandMode()).toBeTruthy()
      expect(vim.inVisualMode()).toBeTruthy()

    it "awaits input then resets to command mode", ->
      editor.trigger 'vim:command-mode'
      expect(vim.inCommandMode()).toBeTruthy()
      editor.vim.enterAwaitInputMode()
      expect(vim.inCommandMode()).toBeFalsy()
      expect(vim.awaitingInput()).toBeTruthy()
      event = jQuery.Event("textInput", {originalEvent:{data: "a"}})
      editor.trigger(event)
      expect(vim.inCommandMode()).toBeTruthy()

  describe "insert mode", ->
    it "enters insert mode", ->
      editor.trigger 'vim:insert-mode'
      expect(vim.inInsertMode()).toBeTruthy()
