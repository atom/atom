RootView = require 'root-view'
CommandPanel = require 'command-panel'
_ = require 'underscore'

describe "CommandPanel", ->
  [rootView, editor, buffer, commandPanel, project] = []

  beforeEach ->
    rootView = new RootView
    rootView.open(require.resolve 'fixtures/sample.js')
    rootView.enableKeymap()
    project = rootView.project
    editor = rootView.getActiveEditor()
    buffer = editor.activeEditSession.buffer
    commandPanel = requireExtension('command-panel')
    commandPanel.history = []
    commandPanel.historyIndex = 0

  afterEach ->
    rootView.deactivate()

  describe "serialization", ->
    it "preserves the command panel's mini-editor text, visibility, focus, and history across reloads", ->
      rootView.attachToDom()
      rootView.trigger 'command-panel:toggle'
      expect(commandPanel.miniEditor.isFocused).toBeTruthy()
      commandPanel.execute('/test')
      expect(commandPanel.history.length).toBe(1)
      expect(commandPanel.history[0]).toBe('/test')
      expect(commandPanel.historyIndex).toBe(1)
      rootView.trigger 'command-panel:toggle'
      expect(commandPanel.miniEditor.isFocused).toBeTruthy()
      commandPanel.miniEditor.insertText 'abc'
      rootView2 = RootView.deserialize(rootView.serialize())
      rootView.deactivate()
      rootView2.attachToDom()

      commandPanel = rootView2.activateExtension(CommandPanel)
      expect(rootView2.find('.command-panel')).toExist()
      expect(commandPanel.miniEditor.getText()).toBe 'abc'
      expect(commandPanel.miniEditor.isFocused).toBeTruthy()
      expect(commandPanel.history.length).toBe(1)
      expect(commandPanel.history[0]).toBe('/test')
      expect(commandPanel.historyIndex).toBe(1)

      rootView2.focus()
      expect(commandPanel.miniEditor.isFocused).toBeFalsy()
      rootView3 = RootView.deserialize(rootView2.serialize())
      rootView2.deactivate()
      rootView3.attachToDom()
      commandPanel = rootView3.activateExtension(CommandPanel)

      expect(commandPanel.miniEditor.isFocused).toBeFalsy()
      rootView3.deactivate()

    it "only retains the configured max serialized history size", ->
      rootView.attachToDom()

      commandPanel.maxSerializedHistorySize = 2
      commandPanel.execute('/test1')
      commandPanel.execute('/test2')
      commandPanel.execute('/test3')
      expect(commandPanel.history.length).toBe(3)
      expect(commandPanel.history[0]).toBe('/test1')
      expect(commandPanel.history[1]).toBe('/test2')
      expect(commandPanel.history[2]).toBe('/test3')
      expect(commandPanel.historyIndex).toBe(3)

      rootView2 = RootView.deserialize(rootView.serialize())
      rootView.deactivate()
      rootView2.attachToDom()

      commandPanel = rootView2.activateExtension(CommandPanel)
      expect(commandPanel.history.length).toBe(2)
      expect(commandPanel.history[0]).toBe('/test2')
      expect(commandPanel.history[1]).toBe('/test3')
      expect(commandPanel.historyIndex).toBe(2)

      rootView2.deactivate()

  describe "when command-panel:close is triggered on the command panel", ->
    it "detaches the command panel", ->
      commandPanel.attach()
      commandPanel.trigger('command-panel:close')
      expect(commandPanel.hasParent()).toBeFalsy()

  describe "when command-panel:toggle is triggered on the root view", ->
    beforeEach ->
      rootView.attachToDom()

    describe "when the command panel is visible", ->
      beforeEach ->
        commandPanel.attach()

      describe "when the mini editor is focused", ->
        it "closes the command panel", ->
          expect(commandPanel.miniEditor.hiddenInput).toMatchSelector ':focus'
          rootView.trigger 'command-panel:toggle'
          expect(commandPanel.hasParent()).toBeFalsy()

      describe "when the mini editor is not focused", ->
        it "focuses the mini editor", ->
          rootView.focus()
          expect(commandPanel.miniEditor.hiddenInput).not.toMatchSelector ':focus'
          rootView.trigger 'command-panel:toggle'
          expect(commandPanel.hasParent()).toBeTruthy()
          expect(commandPanel.miniEditor.hiddenInput).toMatchSelector ':focus'

    describe "when the command panel is not visible", ->
      it "shows and focuses the command panel", ->
        expect(commandPanel.hasParent()).toBeFalsy()
        rootView.trigger 'command-panel:toggle'
        expect(commandPanel.hasParent()).toBeTruthy()

  describe "when command-panel:toggle-preview is triggered on the root view", ->
    beforeEach ->
      rootView.attachToDom()

    describe "when the preview list is/was previously visible", ->
      beforeEach ->
        rootView.trigger 'command-panel:toggle'
        waitsForPromise -> commandPanel.execute('X x/a+/')

      describe "when the command panel is visible", ->
        beforeEach ->
          expect(commandPanel.hasParent()).toBeTruthy()

        describe "when the preview list is visible", ->
          beforeEach ->
            expect(commandPanel.previewList).toBeVisible()

          describe "when the preview list is focused", ->
            it "hides the command panel", ->
              expect(commandPanel.previewList).toMatchSelector(':focus')
              rootView.trigger 'command-panel:toggle-preview'
              expect(commandPanel.hasParent()).toBeFalsy()

          describe "when the preview list is not focused", ->
            it "focuses the preview list", ->
              commandPanel.miniEditor.focus()
              rootView.trigger 'command-panel:toggle-preview'
              expect(commandPanel.previewList).toMatchSelector(':focus')

        describe "when the preview list is not visible", ->
          beforeEach ->
            commandPanel.miniEditor.focus()
            rootView.trigger 'command-panel:toggle'
            rootView.trigger 'command-panel:toggle'
            expect(commandPanel.hasParent()).toBeTruthy()
            expect(commandPanel.previewList).toBeHidden()

          it "shows and focuses the preview list", ->
            rootView.trigger 'command-panel:toggle-preview'
            expect(commandPanel.previewList).toBeVisible()
            expect(commandPanel.previewList).toMatchSelector(':focus')

      describe "when the command panel is not visible", ->
        it "shows the command panel and the preview list, and focuses the preview list", ->
          commandPanel.miniEditor.focus()
          rootView.trigger 'command-panel:toggle'
          expect(commandPanel.hasParent()).toBeFalsy()

          rootView.trigger 'command-panel:toggle-preview'
          expect(commandPanel.hasParent()).toBeTruthy()
          expect(commandPanel.previewList).toBeVisible()
          expect(commandPanel.previewList).toMatchSelector(':focus')

    describe "when the preview list has never been opened", ->
      describe "when the command panel is visible", ->
        beforeEach ->
          rootView.trigger 'command-panel:toggle'
          expect(commandPanel.hasParent()).toBeTruthy()

        describe "when the mini editor is focused", ->
          it "retains focus on the mini editor and does not show the preview list", ->
            expect(commandPanel.miniEditor.isFocused).toBeTruthy()
            rootView.trigger 'command-panel:toggle-preview'
            expect(commandPanel.previewList).toBeHidden()
            expect(commandPanel.miniEditor.isFocused).toBeTruthy()

        describe "when the mini editor is not focused", ->
          it "focuses the mini editor and does not show the preview list", ->
            rootView.focus()
            rootView.trigger 'command-panel:toggle-preview'
            expect(commandPanel.previewList).toBeHidden()
            expect(commandPanel.miniEditor.isFocused).toBeTruthy()

      describe "when the command panel is not visible", ->
        it "shows the command panel and focuses the mini editor, but does not show the preview list", ->

  describe "when command-panel:unfocus is triggered on the command panel", ->
    it "returns focus to the root view but does not hide the command panel", ->
      rootView.attachToDom()
      commandPanel.attach()
      expect(commandPanel.miniEditor.hiddenInput).toMatchSelector ':focus'
      commandPanel.trigger 'command-panel:unfocus'
      expect(commandPanel.hasParent()).toBeTruthy()
      expect(commandPanel.miniEditor.hiddenInput).not.toMatchSelector ':focus'

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

  describe "when command-panel:repeat-relative-address-in-reverse is triggered on the root view", ->
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
      expect(commandInterpreter.lastRelativeAddress.subcommands[0].regex.toString()).toEqual "/\\(items\\)/i"

  describe "when command-panel:find-in-file is triggered on an editor", ->
    it "pre-populates the command panel's editor with / and moves the cursor to the last column", ->
      spyOn(commandPanel, 'attach').andCallThrough()
      commandPanel.miniEditor.setText("foo")
      commandPanel.miniEditor.setCursorBufferPosition([0, 0])

      rootView.getActiveEditor().trigger "command-panel:find-in-file"
      expect(commandPanel.attach).toHaveBeenCalled()
      expect(commandPanel.parent).not.toBeEmpty()
      expect(commandPanel.miniEditor.getText()).toBe "/"
      expect(commandPanel.miniEditor.getCursorBufferPosition()).toEqual [0, 1]

  describe "when command-panel:find-in-project is triggered on the root view", ->
    it "pre-populates the command panel's editor with Xx/ and moves the cursor to the last column", ->
      spyOn(commandPanel, 'attach').andCallThrough()
      commandPanel.miniEditor.setText("foo")
      commandPanel.miniEditor.setCursorBufferPosition([0, 0])

      rootView.trigger "command-panel:find-in-project"
      expect(commandPanel.attach).toHaveBeenCalled()
      expect(commandPanel.parent).not.toBeEmpty()
      expect(commandPanel.miniEditor.getText()).toBe "Xx/"
      expect(commandPanel.miniEditor.getCursorBufferPosition()).toEqual [0, 3]

  describe "when return is pressed on the panel's editor", ->
    describe "if the command has an immediate effect", ->
      it "executes it immediately on the current buffer", ->
        rootView.trigger 'command-panel:toggle'
        commandPanel.miniEditor.insertText ',s/sort/torta/g'
        commandPanel.miniEditor.hiddenInput.trigger keydownEvent('enter')

        expect(buffer.lineForRow(0)).toMatch /quicktorta/
        expect(buffer.lineForRow(1)).toMatch /var torta/

    describe "when the command returns operations to be previewed", ->
      beforeEach ->
        rootView.attachToDom()
        editor.remove()
        rootView.trigger 'command-panel:toggle'
        waitsForPromise -> commandPanel.execute('X x/a+/')

      it "displays and focuses the operation preview list", ->
        expect(commandPanel).toBeVisible()
        expect(commandPanel.previewList).toBeVisible()
        expect(commandPanel.previewList).toMatchSelector ':focus'
        previewItem = commandPanel.previewList.find("li:contains(dir/a):first")
        expect(previewItem.find('.path').text()).toBe "dir/a"
        expect(previewItem.find('.preview').text()).toBe "aaa bbb"
        expect(previewItem.find('.preview > .match').text()).toBe "aaa"

        rootView.trigger 'command-panel:toggle-preview' # ensure we can close panel without problems
        expect(commandPanel).toBeHidden()

      it "destroys previously previewed operations if there are any", ->
        waitsForPromise -> commandPanel.execute('X x/b+/')
        # there shouldn't be any dangling operations after this

    describe "if the command is malformed", ->
      it "adds and removes an error class to the command panel and does not close it", ->
        rootView.trigger 'command-panel:toggle'
        commandPanel.miniEditor.insertText 'garbage-command!!'

        commandPanel.miniEditor.hiddenInput.trigger keydownEvent('enter')
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

  describe "when the preview list is focused with search operations", ->
    previewList = null

    beforeEach ->
      previewList = commandPanel.previewList
      rootView.trigger 'command-panel:toggle'
      waitsForPromise -> commandPanel.execute('X x/a+/')

    describe "when move-down and move-up are triggered on the preview list", ->
      it "selects the next/previous operation (if there is one), and scrolls the list if needed", ->
        rootView.attachToDom()
        expect(previewList.find('li:eq(0)')).toHaveClass 'selected'
        expect(previewList.getSelectedOperation()).toBe previewList.getOperations()[0]

        previewList.trigger 'move-up'
        expect(previewList.find('li:eq(0)')).toHaveClass 'selected'
        expect(previewList.getSelectedOperation()).toBe previewList.getOperations()[0]

        previewList.trigger 'move-down'
        expect(previewList.find('li:eq(1)')).toHaveClass 'selected'
        expect(previewList.getSelectedOperation()).toBe previewList.getOperations()[1]

        previewList.trigger 'move-down'
        expect(previewList.find('li:eq(2)')).toHaveClass 'selected'
        expect(previewList.getSelectedOperation()).toBe previewList.getOperations()[2]

        previewList.trigger 'move-up'
        expect(previewList.find('li:eq(1)')).toHaveClass 'selected'
        expect(previewList.getSelectedOperation()).toBe previewList.getOperations()[1]

        _.times previewList.getOperations().length, -> previewList.trigger 'move-down'

        expect(previewList.find('li:last')).toHaveClass 'selected'
        expect(previewList.getSelectedOperation()).toBe _.last(previewList.getOperations())

        expect(previewList.scrollBottom()).toBeCloseTo previewList.prop('scrollHeight'), -1

        _.times previewList.getOperations().length, -> previewList.trigger 'move-up'

    describe "when command-panel:execute is triggered on the preview list", ->
      it "opens the operation's buffer, selects the search result, and focuses the active editor", ->
        spyOn(rootView, 'focus')
        executeHandler = jasmine.createSpy('executeHandler')
        commandPanel.on 'command-panel:execute', executeHandler

        _.times 4, -> previewList.trigger 'move-down'
        operation = previewList.getSelectedOperation()

        previewList.trigger 'command-panel:execute'

        editSession = rootView.getActiveEditSession()
        expect(editSession.buffer.getPath()).toBe project.resolve(operation.getPath())
        expect(editSession.getSelectedBufferRange()).toEqual operation.getBufferRange()
        expect(rootView.focus).toHaveBeenCalled()

        expect(executeHandler).not.toHaveBeenCalled()

    describe "when an operation in the preview list is clicked", ->
      it "opens the operation's buffer, selects the search result, and focuses the active editor", ->
        spyOn(rootView, 'focus')
        operation = previewList.getOperations()[4]

        previewList.find('li:eq(4) span').mousedown()

        expect(previewList.getSelectedOperation()).toBe operation
        editSession = rootView.getActiveEditSession()
        expect(editSession.buffer.getPath()).toBe project.resolve(operation.getPath())
        expect(editSession.getSelectedBufferRange()).toEqual operation.getBufferRange()
        expect(rootView.focus).toHaveBeenCalled()
