Native = require 'native'

describe "Native", ->
  nativeModule = null

  beforeEach ->
    nativeModule = new Native

  describe "addMenuItem(path, keyPattern)", ->
    mainMenu = null
    mainMenuItems = null

    beforeEach ->
      mainMenu = OSX.NSApp.mainMenu
      mainMenuItems = mainMenu.itemArray

    it "adds the item at the path terminus to the main menu, adding submenus as needed", ->
      initialMenuCount = mainMenu.itemArray.length

      nativeModule.addMenuItem('Submenu 1 > Item 1')

      expect(mainMenu.itemArray.length).toBe initialMenuCount + 1
      submenu1 = mainMenu.itemWithTitle('Submenu 1').submenu
      item1 = submenu1.itemWithTitle('Item 1')
      expect(item1).toBeDefined()

      nativeModule.addMenuItem('Submenu 1 > Item 2')

      expect(mainMenu.itemArray.length).toBe initialMenuCount + 1
      expect(submenu1.itemArray.length).toBe 2
      item1 = submenu1.itemWithTitle('Item 2')
      expect(item1).toBeDefined()

      nativeModule.addMenuItem('Submenu 2 > Item 1')

      expect(mainMenu.itemArray.length).toBe initialMenuCount + 2
      expect(submenu1.itemArray.length).toBe 2
      submenu1 = mainMenu.itemWithTitle('Submenu 2').submenu
      item1 = submenu1.itemWithTitle('Item 1')
      expect(item1).toBeDefined()

    xit "adds a key equivalent to menu item when one is given", ->
      nativeModule.addMenuItem('Submenu 1 > Item 1', "meta-r")

      submenu1 = mainMenu.itemWithTitle('Submenu 1').submenu
      item1 = submenu1.itemWithTitle('Item 1')

      expect(item1.keyEquivalent.valueOf()).toBe 'r'
      expect(item1.keyEquivalentModifierMask.valueOf()).toBe OSX.NSCommandKeyMask

    it "does not add a key equivalent to menu item when no pattern is given", ->
      nativeModule.addMenuItem('Submenu 2 > Item 2')
      submenu2 = mainMenu.itemWithTitle('Submenu 2').submenu
      item2 = submenu2.itemWithTitle('Item 2')

      expect(item2.keyEquivalent.valueOf()).toBe 0
      expect(item2.keyEquivalentModifierMask).toBe 0

    it "does not add the same item twice", ->
      nativeModule.addMenuItem('Submenu > Item')
      expect(mainMenu.itemWithTitle('Submenu').submenu.itemArray.length).toBe(1)
      nativeModule.addMenuItem('Submenu > Item')
      expect(mainMenu.itemWithTitle('Submenu').submenu.itemArray.length).toBe(1)

