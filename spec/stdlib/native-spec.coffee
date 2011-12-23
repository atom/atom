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

      nativeModule.addMenuItem('Submenu > Item')

      expect(mainMenu.itemArray.length).toBe initialMenuCount + 1


