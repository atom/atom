path = require 'path'
temp = require 'temp'
{CompositeDisposable} = require 'event-kit'
WinRegistry = require '../src/browser/win-registry'
WinContextMenuSettings = require '../src/win-context-menu-settings'

describe "WinContextMenuSettings", ->
  dotAtomPath = null

  beforeEach ->
    @disposables = new CompositeDisposable
    
    # Prevent messing with actual Atom settings on machine
    dotAtomPath = temp.path('dot-atom-dir')
    atom.config.configDirPath = dotAtomPath
    atom.config.configFilePath = path.join(atom.config.configDirPath, "atom.config.cson")

    # Prevent any actual change to Windows registry, just run passed callback
    for key, value of WinRegistry
      spyOn(WinRegistry, key).andCallFake (callback) ->
        error = null
        stdout = ''
        callback?(error, stdout)
        
    @disposables.add (new WinContextMenuSettings())

  afterEach ->
    @disposables.dispose
  
  describe "when setting changes from false to true", ->
    beforeEach ->
      jasmine.unspy(WinRegistry, 'installContextMenu')
      spyOn(WinRegistry, 'installContextMenu').andCallFake (callback) ->
        callback?

      atom.config.set("core.showAtomInShellContextMenu", false)
      atom.config.set("core.showAtomInShellContextMenu", true)

    it "asks to install context menu", ->
      expect(WinRegistry.installContextMenu.callCount).toBe 1

  describe "when setting changes from true to false", ->
    beforeEach ->
      jasmine.unspy(WinRegistry, 'uninstallContextMenu')
      spyOn(WinRegistry, 'uninstallContextMenu').andCallFake (callback) ->
        callback?

      atom.config.set("core.showAtomInShellContextMenu", true)
      atom.config.set("core.showAtomInShellContextMenu", false)

    it "asks to uninstall context menu", ->
      expect(WinRegistry.uninstallContextMenu.callCount).toBe 1
