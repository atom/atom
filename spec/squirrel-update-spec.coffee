{EventEmitter} = require 'events'
fs = require 'fs-plus'
path = require 'path'
temp = require 'temp'
Spawner = require '../src/browser/spawner'
WinRegistry = require '../src/browser/win-registry'
SquirrelUpdate = require '../src/browser/squirrel-update'

describe "Windows squirrel updates", ->
  tempHomeDirectory = null

  beforeEach ->
    # Prevent the actually home directory from being manipulated
    tempHomeDirectory = temp.mkdirSync('atom-temp-home-')
    spyOn(fs, 'getHomeDirectory').andReturn(tempHomeDirectory)

    # Prevent any spawned command from actually running and affecting the host
    originalSpawn = Spawner.spawn
    spyOn(Spawner, 'spawn').andCallFake (command, args, callback) ->
      if path.basename(command) is 'Update.exe' and args?[0] is '--createShortcut'
        fs.writeFileSync(path.join(tempHomeDirectory, 'Desktop', 'Atom.lnk'), '')

      # Just spawn something that won't actually modify the host
      if process.platform is 'win32'
        originalSpawn('dir')
      else
        originalSpawn('ls')

      # Then run passed callback
      invokeCallback callback

    # Prevent any actual change to Windows registry, just run passed callback
    for key, value of WinRegistry
      spyOn(WinRegistry, key).andCallFake (callback) ->
        invokeCallback callback

  it "quits the app on all squirrel events", ->
    app = quit: jasmine.createSpy('quit')

    expect(SquirrelUpdate.handleStartupEvent(app, '--squirrel-install')).toBe true

    waitsFor ->
      app.quit.callCount is 1

    runs ->
      app.quit.reset()
      expect(SquirrelUpdate.handleStartupEvent(app, '--squirrel-updated')).toBe true

    waitsFor ->
      app.quit.callCount is 1

    runs ->
      app.quit.reset()
      expect(SquirrelUpdate.handleStartupEvent(app, '--squirrel-uninstall')).toBe true

    waitsFor ->
      app.quit.callCount is 1

    runs ->
      app.quit.reset()
      expect(SquirrelUpdate.handleStartupEvent(app, '--squirrel-obsolete')).toBe true

    waitsFor ->
      app.quit.callCount is 1

    runs ->
      expect(SquirrelUpdate.handleStartupEvent(app, '--not-squirrel')).toBe false

  it "keeps the desktop shortcut deleted on updates if it was previously deleted after install", ->
    desktopShortcutPath = path.join(tempHomeDirectory, 'Desktop', 'Atom.lnk')
    expect(fs.existsSync(desktopShortcutPath)).toBe false

    app = quit: jasmine.createSpy('quit')
    expect(SquirrelUpdate.handleStartupEvent(app, '--squirrel-install')).toBe true

    waitsFor ->
      app.quit.callCount is 1

    runs ->
      app.quit.reset()
      expect(fs.existsSync(desktopShortcutPath)).toBe true
      fs.removeSync(desktopShortcutPath)
      expect(fs.existsSync(desktopShortcutPath)).toBe false
      expect(SquirrelUpdate.handleStartupEvent(app, '--squirrel-updated')).toBe true

    waitsFor ->
      app.quit.callCount is 1

    runs ->
      expect(fs.existsSync(desktopShortcutPath)).toBe false

  describe ".restartAtom", ->
    it "quits the app and spawns a new one", ->
      app = new EventEmitter()
      app.quit = jasmine.createSpy('quit')

      SquirrelUpdate.restartAtom(app)
      expect(app.quit.callCount).toBe 1

      expect(Spawner.spawn.callCount).toBe 0
      app.emit('will-quit')
      expect(Spawner.spawn.callCount).toBe 1
      expect(path.basename(Spawner.spawn.argsForCall[0][0])).toBe 'atom.cmd'

  describe "Shell context menu", ->
    contextMenuState =
      unknown: 'unknown'
      installed: 'installed'
      notInstalled: 'notInstalled'
      
    contextMenu = contextMenuState.unknown
    
    beforeEach ->
      # Prevent messing with actual Atom settings on machine
      dotAtomPath = temp.path('dot-atom-dir')
      atom.config.configDirPath = dotAtomPath
      atom.config.configFilePath = path.join(atom.config.configDirPath, "atom.config.cson")
      
      jasmine.unspy(WinRegistry, 'installContextMenu')
      spyOn(WinRegistry, 'installContextMenu').andCallFake (callback) ->
        contextMenu = contextMenuState.installed
        invokeCallback callback
      
      jasmine.unspy(WinRegistry, 'uninstallContextMenu')
      spyOn(WinRegistry, 'uninstallContextMenu').andCallFake (callback) ->
        contextMenu = contextMenuState.notInstalled
        invokeCallback callback
      
      waitForInstall()
        
    it "is added on install", ->
      expect(contextMenu).toBe contextMenuState.installed
    
    describe "when app is updated", ->
      beforeEach ->
        waitForUpdated()

      it "remains", ->
        expect(contextMenu).toBe contextMenuState.installed
    
    describe "when menu is removed and then app is updated", ->
      beforeEach ->
        atom.config.set('core.showAtomInShellContextMenu', false)
        contextMenu = contextMenuState.notInstalled  # keep dummy test state in sync
        
        waitForUpdated()

      it "is not readded", ->
        expect(contextMenu).toBe contextMenuState.notInstalled
   
    # Wait for install to complete
    waitForInstall = ->
      app = quit: jasmine.createSpy('quit')
      SquirrelUpdate.handleStartupEvent(app, '--squirrel-install')
      waitsFor ->
        app.quit.callCount is 1

    # Wait for update to complete
    waitForUpdated = ->
      app = quit: jasmine.createSpy('quit')
      SquirrelUpdate.handleStartupEvent(app, '--squirrel-updated')
      waitsFor ->
        app.quit.callCount is 1

# Just run passed callback as Spawner:spawn would do
invokeCallback = (callback) ->
  error = null
  stdout = ''
  
  callback?(error, stdout)
