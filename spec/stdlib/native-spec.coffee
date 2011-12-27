Native = require 'native'

describe "Native", ->
  nativeModule = null

  beforeEach ->
    nativeModule = new Native

  describe "addMenuItem(path, keyBinding)", ->
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

    it "does not add the same item twice", ->
      nativeModule.addMenuItem('Submenu > Item')
      expect(mainMenu.itemWithTitle('Submenu').submenu.itemArray.length).toBe(1)
      nativeModule.addMenuItem('Submenu > Item')
      expect(mainMenu.itemWithTitle('Submenu').submenu.itemArray.length).toBe(1)

