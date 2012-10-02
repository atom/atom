fs = require 'fs'

describe "fs", ->
  describe ".isFile(path)", ->
    fixturesDir = require.resolve('fixtures')

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
        expect(fs.directory("/a/b/c")).toBe "/a/b"
        expect(fs.directory("/a")).toBe ""
        expect(fs.directory("a")).toBe ""

  describe ".exists(path)", ->
    it "returns true when path exsits", ->
      expect(fs.exists(require.resolve('fixtures'))).toBe true

    it "returns false when path doesn't exsit", ->
      expect(fs.exists(require.resolve("fixtures") + "/-nope-does-not-exist")).toBe false
      expect(fs.exists("")).toBe false
      expect(fs.exists(null)).toBe false

  describe ".join(paths...)", ->
    it "concatenates the given paths with the directory seperator", ->
      expect(fs.join('a')).toBe 'a'
      expect(fs.join('a', 'b', 'c')).toBe 'a/b/c'
      expect(fs.join('/a/b/', 'c', 'd')).toBe '/a/b/c/d'
      expect(fs.join('a', 'b/c/', 'd/')).toBe 'a/b/c/d/'

  describe ".split(path)", ->
    it "returns path components", ->
      expect(fs.split("/a/b/c.txt")).toEqual ["", "a", "b", "c.txt"]
      expect(fs.split("a/b/c.txt")).toEqual ["a", "b", "c.txt"]

  describe ".extension(path)", ->
    it "returns the extension of a file", ->
      expect(fs.extension("a/b/corey.txt")).toBe '.txt'
      expect(fs.extension("a/b/corey.txt.coffee")).toBe '.coffee'

    it "returns an empty string for paths without an extension", ->
      expect(fs.extension("a/b.not-extension/a-dir")).toBe ''

  describe "makeTree(path)", ->
    beforeEach ->
      fs.remove("/tmp/a") if fs.exists("/tmp/a")

    it "creates all directories in path including any missing parent directories", ->
      fs.makeTree("/tmp/a/b/c")
      expect(fs.exists("/tmp/a/b/c")).toBeTruthy()

  describe ".traverseTree(path, fn)", ->
    fixturesDir = null

    beforeEach ->
      fixturesDir = require.resolve('fixtures')

    it "calls fn for every path in the tree at the given path", ->
      paths = []
      fs.traverseTree fixturesDir, (path) -> paths.push(path)
      expect(paths).toEqual fs.listTree(fixturesDir)

    it "does not recurse into a directory if it is pruned", ->
      paths = []
      fs.traverseTree fixturesDir, (path, prune) ->
        if path.match(/\/dir$/)
          prune()
        else
          paths.push(path)

      expect(paths.length).toBeGreaterThan 0
      for path in paths
        expect(path).not.toMatch /\/dir$/

  describe ".lastModified(path)", ->
    it "returns a Date object representing the time the file was last modified", ->
      beforeWrite = new Date
      fs.write('/tmp/foo', '')
      lastModified = fs.lastModified('/tmp/foo')
      expect(lastModified instanceof Date).toBeTruthy()
      expect(lastModified.getTime()).toBeGreaterThan(beforeWrite.getTime() - 1000)

  describe ".md5ForPath(path)", ->
    it "returns the MD5 hash of the file at the given path", ->
      expect(fs.md5ForPath(require.resolve('fixtures/sample.js'))).toBe 'dd38087d0d7e3e4802a6d3f9b9745f2b'
