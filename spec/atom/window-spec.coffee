require 'window'
$ = require 'jquery'

describe "Window", ->
  describe "keybindings", ->
    beforeEach ->
      window.startup()

    afterEach ->
      window.shutdown()

    describe "bindMenuItem(path, keyPattern, action)", ->
      it "causes the given menu item to be added to the menu when the window is focused and removed when it is blurred", ->
        addedPaths = []
        spyOn(atom.native, 'addMenuItem').andCallFake (path) -> addedPaths.push(path)

        window.bindMenuItem 'Submenu 1 > Item 1'
        window.bindMenuItem 'Submenu 1 > Item 2'
        window.bindMenuItem 'Submenu 2 > Item 1'

        expect(atom.native.addMenuItem).not.toHaveBeenCalled()

        $(window).focus()

        expect(atom.native.addMenuItem).toHaveBeenCalled()
        expect(addedPaths).toContain('Submenu 1 > Item 1')
        expect(addedPaths).toContain('Submenu 1 > Item 2')
        expect(addedPaths).toContain('Submenu 2 > Item 1')

        spyOn(atom.native, 'resetMainMenu')

        $(window).blur()

        expect(atom.native.resetMainMenu).toHaveBeenCalled()

      it "causes the given action to be invoked when the menu item is selected", ->
        handler = jasmine.createSpy('menuItemHandler')
        window.bindMenuItem 'Submenu > Item', null, handler
        $(window).focus()

        OSX.NSApp.mainMenu.itemWithTitle('Submenu').submenu.performActionForItemAtIndex(0)

        expect(handler).toHaveBeenCalled()

    describe "menu items", ->
      it "adds a Save item to the main menu after startup", ->
        expect(OSX.NSApp.mainMenu.itemWithTitle('File').submenu.itemWithTitle('Save')).not.toBeNull()

