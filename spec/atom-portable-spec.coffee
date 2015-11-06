path = require "path"
fs = require 'fs-plus'
temp = require "temp"
AtomPortable = require "../src/browser/atom-portable"

portableModeCommonPlatformBehavior = (platform, portableAtomHomePath) ->
  describe "with ATOM_HOME environment variable", ->
    it "returns false", ->
      expect(AtomPortable.isPortableInstall(platform, "C:\\some\\path")).toBe false

  describe "without ATOM_HOME environment variable", ->
    environmentAtomHome = undefined
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

      it "returns true", ->
        expect(AtomPortable.isPortableInstall(platform, environmentAtomHome)).toBe true

    describe "without .atom directory sibling to exec", ->
      beforeEach ->
        fs.removeSync(portableAtomHomePath) if fs.existsSync(portableAtomHomePath)

      it "returns false", ->
        expect(AtomPortable.isPortableInstall(platform, environmentAtomHome)).toBe false

describe "Set Portable Mode", ->
  portableAtomHomePath =
    if process.platform is 'darwin'
      path.join(process.resourcesPath, "..", "..", '..', ".atom")
    else
      path.join(path.dirname(process.execPath), "..", ".atom")
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

    AtomPortable.setPortable(process.platform, process.env.ATOM_HOME)
    expect(fs.existsSync(portableAtomHomePath)).toBe true

describe "Check for Portable Mode", ->
  simplePortableAtomHomePath = path.join(path.dirname(process.execPath), "..", ".atom")
  describe "Windows", ->
    portableModeCommonPlatformBehavior "win32", simplePortableAtomHomePath

  describe "Mac", ->
    portableModeCommonPlatformBehavior "darwin", path.join(process.resourcesPath, "..", "..", '..', ".atom")

  describe "Linux", ->
    portableModeCommonPlatformBehavior "linux", simplePortableAtomHomePath
