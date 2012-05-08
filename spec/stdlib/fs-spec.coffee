fs = require 'fs'

describe "fs", ->
  describe ".isFile(path)", ->
    fixturesDir = require.resolve('fixtures')
    beforeEach ->

    it "returns true with a file path", ->
      expect(fs.isFile(fs.join(fixturesDir,  'sample.js'))).toBe true

    it "returns false with a directory path", ->
      expect(fs.isFile(fixturesDir)).toBe false

    it "returns false with a non-existent path", ->
      expect(fs.isFile(fs.join(fixturesDir, 'non-existent'))).toBe false
      expect(fs.isFile(null)).toBe false

  describe ".directory(path)", ->
    describe "when called with a file path", ->
      it "returns the path to the directory", ->
        expect(fs.directory(require.resolve('fixtures/dir/a'))).toBe require.resolve('fixtures/dir')

    describe "when called with a directory path", ->
      it "return the path it was given", ->
        expect(fs.directory(require.resolve('fixtures/dir'))).toBe require.resolve('fixtures')
        expect(fs.directory(require.resolve('fixtures/dir/'))).toBe require.resolve('fixtures')

  describe ".join(paths...)", ->
    it "concatenates the given paths with the directory seperator", ->
      expect(fs.join('a')).toBe 'a'
      expect(fs.join('a', 'b', 'c')).toBe 'a/b/c'
      expect(fs.join('/a/b/', 'c', 'd')).toBe '/a/b/c/d'
      expect(fs.join('a', 'b/c/', 'd/')).toBe 'a/b/c/d/'

  describe ".extension(path)", ->
    it "returns the extension of a file", ->
      expect(fs.extension("a/b/corey.txt")).toBe '.txt'
      expect(fs.extension("a/b/corey.txt.coffee")).toBe '.coffee'

    it "returns an empty string for paths without an extension", ->
      expect(fs.extension("a/b.not-extension/a-dir")).toBe ''

  describe ".async", ->
    directoryPath = null
    beforeEach ->
      directoryPath = require.resolve 'fixtures/dir'

    describe ".listTree(directoryPath)", ->
      it "returns a promise that resolves to the recursive contents of that directory", ->
        waitsForPromise ->
          fs.async.listTree(directoryPath).done (result) ->
            expect(result).toEqual fs.listTree(directoryPath)

    describe ".list(directoryPath)", ->
      it "returns a promise that resolves to the contents of that directory", ->
        waitsForPromise ->
          fs.async.list(directoryPath).done (result) ->
            expect(result).toEqual fs.list(directoryPath)

