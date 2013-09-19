{fs} = require 'atom'
installer = require '../src/command-installer'

describe "install(commandPath, callback)", ->
  directory = '/tmp/install-atom-command/atom'
  commandPath = "#{directory}/source"
  destinationPath = "#{directory}/bin/source"

  beforeEach ->
    spyOn(installer, 'findInstallDirectory').andCallFake (callback) ->
      callback(directory)

    fs.remove(directory) if fs.exists(directory)

  it "symlinks the command and makes it executable", ->
    fs.writeSync(commandPath, 'test')
    expect(fs.isFileSync(commandPath)).toBeTruthy()
    expect(fs.isExecutableSync(commandPath)).toBeFalsy()
    expect(fs.isFileSync(destinationPath)).toBeFalsy()

    installDone = false
    installError = null
    installer.install commandPath, (error) ->
      installDone = true
      installError = error

    waitsFor -> installDone

    runs ->
      expect(installError).toBeNull()
      expect(fs.isFileSync(destinationPath)).toBeTruthy()
      expect(fs.realpathSync(destinationPath)).toBe fs.realpathSync(commandPath)
      expect(fs.isExecutableSync(destinationPath)).toBeTruthy()
