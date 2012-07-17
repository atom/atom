RootView = require 'root-view'
CommandPanel = require 'command-panel'

describe "CommandPanel", ->
  [rootView, editor, buffer, commandPanel] = []

  beforeEach ->
    rootView = new RootView
    rootView.open(require.resolve 'fixtures/sample.js')
    rootView.enableKeymap()
    editor = rootView.getActiveEditor()
    buffer = editor.activeEditSession.buffer
    commandPanel = requireExtension('command-panel')

  afterEach ->
    rootView.remove()

  describe "serialization", ->
    it "preserves the command panel's mini editor text and visibility across reloads", ->
      rootView.trigger 'command-panel:toggle'
      commandPanel.miniEditor.insertText 'abc'
      newRootView = RootView.deserialize(rootView.serialize())

      commandPanel = newRootView.activateExtension(CommandPanel)
      expect(newRootView.find('.command-panel')).toExist()
      expect(commandPanel.miniEditor.getText()).toBe 'abc'

      newRootView.remove()

  describe "when toggle-command-panel is triggered on the root view", ->
    it "toggles the command panel", ->
      rootView.attachToDom()
      expect(rootView.find('.command-panel')).not.toExist()
      expect(rootView.getActiveEditor().isFocused).toBeTruthy()
      expect(commandPanel.miniEditor.isFocused).toBeFalsy()

      rootView.trigger 'command-panel:toggle'
      expect(rootView.find('.command-panel').view()).toBe commandPanel
      expect(commandPanel.miniEditor.isFocused).toBeTruthy()
      commandPanel.miniEditor.insertText 's/war/peace/g'

      rootView.trigger 'command-panel:toggle'
      expect(rootView.find('.command-panel')).not.toExist()
      expect(rootView.getActiveEditor().isFocused).toBeTruthy()
      expect(commandPanel.miniEditor.isFocused).toBeFalsy()

      rootView.trigger 'command-panel:toggle'
      expect(rootView.find('.command-panel').view()).toBe commandPanel
      expect(commandPanel.miniEditor.isFocused).toBeTruthy()
      expect(commandPanel.miniEditor.getText()).toBe ''
      expect(commandPanel.miniEditor.getCursorScreenPosition()).toEqual [0, 0]

  describe "when command-panel:repeat-relative-address is triggered on the root view", ->
    it "repeats the last search command if there is one", ->
      rootView.trigger 'command-panel:repeat-relative-address'

      editor.setCursorScreenPosition([4, 0])

      commandPanel.execute("/current")
      expect(editor.getSelection().getBufferRange()).toEqual [[5,6], [5,13]]

      rootView.trigger 'command-panel:repeat-relative-address'
      expect(editor.getSelection().getBufferRange()).toEqual [[6,6], [6,13]]

      commandPanel.execute('s/r/R/g')

      rootView.trigger 'command-panel:repeat-relative-address'
      expect(editor.getSelection().getBufferRange()).toEqual [[6,34], [6,41]]

      commandPanel.execute('0')
      commandPanel.execute('/sort/ s/r/R/') # this contains a substitution... won't be repeated

      rootView.trigger 'command-panel:repeat-relative-address'
      expect(editor.getSelection().getBufferRange()).toEqual [[3,31], [3,38]]

  describe "when command-pane:repeat-relative-address-in-reverse is triggered on the root view", ->
    it "it repeats the last relative address in the reverse direction", ->
      rootView.trigger 'command-panel:repeat-relative-address-in-reverse'

      editor.setCursorScreenPosition([6, 0])

      commandPanel.execute("/current")
      expect(editor.getSelection().getBufferRange()).toEqual [[6,6], [6,13]]

      rootView.trigger 'command-panel:repeat-relative-address-in-reverse'
      expect(editor.getSelection().getBufferRange()).toEqual [[5,6], [5,13]]

  describe "when command-panel:set-selection-as-regex-address is triggered on the root view", ->
    it "sets the @lastRelativeAddress to a RegexAddress of the current selection", ->
      rootView.open(require.resolve('fixtures/sample.js'))
      rootView.getActiveEditor().setSelectedBufferRange([[1,21],[1,28]])

      commandInterpreter = commandPanel.commandInterpreter
      expect(commandInterpreter.lastRelativeAddress).toBeUndefined()
      rootView.trigger 'command-panel:set-selection-as-regex-address'
      expect(commandInterpreter.lastRelativeAddress.subcommands.length).toBe 1
      expect(commandInterpreter.lastRelativeAddress.subcommands[0].regex.toString()).toEqual "/\\(items\\)/"

  describe "when command-panel:find-in-file is triggered on an editor", ->
    it "pre-populates command panel's editor with /", ->
      rootView.getActiveEditor().trigger "command-panel:find-in-file"
      expect(commandPanel.parent).not.toBeEmpty()
      expect(commandPanel.miniEditor.getText()).toBe "/"

  describe "when esc is pressed in the command panel", ->
    it "closes the command panel", ->
      rootView.trigger 'command-panel:toggle'
      expect(rootView.find('.command-panel').view()).toBe commandPanel
      commandPanel.miniEditor.trigger keydownEvent('escape')
      expect(rootView.find('.command-panel')).not.toExist()

  describe "when return is pressed on the panel's editor", ->
    describe "if the command has an immediate effect", ->
      it "executes it immediately on the current buffer", ->
        rootView.trigger 'command-panel:toggle'
        commandPanel.miniEditor.insertText ',s/sort/torta/g'
        commandPanel.miniEditor.trigger keydownEvent('enter')

        expect(buffer.lineForRow(0)).toMatch /quicktorta/
        expect(buffer.lineForRow(1)).toMatch /var torta/

    describe "if the command is malformed", ->
      it "adds and removes an error class to the command panel and does not close it", ->
        rootView.trigger 'command-panel:toggle'
        commandPanel.miniEditor.insertText 'garbage-command!!'

        commandPanel.miniEditor.trigger keydownEvent('enter')
        expect(commandPanel.parent()).toExist()
        expect(commandPanel).toHaveClass 'error'

        advanceClock 400

        expect(commandPanel).not.toHaveClass 'error'

  describe "when move-up and move-down are triggerred on the editor", ->
    it "navigates forward and backward through the command history", ->
      commandPanel.execute 's/war/peace/g'
      commandPanel.execute 's/twinkies/wheatgrass/g'

      rootView.trigger 'command-panel:toggle'

      commandPanel.miniEditor.trigger 'move-up'
      expect(commandPanel.miniEditor.getText()).toBe 's/twinkies/wheatgrass/g'
      commandPanel.miniEditor.trigger 'move-up'
      expect(commandPanel.miniEditor.getText()).toBe 's/war/peace/g'
      commandPanel.miniEditor.trigger 'move-up'
      expect(commandPanel.miniEditor.getText()).toBe 's/war/peace/g'
      commandPanel.miniEditor.trigger 'move-down'
      expect(commandPanel.miniEditor.getText()).toBe 's/twinkies/wheatgrass/g'
      commandPanel.miniEditor.trigger 'move-down'
      expect(commandPanel.miniEditor.getText()).toBe ''

  describe ".execute()", ->
    it "executes the command and closes the command panel", ->
      rootView.getActiveEditor().setText("i hate love")
      rootView.getActiveEditor().getSelection().setBufferRange [[0,0], [0,Infinity]]
      rootView.trigger 'command-panel:toggle'
      commandPanel.miniEditor.insertText 's/hate/love/'
      commandPanel.execute()
      expect(rootView.getActiveEditor().getText()).toBe "i love love"
      expect(rootView.find('.command-panel')).not.toExist()
