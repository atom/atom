RootView = require 'root-view'

describe "CommandPanel", ->
  [rootView, commandPanel] = []

  beforeEach ->
    rootView = new RootView
    rootView.enableKeymap()
    commandPanel = rootView.commandPanel

  describe "when toggle-command-panel is triggered on the root view", ->
    it "toggles the command panel", ->
      rootView.attachToDom()
      expect(rootView.find('.command-panel')).not.toExist()
      expect(rootView.activeEditor().isFocused).toBeTruthy()
      expect(commandPanel.editor.isFocused).toBeFalsy()

      rootView.trigger 'command-panel:toggle'
      expect(rootView.find('.command-panel').view()).toBe commandPanel
      expect(commandPanel.editor.isFocused).toBeTruthy()
      # this is currently assigned dynamically since our css scheme lacks variables
      expect(commandPanel.prompt.css('font')).toBe commandPanel.editor.css('font')
      commandPanel.editor.insertText 's/war/peace/g'

      rootView.trigger 'command-panel:toggle'
      expect(rootView.find('.command-panel')).not.toExist()
      expect(rootView.activeEditor().isFocused).toBeTruthy()
      expect(commandPanel.editor.isFocused).toBeFalsy()

      rootView.trigger 'command-panel:toggle'
      expect(rootView.find('.command-panel').view()).toBe commandPanel
      expect(commandPanel.editor.isFocused).toBeTruthy()
      expect(commandPanel.editor.buffer.getText()).toBe ''
      expect(commandPanel.editor.getCursorScreenPosition()).toEqual [0, 0]

  describe "when command-panel:repeat-relative-address is triggered on the root view", ->
    it "calls .repeatRelativeAddress on the command interpreter with the active editor", ->
      spyOn(commandPanel.commandInterpreter, 'repeatRelativeAddress')
      rootView.trigger 'command-panel:repeat-relative-address'
      expect(commandPanel.commandInterpreter.repeatRelativeAddress).toHaveBeenCalledWith(rootView.activeEditor())

  describe "when command-panel:find-in-file is triggered on an editor", ->
    it "pre-populates command panel's editor with /", ->
      rootView.activeEditor().trigger "command-panel:find-in-file"
      expect(rootView.commandPanel.parent).not.toBeEmpty()
      expect(rootView.commandPanel.editor.getText()).toBe "/"

  describe "when esc is pressed in the command panel", ->
    it "closes the command panel", ->
      rootView.trigger 'command-panel:toggle'
      expect(rootView.find('.command-panel').view()).toBe commandPanel
      commandPanel.editor.trigger keydownEvent('escape')
      expect(rootView.find('.command-panel')).not.toExist()

  describe "when return is pressed on the panel's editor", ->
    it "calls execute", ->
      spyOn(commandPanel, 'execute')
      rootView.trigger 'command-panel:toggle'
      commandPanel.editor.insertText 's/hate/love/g'
      commandPanel.editor.trigger keydownEvent('enter')

      expect(commandPanel.execute).toHaveBeenCalled()

    describe "if the command is malformed", ->
      it "adds and removes an error class to the command panel and does not close it", ->
        rootView.trigger 'command-panel:toggle'
        commandPanel.editor.insertText 'garbage-command!!'

        commandPanel.editor.trigger keydownEvent('enter')
        expect(commandPanel.parent()).toExist()
        expect(commandPanel).toHaveClass 'error'

        advanceClock 400

        expect(commandPanel).not.toHaveClass 'error'

  describe "when move-up and move-down are triggerred on the editor", ->
    it "navigates forward and backward through the command history", ->
      commandPanel.execute 's/war/peace/g'
      commandPanel.execute 's/twinkies/wheatgrass/g'

      rootView.trigger 'command-panel:toggle'

      commandPanel.editor.trigger 'move-up'
      expect(commandPanel.editor.getText()).toBe 's/twinkies/wheatgrass/g'
      commandPanel.editor.trigger 'move-up'
      expect(commandPanel.editor.getText()).toBe 's/war/peace/g'
      commandPanel.editor.trigger 'move-up'
      expect(commandPanel.editor.getText()).toBe 's/war/peace/g'
      commandPanel.editor.trigger 'move-down'
      expect(commandPanel.editor.getText()).toBe 's/twinkies/wheatgrass/g'
      commandPanel.editor.trigger 'move-down'
      expect(commandPanel.editor.getText()).toBe ''

  describe ".execute()", ->
    it "executes the command and closes the command panel", ->
      rootView.activeEditor().setText("i hate love")
      rootView.activeEditor().getSelection().setBufferRange [[0,0], [0,Infinity]]
      rootView.trigger 'command-panel:toggle'
      commandPanel.editor.insertText 's/hate/love/'
      commandPanel.execute()
      expect(rootView.activeEditor().getText()).toBe "i love love"
      expect(rootView.find('.command-panel')).not.toExist()
