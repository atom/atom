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
    it "only creates a single undomanager transaction", ->
      editor.selectAll()
      editor.delete()
      editor.trigger 'vim:insert-mode'
      editor.insertText(c) for c in "abcde"
      editor.trigger 'vim:command-mode'
      editor.trigger 'vim:insert-mode'
      editor.insertText(c) for c in "fghijk"
      editor.trigger 'vim:command-mode'
      editor.trigger 'core:undo'
      expect(editor.activeEditSession.buffer.getText()).toBe("abcde")

  describe "leader key", ->
    it "creates a new virtual key", ->
      spyOn(keymap, 'handleKeyEvent')
      editor.trigger 'vim:leader'
      expect(keymap.handleKeyEvent).toHaveBeenCalled()
    it "is available for key bindings", ->
      editor.trigger 'vim:command-mode'
      keymap.add
        '.editor':
          'leader': 'vim:insert-mode'
      editor.trigger 'vim:leader'
      expect(vim.inInsertMode()).toBeTruthy()

  describe "autocomplete", ->
    it "opens the autocomplete panel", ->
      spyOn(editor, 'trigger')
      vim.autocomplete()
      expect(editor.trigger).toHaveBeenCalledWith('autocomplete:attach')
    it "selects the next element in the autocomplete panel", ->
      spyOn(editor, 'trigger')
      spyOn(vim, 'autocompleting').andReturn(true)
      vim.autocomplete()
      expect(editor.trigger).toHaveBeenCalledWith('autocomplete:next')
    it "selects the previous element in the autocomplete panel", ->
      spyOn(editor, 'trigger')
      spyOn(vim, 'autocompleting').andReturn(true)
      vim.autocomplete(true)
      expect(editor.trigger).toHaveBeenCalledWith('autocomplete:previous')

  describe "search word", ->
    it "foo", ->
      spyOn(editor, 'trigger')
      vim.searchWord()
      expect(editor.trigger).toHaveBeenCalledWith("command-panel:find-in-file")
