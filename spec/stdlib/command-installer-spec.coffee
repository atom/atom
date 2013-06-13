fs = require 'fs'
fsUtils = require 'fs-utils'
installer = require 'command-installer'

describe "install(commandPath, callback)", ->
  directory = '/tmp/install-atom-command/atom'
  commandPath = "#{directory}/source"
  destinationPath = "#{directory}/bin/source"

  beforeEach ->
    spyOn(installer, 'findInstallDirectory').andCallFake (callback) ->
      callback(directory)

    fsUtils.remove(directory) if fsUtils.exists(directory)

  it "symlinks the command and makes it executable", ->
    fsUtils.writeSync(commandPath, 'test')
    expect(fsUtils.isFileSync(commandPath)).toBeTruthy()
    expect(fsUtils.isExecutableSync(commandPath)).toBeFalsy()
    expect(fsUtils.isFileSync(destinationPath)).toBeFalsy()

    installDone = false
    installError = null
    installer.install commandPath, (error) ->
      installDone = true
      installError = error

    waitsFor -> installDone

    runs ->
      expect(installError).toBeNull()
      expect(fsUtils.isFileSync(destinationPath)).toBeTruthy()
      expect(fs.realpathSync(destinationPath)).toBe fs.realpathSync(commandPath)
      expect(fsUtils.isExecutableSync(destinationPath)).toBeTruthy()
