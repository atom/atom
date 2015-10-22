path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
CommandInstaller = require '../src/command-installer'

describe "CommandInstaller on #darwin", ->
  [installer, resourcesPath, installationPath, atomBinPath, apmBinPath] = []

  beforeEach ->
    installationPath = temp.mkdirSync("atom-bin")

    resourcesPath = temp.mkdirSync('atom-app')
    atomBinPath = path.join(resourcesPath, 'app', 'atom.sh')
    apmBinPath = path.join(resourcesPath, 'app', 'apm', 'node_modules', '.bin', 'apm')
    fs.writeFileSync(atomBinPath, "")
    fs.writeFileSync(apmBinPath, "")
    fs.chmodSync(atomBinPath, '755')
    fs.chmodSync(apmBinPath, '755')

    spyOn(CommandInstaller::, 'getResourcesDirectory').andReturn(resourcesPath)
    spyOn(CommandInstaller::, 'getInstallDirectory').andReturn(installationPath)

  describe "when using a stable version of atom", ->
    beforeEach ->
      confirm = ->
      installer = new CommandInstaller("2.0.2", confirm)

    it "symlinks the atom command as 'atom'", ->
      installedAtomPath = path.join(installationPath, 'atom')

      expect(fs.isFileSync(installedAtomPath)).toBeFalsy()

      waitsFor (done) ->
        installer.installAtomCommand(false, done)

      runs ->
        expect(fs.realpathSync(installedAtomPath)).toBe fs.realpathSync(atomBinPath)
        expect(fs.isExecutableSync(installedAtomPath)).toBe true
        expect(fs.isFileSync(path.join(installationPath, 'atom-beta'))).toBe false

    it "symlinks the apm command as 'apm'", ->
      installedApmPath = path.join(installationPath, 'apm')

      expect(fs.isFileSync(installedApmPath)).toBeFalsy()

      waitsFor (done) ->
        installer.installApmCommand(false, done)

      runs ->
        expect(fs.realpathSync(installedApmPath)).toBe fs.realpathSync(apmBinPath)
        expect(fs.isExecutableSync(installedApmPath)).toBeTruthy()
        expect(fs.isFileSync(path.join(installationPath, 'apm-beta'))).toBe false

  describe "when using a beta version of atom", ->
    beforeEach ->
      installer = new CommandInstaller("2.2.0-beta.0")

    it "symlinks the atom command as 'atom-beta'", ->
      installedAtomPath = path.join(installationPath, 'atom-beta')

      expect(fs.isFileSync(installedAtomPath)).toBeFalsy()

      waitsFor (done) ->
        installer.installAtomCommand(false, done)

      runs ->
        expect(fs.realpathSync(installedAtomPath)).toBe fs.realpathSync(atomBinPath)
        expect(fs.isExecutableSync(installedAtomPath)).toBe true
        expect(fs.isFileSync(path.join(installationPath, 'atom'))).toBe false

    it "symlinks the apm command as 'apm-beta'", ->
      installedApmPath = path.join(installationPath, 'apm-beta')

      expect(fs.isFileSync(installedApmPath)).toBeFalsy()

      waitsFor (done) ->
        installer.installApmCommand(false, done)

      runs ->
        expect(fs.realpathSync(installedApmPath)).toBe fs.realpathSync(apmBinPath)
        expect(fs.isExecutableSync(installedApmPath)).toBeTruthy()
        expect(fs.isFileSync(path.join(installationPath, 'apm'))).toBe false
