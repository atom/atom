{EventEmitter} = require 'events'
electron = require 'electron'
fs = require 'fs-plus'
path = require 'path'
temp = require('temp').track()

electron.app = {
  getName: -> 'Atom',
  getVersion: -> '1.0.0',
  getPath: -> '/tmp/atom.exe'
}

SquirrelUpdate = require '../src/main-process/squirrel-update'
Spawner = require '../src/main-process/spawner'
WinShell = require '../src/main-process/win-shell'

# Run passed callback as Spawner.spawn() would do
invokeCallback = (callback) ->
  error = null
  stdout = ''
  callback?(error, stdout)

describe "Windows Squirrel Update", ->
  tempHomeDirectory = null

  beforeEach ->
    # Prevent the actual home directory from being manipulated
    tempHomeDirectory = temp.mkdirSync('atom-temp-home-')
    spyOn(fs, 'getHomeDirectory').andReturn(tempHomeDirectory)

    # Prevent any spawned command from actually running and affecting the host
    spyOn(Spawner, 'spawn').andCallFake (command, args, callback) ->
      # do nothing on command, just run passed callback
      invokeCallback callback

    # Prevent any actual change to Windows Shell
    class FakeShellOption
      isRegistered: (callback) -> callback true
      register: (callback) -> callback null
      deregister: (callback) -> callback null, true
      update: (callback) -> callback null
    WinShell.fileHandler = new FakeShellOption()
    WinShell.fileContextMenu = new FakeShellOption()
    WinShell.folderContextMenu = new FakeShellOption()
    WinShell.folderBackgroundContextMenu = new FakeShellOption()
    electron.app.quit = jasmine.createSpy('quit')

  afterEach ->
    electron.app.quit.reset()
    try
      temp.cleanupSync()

  it "quits the app on all squirrel events", ->
    expect(SquirrelUpdate.handleStartupEvent('--squirrel-install')).toBe true

    waitsFor ->
      electron.app.quit.callCount is 1

    runs ->
      electron.app.quit.reset()
      expect(SquirrelUpdate.handleStartupEvent('--squirrel-updated')).toBe true

    waitsFor ->
      electron.app.quit.callCount is 1

    runs ->
      electron.app.quit.reset()
      expect(SquirrelUpdate.handleStartupEvent( '--squirrel-uninstall')).toBe true

    waitsFor ->
      electron.app.quit.callCount is 1

    runs ->
      electron.app.quit.reset()
      expect(SquirrelUpdate.handleStartupEvent('--squirrel-obsolete')).toBe true

    waitsFor ->
      electron.app.quit.callCount is 1

    runs ->
      expect(SquirrelUpdate.handleStartupEvent('--not-squirrel')).toBe false

  describe "Desktop shortcut", ->
    desktopShortcutPath = '/non/existing/path'

    beforeEach ->
      desktopShortcutPath = path.join(tempHomeDirectory, 'Desktop', 'Atom.lnk')

      jasmine.unspy(Spawner, 'spawn')
      spyOn(Spawner, 'spawn').andCallFake (command, args, callback) ->
        if path.basename(command) is 'Update.exe' and args?[0] is '--createShortcut' and args?[3].match /Desktop/i
          fs.writeFileSync(desktopShortcutPath, '')
        else
          # simply ignore other commands

        invokeCallback callback

    it "does not exist before install", ->
      expect(fs.existsSync(desktopShortcutPath)).toBe false

    describe "on install", ->
      beforeEach ->
        SquirrelUpdate.handleStartupEvent('--squirrel-install')
        waitsFor ->
          electron.app.quit.callCount is 1

      it "creates desktop shortcut", ->
        expect(fs.existsSync(desktopShortcutPath)).toBe true

      describe "when shortcut is deleted and then app is updated", ->
        beforeEach ->
          fs.removeSync(desktopShortcutPath)
          expect(fs.existsSync(desktopShortcutPath)).toBe false

          SquirrelUpdate.handleStartupEvent('--squirrel-updated')
          waitsFor ->
            electron.app.quit.callCount is 2

        it "does not recreate shortcut", ->
          expect(fs.existsSync(desktopShortcutPath)).toBe false

      describe "when shortcut is kept and app is updated", ->
        beforeEach ->
          SquirrelUpdate.handleStartupEvent('--squirrel-updated')
          waitsFor ->
            electron.app.quit.callCount is 2

        it "still has desktop shortcut", ->
          expect(fs.existsSync(desktopShortcutPath)).toBe true
