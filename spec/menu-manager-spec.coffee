path = require 'path'
MenuManager = require '../src/menu-manager'

describe "MenuManager", ->
  menu = null

  beforeEach ->
    menu = new MenuManager({keymapManager: atom.keymaps, packageManager: atom.packages})
    menu.initialize({resourcePath: atom.getLoadSettings().resourcePath})

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

  describe "::update()", ->
    originalPlatform = process.platform
    afterEach -> Object.defineProperty process, 'platform', value: originalPlatform

    it "sends the current menu template and associated key bindings to the browser process", ->
      spyOn(menu, 'sendToBrowserProcess')
      menu.add [{label: "A", submenu: [{label: "B", command: "b"}]}]
      atom.keymaps.add 'test', 'atom-workspace': 'ctrl-b': 'b'
      menu.update()

      waits 1

      runs -> expect(menu.sendToBrowserProcess.argsForCall[0][1]['b']).toEqual ['ctrl-b']

    it "omits key bindings that are mapped to unset! in any context", ->
      # it would be nice to be smarter about omitting, but that would require a much
      # more dynamic interaction between the currently focused element and the menu
      spyOn(menu, 'sendToBrowserProcess')
      menu.add [{label: "A", submenu: [{label: "B", command: "b"}]}]
      atom.keymaps.add 'test', 'atom-workspace': 'ctrl-b': 'b'
      atom.keymaps.add 'test', 'atom-text-editor': 'ctrl-b': 'unset!'

      waits 50

      runs -> expect(menu.sendToBrowserProcess.argsForCall[0][1]['b']).toBeUndefined()

    it "omits key bindings that could conflict with AltGraph characters on macOS", ->
      Object.defineProperty process, 'platform', value: 'darwin'
      spyOn(menu, 'sendToBrowserProcess')
      menu.add [{label: "A", submenu: [
        {label: "B", command: "b"},
        {label: "C", command: "c"}
        {label: "D", command: "d"}
      ]}]

      atom.keymaps.add 'test', 'atom-workspace':
        'alt-b': 'b'
        'alt-shift-C': 'c'
        'alt-cmd-d': 'd'

      waits 50

      runs ->
        expect(menu.sendToBrowserProcess.argsForCall[0][1]['b']).toBeUndefined()
        expect(menu.sendToBrowserProcess.argsForCall[0][1]['c']).toBeUndefined()
        expect(menu.sendToBrowserProcess.argsForCall[0][1]['d']).toEqual(['alt-cmd-d'])

    it "omits key bindings that could conflict with AltGraph characters on Windows", ->
      Object.defineProperty process, 'platform', value: 'win32'
      spyOn(menu, 'sendToBrowserProcess')
      menu.add [{label: "A", submenu: [
        {label: "B", command: "b"},
        {label: "C", command: "c"}
        {label: "D", command: "d"}
      ]}]

      atom.keymaps.add 'test', 'atom-workspace':
        'ctrl-alt-b': 'b'
        'ctrl-alt-shift-C': 'c'
        'ctrl-alt-cmd-d': 'd'

      waits 50

      runs ->
        expect(menu.sendToBrowserProcess.argsForCall[0][1]['b']).toBeUndefined()
        expect(menu.sendToBrowserProcess.argsForCall[0][1]['c']).toBeUndefined()
        expect(menu.sendToBrowserProcess.argsForCall[0][1]['d']).toEqual(['ctrl-alt-cmd-d'])

  it "updates the application menu when a keymap is reloaded", ->
    spyOn(menu, 'update')
    keymapPath = path.join(__dirname, 'fixtures', 'packages', 'package-with-keymaps', 'keymaps', 'keymap-1.cson')
    atom.keymaps.reloadKeymap(keymapPath)
    expect(menu.update).toHaveBeenCalled()
