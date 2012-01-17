$ = require 'jquery'
fs = require 'fs'

describe "Window", ->
  describe "keybindings", ->
    beforeEach ->
      window.startup()

    afterEach ->
      window.shutdown()

    describe ".close()", ->
      it "is triggered by the 'close' event", ->
        spyOn window, 'close'
        $(window).trigger 'close'
        expect(window.close).toHaveBeenCalled()

    describe "requireStylesheet(path)", ->
      it "synchronously loads the stylesheet at the given path and installs a style tag for it in the head", ->
        $('head style').remove()
        expect($('head style').length).toBe 0
        requireStylesheet('atom.css')
        expect($('head style').length).toBe 1

        styleElt = $('head style')

        fullPath = require.resolve('atom.css')
        expect(styleElt.attr('path')).toBe fullPath
        expect(styleElt.text()).toBe fs.read(fullPath)

        requireStylesheet('atom.css')
        expect($('head style').length).toBe 1


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

