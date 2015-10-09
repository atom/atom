path = require "path"
fs = require 'fs-plus'
temp = require "temp"
rimraf = require "rimraf"
AtomPortable = require "../src/browser/atom-portable"

describe "Portable Mode", ->
  describe "Windows", ->
    platform = "win32"

    describe "with ATOM_HOME environment variable", ->
      environmentAtomHome = "C:\\some\\path"
      it "returns false", ->
        expect(AtomPortable.isPortableInstall(platform, environmentAtomHome)).toBe false

    describe "without ATOM_HOME environment variable", ->
      environmentAtomHome = undefined
      portableAtomHomePath = path.join(path.dirname(process.execPath), "../.atom").toString()
      portableAtomHomeNaturallyExists = fs.existsSync(portableAtomHomePath)
      portableAtomHomeBackupPath = portableAtomHomePath + ".temp"

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
          expect(AtomPortable.isPortableInstall(platform, environmentAtomHome)).toBe true

      describe "without .atom directory sibling to exec", ->
        beforeEach ->
          rimraf.sync(portableAtomHomePath) if fs.existsSync(portableAtomHomePath)
        it "returns false", ->
          expect(AtomPortable.isPortableInstall(platform, environmentAtomHome)).toBe false

  describe "Mac", ->
    platform = "darwin"
    it "returns false", ->
      expect(AtomPortable.isPortableInstall(platform, platform)).toBe false

  describe "Linux", ->
    platform = "linux"
    it "returns false", ->
      expect(AtomPortable.isPortableInstall(platform, platform)).toBe false
