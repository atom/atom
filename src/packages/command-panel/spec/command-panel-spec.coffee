RootView = require 'root-view'
CommandPanelView = require 'command-panel/lib/command-panel-view'
shell = require 'shell'
_ = require 'underscore'

describe "CommandPanel", ->
  [editSession, buffer, commandPanel] = []

  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    rootView.enableKeymap()
    editSession = rootView.getActivePaneItem()
    buffer = editSession.buffer
    commandPanelMain = atom.activatePackage('command-panel', immediate: true).mainModule
    commandPanel = commandPanelMain.commandPanelView
    commandPanel.history = []
    commandPanel.historyIndex = 0

  describe "serialization", ->
    it "preserves the command panel's history across reloads", ->
      rootView.attachToDom()
      rootView.trigger 'command-panel:toggle'
      expect(commandPanel.miniEditor.isFocused).toBeTruthy()
      commandPanel.execute('/.')
      expect(commandPanel.history.length).toBe(1)
      expect(commandPanel.history[0]).toBe('/.')
      expect(commandPanel.historyIndex).toBe(1)
      rootView.trigger 'command-panel:toggle'
      expect(commandPanel.miniEditor.isFocused).toBeTruthy()

      atom.deactivatePackage('command-panel')
      atom.activatePackage('command-panel')

      expect(rootView.find('.command-panel')).not.toExist()
      rootView.trigger 'command-panel:toggle'
      expect(rootView.find('.command-panel')).toExist()
      commandPanel = rootView.find('.command-panel').view()
      expect(commandPanel.history.length).toBe(1)
      expect(commandPanel.history[0]).toBe('/.')
      expect(commandPanel.historyIndex).toBe(1)

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

      atom.deactivatePackage('command-panel')
      atom.activatePackage('command-panel')

      rootView.trigger 'command-panel:toggle'
      commandPanel = rootView.find('.command-panel').view()

      expect(commandPanel.history.length).toBe(2)
      expect(commandPanel.history[0]).toBe('/test2')
      expect(commandPanel.history[1]).toBe('/test3')
      expect(commandPanel.historyIndex).toBe(2)

  describe "when core:close is triggered on the command panel", ->
    it "detaches the command panel, focuses the RootView and does not bubble the core:close event", ->
      commandPanel.attach('command')
      expect(commandPanel.miniEditor.getText()).toBe 'command'
      rootViewCloseHandler = jasmine.createSpy('rootViewCloseHandler')
      rootView.on 'core:close', rootViewCloseHandler
      spyOn(rootView, 'focus')

      commandPanel.trigger('core:close')

      expect(rootView.focus).toHaveBeenCalled()
      expect(rootViewCloseHandler).not.toHaveBeenCalled()
      expect(commandPanel.hasParent()).toBeFalsy()
      expect(commandPanel.miniEditor.getText()).toBe 'command'

  describe "when core:cancel is triggered on the command panel's mini editor", ->
    it "detaches the command panel, focuses the RootView and does not bubble the core:cancel event", ->
      commandPanel.attach('command')
      expect(commandPanel.miniEditor.getText()).toBe 'command'
      rootViewCancelHandler = jasmine.createSpy('rootViewCancelHandler')
      rootView.on 'core:cancel', rootViewCancelHandler
      spyOn(rootView, 'focus')

      commandPanel.miniEditor.trigger('core:cancel')

      expect(rootView.focus).toHaveBeenCalled()
      expect(rootViewCancelHandler).not.toHaveBeenCalled()
      expect(commandPanel.hasParent()).toBeFalsy()
      expect(commandPanel.miniEditor.getText()).toBe 'command'

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

      describe "when the command panel is opened a second time", ->
        it "displays and selects the previously entered text", ->
          commandPanel.miniEditor.setText('command1')
          rootView.trigger 'command-panel:toggle'
          expect(commandPanel.hasParent()).toBeFalsy()
          rootView.trigger 'command-panel:toggle'
          expect(commandPanel.hasParent()).toBeTruthy()
          expect(commandPanel.miniEditor.getText()).toBe 'command1'
          expect(commandPanel.miniEditor.getSelectedText()).toBe 'command1'

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
        waitsForPromise -> commandPanel.execute('X x/quicksort/')

      describe "when the command panel is visible", ->
        beforeEach ->
          expect(commandPanel.hasParent()).toBeTruthy()

        describe "when the preview list is visible", ->
          beforeEach ->
            expect(commandPanel.previewList).toBeVisible()

          it  "shows the expand and collapse all buttons", ->
            expect(commandPanel.collapseAll).toBeVisible()
            expect(commandPanel.expandAll).toBeVisible()

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
          it "retains focus on the mini editor and does not show the preview list or preview header", ->
            expect(commandPanel.miniEditor.isFocused).toBeTruthy()
            rootView.trigger 'command-panel:toggle-preview'
            expect(commandPanel.previewList).toBeHidden()
            expect(commandPanel.previewHeader).toBeHidden()
            expect(commandPanel.miniEditor.isFocused).toBeTruthy()

        describe "when the mini editor is not focused", ->
          it "focuses the mini editor and does not show the preview list or preview header", ->
            rootView.focus()
            rootView.trigger 'command-panel:toggle-preview'
            expect(commandPanel.previewList).toBeHidden()
            expect(commandPanel.previewHeader).toBeHidden()
            expect(commandPanel.miniEditor.isFocused).toBeTruthy()

      describe "when the command panel is not visible", ->
        it "shows the command panel and focuses the mini editor, but does not show the preview list", ->

  describe "when tool-panel:unfocus is triggered on the command panel", ->
    it "returns focus to the root view but does not hide the command panel", ->
      rootView.attachToDom()
      commandPanel.attach()
      expect(commandPanel.miniEditor.hiddenInput).toMatchSelector ':focus'
      commandPanel.trigger 'tool-panel:unfocus'
      expect(commandPanel.hasParent()).toBeTruthy()
      expect(commandPanel.miniEditor.hiddenInput).not.toMatchSelector ':focus'

  describe "when command-panel:repeat-relative-address is triggered on the root view", ->
    describe "when there is more than one match", ->
      it "repeats the last search command if there is one", ->
        rootView.trigger 'command-panel:repeat-relative-address'

        editSession.setCursorScreenPosition([4, 0])

        commandPanel.execute("/current")
        expect(editSession.getSelectedBufferRange()).toEqual [[5,6], [5,13]]

        rootView.trigger 'command-panel:repeat-relative-address'
        expect(editSession.getSelectedBufferRange()).toEqual [[6,6], [6,13]]

        commandPanel.execute('s/r/R/g')

        rootView.trigger 'command-panel:repeat-relative-address'
        expect(editSession.getSelectedBufferRange()).toEqual [[6,34], [6,41]]

        commandPanel.execute('0')
        commandPanel.execute('/sort/ s/r/R/') # this contains a substitution... won't be repeated

        rootView.trigger 'command-panel:repeat-relative-address'
        expect(editSession.getSelectedBufferRange()).toEqual [[3,31], [3,38]]

    describe "when there is only one match and it is selected", ->
      it "maintains the current selection and plays a beep", ->
        editSession.setCursorScreenPosition([0, 0])
        waitsForPromise ->
          commandPanel.execute("/Array")
        runs ->
          expect(editSession.getSelectedBufferRange()).toEqual [[11,14], [11,19]]
          spyOn(shell, 'beep')
          rootView.trigger 'command-panel:repeat-relative-address'
        waitsFor ->
          shell.beep.callCount > 0
        runs ->
          expect(editSession.getSelectedBufferRange()).toEqual [[11,14], [11,19]]

  describe "when command-panel:repeat-relative-address-in-reverse is triggered on the root view", ->
    describe "when there is more than one match", ->
      it "it repeats the last relative address in the reverse direction", ->
        rootView.trigger 'command-panel:repeat-relative-address-in-reverse'

        editSession.setCursorScreenPosition([6, 0])

        commandPanel.execute("/current")
        expect(editSession.getSelectedBufferRange()).toEqual [[6,6], [6,13]]

        rootView.trigger 'command-panel:repeat-relative-address-in-reverse'
        expect(editSession.getSelectedBufferRange()).toEqual [[5,6], [5,13]]

    describe "when there is only one match and it is selected", ->
      it "maintains the current selection and plays a beep", ->
        editSession.setCursorScreenPosition([0, 0])
        waitsForPromise ->
          commandPanel.execute("/Array")
        runs ->
          expect(editSession.getSelectedBufferRange()).toEqual [[11,14], [11,19]]
          spyOn(shell, 'beep')
          rootView.trigger 'command-panel:repeat-relative-address-in-reverse'
        waitsFor ->
          shell.beep.callCount > 0
        runs ->
          expect(editSession.getSelectedBufferRange()).toEqual [[11,14], [11,19]]

  describe "when command-panel:set-selection-as-regex-address is triggered on the root view", ->
    it "sets the @lastRelativeAddress to a RegexAddress of the current selection", ->
      rootView.open(require.resolve('fixtures/sample.js'))
      rootView.getActivePaneItem().setSelectedBufferRange([[1,21],[1,28]])

      commandInterpreter = commandPanel.commandInterpreter
      expect(commandInterpreter.lastRelativeAddress).toBeUndefined()
      rootView.trigger 'command-panel:set-selection-as-regex-address'
      expect(commandInterpreter.lastRelativeAddress.subcommands.length).toBe 1
      expect(commandInterpreter.lastRelativeAddress.subcommands[0].regex.toString()).toEqual "/\\(items\\)/i"

  describe "when command-panel:find-in-file is triggered on an editor", ->
    describe "when the command panel's editor does not begin with /", ->
      it "pre-populates the command panel's editor with / and moves the cursor to the last column", ->
        spyOn(commandPanel, 'attach').andCallThrough()
        commandPanel.miniEditor.setText("foo")
        commandPanel.miniEditor.setCursorBufferPosition([0, 0])

        rootView.getActiveView().trigger "command-panel:find-in-file"
        expect(commandPanel.attach).toHaveBeenCalled()
        expect(commandPanel.parent).not.toBeEmpty()
        expect(commandPanel.miniEditor.getText()).toBe "/"
        expect(commandPanel.miniEditor.getCursorBufferPosition()).toEqual [0, 1]

    describe "when the command panel's editor begins with /", ->
      it "selects text after the /", ->
        spyOn(commandPanel, 'attach').andCallThrough()
        commandPanel.miniEditor.setText("/foo")
        commandPanel.miniEditor.setCursorBufferPosition([0, 0])

        rootView.getActiveView().trigger "command-panel:find-in-file"
        expect(commandPanel.attach).toHaveBeenCalled()
        expect(commandPanel.parent).not.toBeEmpty()
        expect(commandPanel.miniEditor.getText()).toBe "/foo"
        expect(commandPanel.miniEditor.getSelectedText()).toBe "foo"

  describe "when command-panel:find-in-project is triggered on the root view", ->
    describe "when the command panel's editor does not begin with Xx/", ->
      it "pre-populates the command panel's editor with Xx/ and moves the cursor to the last column", ->
        spyOn(commandPanel, 'attach').andCallThrough()
        commandPanel.miniEditor.setText("foo")
        commandPanel.miniEditor.setCursorBufferPosition([0, 0])

        rootView.trigger "command-panel:find-in-project"
        expect(commandPanel.attach).toHaveBeenCalled()
        expect(commandPanel.parent).not.toBeEmpty()
        expect(commandPanel.miniEditor.getText()).toBe "Xx/"
        expect(commandPanel.miniEditor.getCursorBufferPosition()).toEqual [0, 3]

    describe "when the command panel's editor begins with Xx/", ->
      it "selects text after the Xx/", ->
        spyOn(commandPanel, 'attach').andCallThrough()
        commandPanel.miniEditor.setText("Xx/foo")
        commandPanel.miniEditor.setCursorBufferPosition([0, 0])

        rootView.getActiveView().trigger "command-panel:find-in-project"
        expect(commandPanel.attach).toHaveBeenCalled()
        expect(commandPanel.parent).not.toBeEmpty()
        expect(commandPanel.miniEditor.getText()).toBe "Xx/foo"
        expect(commandPanel.miniEditor.getSelectedText()).toBe "foo"

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
        rootView.getActivePane().remove()
        rootView.attachToDom()
        rootView.trigger 'command-panel:toggle'
        waitsForPromise -> commandPanel.execute('X x/quicksort/')

      it "displays and focuses the operation preview list", ->
        expect(commandPanel).toBeVisible()
        expect(commandPanel.previewList).toBeVisible()
        expect(commandPanel.previewList).toMatchSelector ':focus'
        previewItem = commandPanel.previewList.find("li:contains(sample.js):first")
        expect(previewItem.find('.path-details').text()).toBe "sample.js(1)"
        expect(previewItem.next().find('.preview').text()).toBe "var quicksort = function () {"
        expect(previewItem.next().find('.preview > .match').text()).toBe "quicksort"

        rootView.trigger 'command-panel:toggle-preview' # ensure we can close panel without problems
        expect(commandPanel).toBeHidden()

      it "destroys previously previewed operations if there are any", ->
        waitsForPromise -> commandPanel.execute('X x/pivot/')
        # there shouldn't be any dangling operations after this

    describe "if the command is malformed", ->
      it "adds and removes an error class to the command panel and does not close it or display a loading message", ->
        rootView.attachToDom()
        rootView.trigger 'command-panel:toggle'
        commandPanel.miniEditor.insertText 'garbage-command!!'

        commandPanel.miniEditor.hiddenInput.trigger keydownEvent('enter')
        expect(commandPanel.parent()).toExist()
        expect(commandPanel).toHaveClass 'error'
        expect(commandPanel.loadingMessage).toBeHidden()

        advanceClock 400

        expect(commandPanel).not.toHaveClass 'error'

    describe "if the command returns an error message", ->
      beforeEach ->
        rootView.attachToDom()
        rootView.trigger 'command-panel:toggle'
        commandPanel.miniEditor.insertText '/garbage'
        expect(commandPanel.errorMessages).not.toBeVisible()
        commandPanel.miniEditor.hiddenInput.trigger keydownEvent('enter')

      it "adds and removes an error class to the command panel and displays the error message", ->
        expect(commandPanel).toBeVisible()
        expect(commandPanel.errorMessages).toBeVisible()
        expect(commandPanel).toHaveClass 'error'

      it "removes the error message when the command-panel is toggled", ->
        rootView.trigger 'command-panel:toggle' # off
        rootView.trigger 'command-panel:toggle' # on
        expect(commandPanel).toBeVisible()
        expect(commandPanel.errorMessages).not.toBeVisible()

    describe "when the command contains an escaped character", ->
      it "executes the command with the escaped character (instead of as a backslash followed by the character)", ->
        rootView.trigger 'command-panel:toggle'

        editSession = rootView.open(require.resolve 'fixtures/sample-with-tabs.coffee')
        commandPanel.miniEditor.setText "/\\tsell"
        commandPanel.miniEditor.hiddenInput.trigger keydownEvent('enter')
        expect(editSession.getSelectedBufferRange()).toEqual [[3,1],[3,6]]

  describe "when move-up and move-down are triggerred on the editor", ->
    it "navigates forward and backward through the command history", ->
      commandPanel.execute 's/war/peace/g'
      commandPanel.execute 's/twinkies/wheatgrass/g'

      rootView.trigger 'command-panel:toggle'

      commandPanel.miniEditor.trigger 'core:move-up'
      expect(commandPanel.miniEditor.getText()).toBe 's/twinkies/wheatgrass/g'
      commandPanel.miniEditor.trigger 'core:move-up'
      expect(commandPanel.miniEditor.getText()).toBe 's/war/peace/g'
      commandPanel.miniEditor.trigger 'core:move-up'
      expect(commandPanel.miniEditor.getText()).toBe 's/war/peace/g'
      commandPanel.miniEditor.trigger 'core:move-down'
      expect(commandPanel.miniEditor.getText()).toBe 's/twinkies/wheatgrass/g'
      commandPanel.miniEditor.trigger 'core:move-down'
      expect(commandPanel.miniEditor.getText()).toBe ''

  describe "when the preview list is focused with search operations", ->
    previewList = null

    beforeEach ->
      previewList = commandPanel.previewList
      rootView.trigger 'command-panel:toggle'
      waitsForPromise -> commandPanel.execute('X x/sort/')

    it "displays the number of files and operations", ->
      rootView.attachToDom()
      expect(commandPanel.previewCount.text()).toBe '22 matches in 5 files'

    describe "when move-down and move-up are triggered on the preview list", ->
      it "selects the next/previous operation (if there is one), and scrolls the list if needed", ->
        rootView.attachToDom()
        expect(previewList.find('li.operation:eq(0)')).toHaveClass 'selected'
        expect(previewList.getSelectedOperation()).toBe previewList.getOperations()[0]

        previewList.trigger 'core:move-down'
        expect(previewList.find('li.operation:eq(1)')).toHaveClass 'selected'
        expect(previewList.getSelectedOperation()).toBe previewList.getOperations()[1]

        previewList.trigger 'core:move-down'
        expect(previewList.find('li.operation:eq(2)')).toHaveClass 'selected'
        expect(previewList.getSelectedOperation()).toBe previewList.getOperations()[2]

        previewList.trigger 'core:move-up'
        expect(previewList.find('li.operation:eq(1)')).toHaveClass 'selected'
        expect(previewList.getSelectedOperation()).toBe previewList.getOperations()[1]

        _.times previewList.getOperations().length + previewList.getPathCount(), -> previewList.trigger 'core:move-down'

        expect(previewList.find("li.operation:last")).toHaveClass 'selected'
        expect(previewList.getSelectedOperation()).toBe _.last(previewList.getOperations())

        expect(previewList.scrollBottom()).toBeCloseTo previewList.prop('scrollHeight'), -1

        _.times previewList.getOperations().length + previewList.getPathCount(), -> previewList.trigger 'core:move-up'
        expect(previewList.scrollTop()).toBe 0

      it "doesn't bubble up the event and the command panel text doesn't change", ->
        rootView.attachToDom()
        commandPanel.miniEditor.setText "command"
        previewList.focus()
        previewList.trigger 'core:move-down'
        expect(previewList.find('li.operation:eq(1)')).toHaveClass 'selected'
        expect(commandPanel.miniEditor.getText()).toBe 'command'
        previewList.trigger 'core:move-up'
        expect(previewList.find('li.operation:eq(0)')).toHaveClass 'selected'
        expect(commandPanel.miniEditor.getText()).toBe 'command'

      it "doesn't select collapsed operations", ->
        rootView.attachToDom()
        previewList.trigger 'command-panel:collapse-result'
        expect(previewList.find('li.path:eq(0)')).toHaveClass 'selected'
        previewList.trigger 'core:move-down'
        expect(previewList.find('li.path:eq(1)')).toHaveClass 'selected'
        previewList.trigger 'core:move-up'
        expect(previewList.find('li.path:eq(0)')).toHaveClass 'selected'

    describe "when move-to-top and move-to-bottom are triggered on the preview list", ->
      it "selects the first path or last operation", ->
        rootView.attachToDom()
        expect(previewList.getOperations().length).toBeGreaterThan 0
        expect(previewList.find('li.operation:eq(0)')).toHaveClass 'selected'
        expect(previewList.getSelectedOperation()).toBe previewList.getOperations()[0]

        previewList.trigger 'core:move-to-bottom'
        expect(previewList.find('li.operation:last')).toHaveClass 'selected'
        expect(previewList.getSelectedOperation()).toBe _.last(previewList.getOperations())

        previewList.trigger 'core:move-to-top'
        expect(previewList.find('li.path:eq(0)')).toHaveClass 'selected'
        expect(previewList.getSelectedOperation()).toBeUndefined()

    describe "when core:confirm is triggered on the preview list", ->
      it "opens the operation's buffer, selects and scrolls to the search result, and refocuses the preview list", ->
        rootView.height(200)
        rootView.attachToDom()

        waitsForPromise -> commandPanel.execute('X x/apply/') # use apply because it is at the end of the file
        runs ->
          spyOn(previewList, 'focus')
          executeHandler = jasmine.createSpy('executeHandler')
          commandPanel.on 'core:confirm', executeHandler

          _.times 4, -> previewList.trigger 'core:move-down'
          operation = previewList.getSelectedOperation()

          previewList.trigger 'core:confirm'

          editSession = rootView.getActivePaneItem()
          expect(editSession.buffer.getPath()).toBe project.resolve(operation.getPath())
          expect(editSession.getSelectedBufferRange()).toEqual operation.getBufferRange()
          expect(editSession.getSelectedBufferRange()).toEqual operation.getBufferRange()
          expect(rootView.getActiveView().isScreenRowVisible(editSession.getCursorScreenRow())).toBeTruthy()
          expect(previewList.focus).toHaveBeenCalled()

          expect(executeHandler).not.toHaveBeenCalled()

      it "toggles the expansion state when a path is selected", ->
        rootView.attachToDom()
        previewList.trigger 'core:move-to-top'
        expect(previewList.find('li.path:first')).toHaveClass 'selected'
        expect(previewList.find('li.path:first')).not.toHaveClass 'is-collapsed'
        previewList.trigger 'core:confirm'
        expect(previewList.find('li.path:first')).toHaveClass 'selected'
        expect(previewList.find('li.path:first')).toHaveClass 'is-collapsed'

    describe "when an operation in the preview list is clicked", ->
      it "opens the operation's buffer, selects the search result, and refocuses the preview list", ->
        spyOn(previewList, 'focus')
        operation = previewList.getOperations()[4]

        previewList.find('li.operation:eq(4) span').mousedown()

        expect(previewList.getSelectedOperation()).toBe operation
        editSession = rootView.getActivePaneItem()
        expect(editSession.buffer.getPath()).toBe project.resolve(operation.getPath())
        expect(editSession.getSelectedBufferRange()).toEqual operation.getBufferRange()
        expect(previewList.focus).toHaveBeenCalled()

    describe "when a path in the preview list is clicked", ->
      it "shows and hides the matches for that path", ->
        rootView.attachToDom()
        expect(previewList.find('li.path:first-child ul.matches')).toBeVisible()
        previewList.find('li.path:first-child .path-details').mousedown()
        expect(previewList.find('li.path:first-child ul.matches')).toBeHidden()

        previewList.find('li.path:first-child .path-details').mousedown()
        expect(previewList.find('li.path:first-child ul.matches')).toBeVisible()

    describe "when command-panel:collapse-result and command-panel:expand-result are triggered", ->
      it "collapses and selects the path, and then expands the selected path", ->
        rootView.attachToDom()
        expect(previewList.find('li.path:first-child ul.matches')).toBeVisible()
        previewList.trigger 'command-panel:collapse-result'
        expect(previewList.find('li.path:first-child ul.matches')).toBeHidden()
        expect(previewList.find('li.path:first-child')).toHaveClass 'selected'
        previewList.trigger 'command-panel:expand-result'
        expect(previewList.find('li.path:first-child ul.matches')).toBeVisible()
        expect(previewList.find('li.path:first-child')).toHaveClass 'selected'

  describe "when the active pane item is not an EditSession", ->
    it "doesn't throw an error (regression)", ->
      rootView.open('binary-file.png')
      rootView.trigger 'command-panel:toggle'

      executePromise = null
      expect(-> executePromise = commandPanel.execute('Xx/sort/')).not.toThrow()

      waitsForPromise -> executePromise
