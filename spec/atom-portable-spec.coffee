path = require "path"
fs = require 'fs-plus'
temp = require "temp"
rimraf = require "rimraf"
AtomPortable = require "../src/browser/atom-portable"

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
      rimraf.sync(portableAtomHomePath) if fs.existsSync(portableAtomHomePath)
    rimraf.sync(portableAtomHomeBackupPath) if fs.existsSync(portableAtomHomeBackupPath)

  it "creates a portable home directory", ->
    expect(fs.existsSync(portableAtomHomePath)).toBe false

    AtomPortable.setPortable(process.env.ATOM_HOME)
    expect(fs.existsSync(portableAtomHomePath)).toBe true

describe "Check for Portable Mode", ->
  describe "Windows", ->
    describe "with ATOM_HOME environment variable", ->
      it "returns false", ->
        expect(AtomPortable.isPortableInstall("win32", "C:\\some\\path")).toBe false

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
          rimraf.sync(portableAtomHomePath) if fs.existsSync(portableAtomHomePath)
        rimraf.sync(portableAtomHomeBackupPath) if fs.existsSync(portableAtomHomeBackupPath)

      describe "with .atom directory sibling to exec", ->
        beforeEach ->
          fs.mkdirSync(portableAtomHomePath) if not fs.existsSync(portableAtomHomePath)

        it "returns true", ->
          expect(AtomPortable.isPortableInstall("win32", environmentAtomHome)).toBe true

      describe "without .atom directory sibling to exec", ->
        beforeEach ->
          rimraf.sync(portableAtomHomePath) if fs.existsSync(portableAtomHomePath)

        it "returns false", ->
          expect(AtomPortable.isPortableInstall("win32", environmentAtomHome)).toBe false

  describe "Mac", ->
    it "returns false", ->
      expect(AtomPortable.isPortableInstall("darwin", "darwin")).toBe false

  describe "Linux", ->
    it "returns false", ->
      expect(AtomPortable.isPortableInstall("linux", "linux")).toBe false
