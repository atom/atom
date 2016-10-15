path = require 'path'
fs = require 'fs-plus'
AtomPortable = require '../src/main-process/atom-portable'

portableModeCommonPlatformBehavior = (platform) ->
  describe "with ATOM_HOME environment variable", ->
    it "returns false", ->
      expect(AtomPortable.isPortableInstall(platform, "C:\\some\\path")).toBe false

  describe "without ATOM_HOME environment variable", ->
    environmentAtomHome = undefined
    portableAtomHomePath = path.join(path.dirname(process.execPath), "..", ".atom")
    portableAtomHomeNaturallyExists = fs.existsSync(portableAtomHomePath)
    portableAtomHomeBackupPath =  "#{portableAtomHomePath}.temp"

    beforeEach ->
      fs.renameSync(portableAtomHomePath, portableAtomHomeBackupPath) if fs.existsSync(portableAtomHomePath)

    afterEach ->
      if portableAtomHomeNaturallyExists
        fs.renameSync(portableAtomHomeBackupPath, portableAtomHomePath) if not fs.existsSync(portableAtomHomePath)
      else
        fs.removeSync(portableAtomHomePath) if fs.existsSync(portableAtomHomePath)
      fs.removeSync(portableAtomHomeBackupPath) if fs.existsSync(portableAtomHomeBackupPath)

    describe "with .atom directory sibling to exec", ->
      beforeEach ->
        fs.mkdirSync(portableAtomHomePath) if not fs.existsSync(portableAtomHomePath)

    describe "without .atom directory sibling to exec", ->
      beforeEach ->
        fs.removeSync(portableAtomHomePath) if fs.existsSync(portableAtomHomePath)

      it "returns false", ->
        expect(AtomPortable.isPortableInstall(platform, environmentAtomHome)).toBe false

describe "Set Portable Mode on #win32", ->
  portableAtomHomePath = path.join(path.dirname(process.execPath), "..", ".atom")
  portableAtomHomeNaturallyExists = fs.existsSync(portableAtomHomePath)
  portableAtomHomeBackupPath =  "#{portableAtomHomePath}.temp"

  beforeEach ->
    fs.renameSync(portableAtomHomePath, portableAtomHomeBackupPath) if fs.existsSync(portableAtomHomePath)

  afterEach ->
    if portableAtomHomeNaturallyExists
      fs.renameSync(portableAtomHomeBackupPath, portableAtomHomePath) if not fs.existsSync(portableAtomHomePath)
    else
      fs.removeSync(portableAtomHomePath) if fs.existsSync(portableAtomHomePath)
    fs.removeSync(portableAtomHomeBackupPath) if fs.existsSync(portableAtomHomeBackupPath)

  it "creates a portable home directory", ->
    expect(fs.existsSync(portableAtomHomePath)).toBe false

    AtomPortable.setPortable(process.env.ATOM_HOME)
    expect(fs.existsSync(portableAtomHomePath)).toBe true

describe "Check for Portable Mode", ->
  describe "Windows", ->
    portableModeCommonPlatformBehavior "win32"

  describe "Mac", ->
    it "returns false", ->
      expect(AtomPortable.isPortableInstall("darwin", "darwin")).toBe false

  describe "Linux", ->
    portableModeCommonPlatformBehavior "linux"
