{fs} = require 'atom'
path = require 'path'
temp = require 'temp'
installer = require '../src/command-installer'

describe "install(commandPath, callback)", ->
  commandFilePath = temp.openSync("atom-command").path
  commandName = path.basename(commandFilePath)
  instalationPath = temp.mkdirSync("atom-bin")
  instalationFilePath = path.join(instalationPath, commandName)

  beforeEach ->
    spyOn(installer, 'getInstallDirectory').andReturn instalationPath

  describe "on #darwin", ->
    it "symlinks the command and makes it executable", ->
      expect(fs.isFileSync(commandFilePath)).toBeTruthy()
      expect(fs.isExecutableSync(commandFilePath)).toBeFalsy()
      expect(fs.isFileSync(instalationFilePath)).toBeFalsy()

      installDone = false
      installError = null
      installer.install commandFilePath, (error) ->
        installDone = true
        installError = error

      waitsFor ->
        installDone

      runs ->
        expect(installError).toBeNull()
        expect(fs.isFileSync(instalationFilePath)).toBeTruthy()
        expect(fs.realpathSync(instalationFilePath)).toBe fs.realpathSync(commandFilePath)
        expect(fs.isExecutableSync(instalationFilePath)).toBeTruthy()
