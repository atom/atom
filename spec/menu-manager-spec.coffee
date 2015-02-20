MenuManager = require '../src/menu-manager'

describe "MenuManager", ->
  menu = null

  beforeEach ->
    menu = new MenuManager(resourcePath: atom.getLoadSettings().resourcePath)

  describe "::add(items)", ->
    it "can add new menus that can be removed with the returned disposable", ->
      disposable = menu.add [{label: "A", submenu: [{label: "B", command: "b"}]}]
      expect(menu.template).toEqual [{label: "A", submenu: [{label: "B", command: "b"}]}]
      disposable.dispose()
      expect(menu.template).toEqual []

    it "can add submenu items to existing menus that can be removed with the returned disposable", ->
      disposable1 = menu.add [{label: "A", submenu: [{label: "B", command: "b"}]}]
      disposable2 = menu.add [{label: "A", submenu: [{label: "C", submenu: [{label: "D", command: 'd'}]}]}]
      disposable3 = menu.add [{label: "A", submenu: [{label: "C", submenu: [{label: "E", command: 'e'}]}]}]

      expect(menu.template).toEqual [{
        label: "A",
        submenu: [
          {label: "B", command: "b"},
          {label: "C", submenu: [{label: 'D', command: 'd'}, {label: 'E', command: 'e'}]}
        ]
      }]

      disposable3.dispose()
      expect(menu.template).toEqual [{
        label: "A",
        submenu: [
          {label: "B", command: "b"},
          {label: "C", submenu: [{label: 'D', command: 'd'}]}
        ]
      }]

      disposable2.dispose()
      expect(menu.template).toEqual [{label: "A", submenu: [{label: "B", command: "b"}]}]

      disposable1.dispose()
      expect(menu.template).toEqual []

    it "does not add duplicate labels to the same menu", ->
      originalItemCount = menu.template.length
      menu.add [{label: "A", submenu: [{label: "B", command: "b"}]}]
      menu.add [{label: "A", submenu: [{label: "B", command: "b"}]}]
      expect(menu.template[originalItemCount]).toEqual {label: "A", submenu: [{label: "B", command: "b"}]}
