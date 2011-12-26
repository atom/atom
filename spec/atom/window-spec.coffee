require 'window'
$ = require 'jquery'

describe "Window", ->
  describe "keybindings", ->
    beforeEach ->
      window.startup()

    afterEach ->
      window.shutdown()

    describe 'bindKey(pattern, action)', ->
      it 'maps keypresses that match a pattern to an action', ->
        action1 = jasmine.createSpy 'action1'
        action2 = jasmine.createSpy 'action2'

        window.bindKey 'meta+1', action1
        window.bindKey 'meta+2', action2

        window.keydown 'meta+1'
        expect(action1).toHaveBeenCalled()
        expect(action2).not.toHaveBeenCalled()
        action1.reset()

        window.keydown 'meta+2'
        expect(action1).not.toHaveBeenCalled()
        expect(action2).toHaveBeenCalled()
        action2.reset()

        window.keydown 'meta+3'
        expect(action1).not.toHaveBeenCalled()
        expect(action2).not.toHaveBeenCalled()

    describe 'keyEventMatchesPattern', ->
      it 'returns true if the modifiers and letter in the pattern match the key event', ->
        expectMatch = (pattern) ->
          expect(window.keyEventMatchesPattern(window.createKeyEvent(pattern), pattern)).toBeTruthy()

        expectNoMatch = (eventPattern, patternToTest) ->
          event = window.createKeyEvent(eventPattern)
          expect(window.keyEventMatchesPattern(event, patternToTest)).toBeFalsy()

        expectMatch 'meta+a'
        expectMatch 'meta+1'
        expectMatch 'alt+1'
        expectMatch 'ctrl+1'
        expectMatch 'shift+1'
        expectMatch 'shift+a'
        expectMatch 'meta+alt+1'
        expectMatch 'meta+alt+ctrl+1'
        expectMatch 'meta+alt+ctrl+shift+1'

        expectNoMatch 'meta+alt+ctrl+shift+1', 'meta+1'
        expectNoMatch 'meta+1', 'meta+alt+1'
        expectNoMatch 'meta+a', 'meta+b'
        expectNoMatch 'meta+a', 'meta+b'
        expectNoMatch 'meta+1', 'alt+1'

    describe "bindMenuItem(path, action)", ->
      it "causes the given menu item to be added to the menu when the window is focused and removed when it is blurred", ->
        addedPaths = []
        spyOn(atom.native, 'addMenuItem').andCallFake (path) -> addedPaths.push(path)

        window.bindMenuItem 'Submenu 1 > Item 1'
        window.bindMenuItem 'Submenu 1 > Item 2'
        window.bindMenuItem 'Submenu 2 > Item 1'

        expect(atom.native.addMenuItem).not.toHaveBeenCalled()

        $(document).focus()

        expect(atom.native.addMenuItem).toHaveBeenCalled()
        expect(addedPaths).toContain('Submenu 1 > Item 1')
        expect(addedPaths).toContain('Submenu 1 > Item 2')
        expect(addedPaths).toContain('Submenu 2 > Item 1')

        spyOn(atom.native, 'resetMainMenu')

        $(document).blur()

        expect(atom.native.resetMainMenu).toHaveBeenCalled()

      it "causes the given action to be invoked when the menu item is selected", ->
        handler = jasmine.createSpy('menuItemHandler')
        window.bindMenuItem 'Submenu > Item', handler
        $(document).focus()

        OSX.NSApp.mainMenu.itemWithTitle('Submenu').submenu.performActionForItemAtIndex(0)

        expect(handler).toHaveBeenCalled()

    describe "menu items", ->
      it "adds a Save item to the main menu after startup", ->
        expect(OSX.NSApp.mainMenu.itemWithTitle('File').submenu.itemWithTitle('Save')).not.toBeNull()

    describe 'meta+s', ->
      it 'saves the buffer', ->
        spyOn(window.editor, 'save')
        window.keydown 'meta+s'
        expect(window.editor.save).toHaveBeenCalled()
