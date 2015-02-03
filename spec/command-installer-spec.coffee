path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
installer = require '../src/command-installer'

describe "install(commandPath, callback)", ->
  commandFilePath = temp.openSync("atom-command").path
  commandName = path.basename(commandFilePath)
  installationPath = temp.mkdirSync("atom-bin")
  installationFilePath = path.join(installationPath, commandName)

  beforeEach ->
    fs.chmodSync(commandFilePath, '755')
    spyOn(installer, 'getInstallDirectory').and.returnValue(installationPath)

  describe "on #darwin", ->
    it "symlinks the command and makes it executable", (done) ->
      expect(fs.isFileSync(commandFilePath)).toBeTruthy()
      expect(fs.isFileSync(installationFilePath)).toBeFalsy()

      installDone = false
      installError = null
      installer.createSymlink commandFilePath, false, (error) ->
        expect(error).toBeNull()
        expect(fs.isFileSync(installationFilePath)).toBeTruthy()
        expect(fs.realpathSync(installationFilePath)).toBe fs.realpathSync(commandFilePath)
        expect(fs.isExecutableSync(installationFilePath)).toBeTruthy()

        done()
