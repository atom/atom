RootView = require 'root-view'

describe "CommandPanel", ->
  [rootView, commandPanel] = []

  beforeEach ->
    rootView = new RootView
    rootView.enableKeymap()
    commandPanel = rootView.commandPanel

  fdescribe "when toggle-command-panel is triggered on the root view", ->
    it "toggles the command panel", ->
      rootView.attachToDom()
      expect(rootView.find('.command-panel')).not.toExist()
      expect(rootView.lastActiveEditor().isFocused).toBeTruthy()
      expect(commandPanel.editor.isFocused).toBeFalsy()

      rootView.trigger 'command-panel:toggle'
      expect(rootView.find('.command-panel').view()).toBe commandPanel
      expect(commandPanel.editor.isFocused).toBeTruthy()
      commandPanel.editor.insertText 's/war/peace/g'

      rootView.trigger 'command-panel:toggle'
      expect(rootView.find('.command-panel')).not.toExist()
      expect(rootView.lastActiveEditor().isFocused).toBeTruthy()
      expect(commandPanel.editor.isFocused).toBeFalsy()

      rootView.trigger 'command-panel:toggle'
      expect(rootView.find('.command-panel').view()).toBe commandPanel
      expect(commandPanel.editor.isFocused).toBeTruthy()
      expect(commandPanel.editor.buffer.getText()).toBe ''
      expect(commandPanel.editor.getCursorScreenPosition()).toEqual [0, 0]

  fdescribe "when esc is pressed in the command panel", ->
    it "closes the command panel", ->
      rootView.trigger 'command-panel:toggle'
      expect(rootView.find('.command-panel').view()).toBe commandPanel
      commandPanel.editor.trigger keydownEvent('escape')
      expect(rootView.find('.command-panel')).not.toExist()

