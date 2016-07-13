{EventEmitter} = require 'events'
fs = require 'fs-plus'
path = require 'path'
temp = require 'temp'
SquirrelUpdate = require '../src/main-process/squirrel-update'
Spawner = require '../src/main-process/spawner'
WinPowerShell = require '../src/main-process/win-powershell'
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
    for own property of WinShell
      for own method of property
        spyOn(property, method).andCallFake (callback) ->
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

  describe "Desktop shortcut", ->
    desktopShortcutPath = '/non/existing/path'

    beforeEach ->
      desktopShortcutPath = path.join(tempHomeDirectory, 'Desktop', 'Atom.lnk')

      jasmine.unspy(Spawner, 'spawn')
      spyOn(Spawner, 'spawn').andCallFake (command, args, callback) ->
        if path.basename(command) is 'Update.exe' and args?[0] is '--createShortcut'
          fs.writeFileSync(desktopShortcutPath, '')
        else
          # simply ignore other commands

        invokeCallback callback

    it "does not exist before install", ->
      expect(fs.existsSync(desktopShortcutPath)).toBe false

    describe "on install", ->
      beforeEach ->
        app = quit: jasmine.createSpy('quit')
        SquirrelUpdate.handleStartupEvent(app, '--squirrel-install')
        waitsFor ->
          app.quit.callCount is 1

      it "creates desktop shortcut", ->
        expect(fs.existsSync(desktopShortcutPath)).toBe true

      describe "when shortcut is deleted and then app is updated", ->
        beforeEach ->
          fs.removeSync(desktopShortcutPath)
          expect(fs.existsSync(desktopShortcutPath)).toBe false

          app = quit: jasmine.createSpy('quit')
          SquirrelUpdate.handleStartupEvent(app, '--squirrel-updated')
          waitsFor ->
            app.quit.callCount is 1

        it "does not recreate shortcut", ->
          expect(fs.existsSync(desktopShortcutPath)).toBe false

      describe "when shortcut is kept and app is updated", ->
        beforeEach ->
          app = quit: jasmine.createSpy('quit')
          SquirrelUpdate.handleStartupEvent(app, '--squirrel-updated')
          waitsFor ->
            app.quit.callCount is 1

        it "still has desktop shortcut", ->
          expect(fs.existsSync(desktopShortcutPath)).toBe true

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
