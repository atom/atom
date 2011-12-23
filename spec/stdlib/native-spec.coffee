Native = require 'native'

describe "Native", ->
  nativeModule = null

  beforeEach ->
    nativeModule = new Native

  fdescribe "addMenuItem(path, keyBinding)", ->
    mainMenuItems = null

    beforeEach ->
      mainMenuItems = OSX.NSApp.mainMenu.itemArray

    it "adds the item at the path terminus to the main menu, adding submenus as needed", ->
      initialMenuCount = mainMenuItems.length

      nativeModule.addMenuItem('Submenu > Item')

      expect(mainMenuItems.length).toBe initialMenuCount + 1

