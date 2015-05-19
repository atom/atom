ChildProcess = require 'child_process'
{EventEmitter} = require 'events'
fs = require 'fs-plus'
path = require 'path'
temp = require 'temp'
SquirrelUpdate = require '../src/browser/squirrel-update'

describe "Windows squirrel updates", ->
  tempHomeDirectory = null

  beforeEach ->
    # Prevent the actually home directory from being manipulated
    tempHomeDirectory = temp.mkdirSync('atom-temp-home-')
    spyOn(fs, 'getHomeDirectory').andReturn(tempHomeDirectory)

    # Prevent any commands from actually running and affecting the host
    originalSpawn = ChildProcess.spawn
    spyOn(ChildProcess, 'spawn').andCallFake (command, args) ->
      if path.basename(command) is 'Update.exe' and args?[0] is '--createShortcut'
        fs.writeFileSync(path.join(tempHomeDirectory, 'Desktop', 'Atom.lnk'), '')

      # Just spawn something that won't actually modify the host
      if process.platform is 'win32'
        originalSpawn('dir')
      else
        originalSpawn('ls')

  it "ignores errors spawning Squirrel", ->
    jasmine.unspy(ChildProcess, 'spawn')
    spyOn(ChildProcess, 'spawn').andCallFake -> throw new Error("EBUSY")

    app = quit: jasmine.createSpy('quit')
    expect(SquirrelUpdate.handleStartupEvent(app, '--squirrel-install')).toBe true

    waitsFor ->
      app.quit.callCount is 1

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

      expect(ChildProcess.spawn.callCount).toBe 0
      app.emit('will-quit')
      expect(ChildProcess.spawn.callCount).toBe 1
      expect(path.basename(ChildProcess.spawn.argsForCall[0][0])).toBe 'atom.cmd'
