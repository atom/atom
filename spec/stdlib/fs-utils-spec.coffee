fsUtils = require 'fs-utils'

describe "fsUtils", ->
  describe ".read(path)", ->
    it "return contents of file", ->
      expect(fsUtils.read(require.resolve("fixtures/sample.txt"))).toBe "Some text.\n"

    it "does not through an exception when the path is a binary file", ->
      expect(-> fsUtils.read(require.resolve("fixtures/binary-file.png"))).not.toThrow()

  describe ".isFile(path)", ->
    fixturesDir = fsUtils.resolveOnLoadPath('fixtures')

    it "returns true with a file path", ->
      expect(fsUtils.isFile(fsUtils.join(fixturesDir,  'sample.js'))).toBe true

    it "returns false with a directory path", ->
      expect(fsUtils.isFile(fixturesDir)).toBe false

    it "returns false with a non-existent path", ->
      expect(fsUtils.isFile(fsUtils.join(fixturesDir, 'non-existent'))).toBe false
      expect(fsUtils.isFile(null)).toBe false

  describe ".directory(path)", ->
    describe "when called with a file path", ->
      it "returns the path to the directory", ->
        expect(fsUtils.directory(fsUtils.resolveOnLoadPath('fixtures/dir/a'))).toBe fsUtils.resolveOnLoadPath('fixtures/dir')

    describe "when called with a directory path", ->
      it "return the path it was given", ->
        expect(fsUtils.directory("/a/b/c")).toBe "/a/b"
        expect(fsUtils.directory("/a")).toBe ""
        expect(fsUtils.directory("a")).toBe ""
        expect(fsUtils.directory("/a/b/c++")).toBe "/a/b"

  describe ".exists(path)", ->
    it "returns true when path exsits", ->
      expect(fsUtils.exists(fsUtils.resolveOnLoadPath('fixtures'))).toBe true

    it "returns false when path doesn't exsit", ->
      expect(fsUtils.exists(fsUtils.resolveOnLoadPath("fixtures") + "/-nope-does-not-exist")).toBe false
      expect(fsUtils.exists("")).toBe false
      expect(fsUtils.exists(null)).toBe false

  describe ".join(paths...)", ->
    it "concatenates the given paths with the directory separator", ->
      expect(fsUtils.join('a')).toBe 'a'
      expect(fsUtils.join('a', 'b', 'c')).toBe 'a/b/c'
      expect(fsUtils.join('/a/b/', 'c', 'd')).toBe '/a/b/c/d'
      expect(fsUtils.join('a', 'b/c/', 'd/')).toBe 'a/b/c/d/'

  describe ".split(path)", ->
    it "returns path components", ->
      expect(fsUtils.split("/a/b/c.txt")).toEqual ["", "a", "b", "c.txt"]
      expect(fsUtils.split("a/b/c.txt")).toEqual ["a", "b", "c.txt"]

  describe ".extension(path)", ->
    it "returns the extension of a file", ->
      expect(fsUtils.extension("a/b/corey.txt")).toBe '.txt'
      expect(fsUtils.extension("a/b/corey.txt.coffee")).toBe '.coffee'

    it "returns an empty string for paths without an extension", ->
      expect(fsUtils.extension("a/b.not-extension/a-dir")).toBe ''

  describe ".makeTree(path)", ->
    beforeEach ->
      fsUtils.remove("/tmp/a") if fsUtils.exists("/tmp/a")

    it "creates all directories in path including any missing parent directories", ->
      fsUtils.makeTree("/tmp/a/b/c")
      expect(fsUtils.exists("/tmp/a/b/c")).toBeTruthy()

  describe ".traverseTreeSync(path, onFile, onDirectory)", ->
    fixturesDir = null

    beforeEach ->
      fixturesDir = fsUtils.resolveOnLoadPath('fixtures')

    it "calls fn for every path in the tree at the given path", ->
      paths = []
      onPath = (path) ->
        paths.push(path)
        true
      fsUtils.traverseTreeSync fixturesDir, onPath, onPath
      expect(paths).toEqual fsUtils.listTree(fixturesDir)

    it "does not recurse into a directory if it is pruned", ->
      paths = []
      onPath = (path) ->
        if path.match(/\/dir$/)
          false
        else
          paths.push(path)
          true
      fsUtils.traverseTreeSync fixturesDir, onPath, onPath

      expect(paths.length).toBeGreaterThan 0
      for path in paths
        expect(path).not.toMatch /\/dir\//

    it "returns entries if path is a symlink", ->
      symlinkPath = fsUtils.join(fixturesDir, 'symlink-to-dir')
      symlinkPaths = []
      onSymlinkPath = (path) -> symlinkPaths.push(path.substring(symlinkPath.length + 1))

      regularPath = fsUtils.join(fixturesDir, 'dir')
      paths = []
      onPath = (path) -> paths.push(path.substring(regularPath.length + 1))

      fsUtils.traverseTreeSync(symlinkPath, onSymlinkPath, onSymlinkPath)
      fsUtils.traverseTreeSync(regularPath, onPath, onPath)

      expect(symlinkPaths).toEqual(paths)

  describe ".md5ForPath(path)", ->
    it "returns the MD5 hash of the file at the given path", ->
      expect(fsUtils.md5ForPath(require.resolve('fixtures/sample.js'))).toBe 'dd38087d0d7e3e4802a6d3f9b9745f2b'

  describe ".list(path, extensions)", ->
    it "returns the absolute paths of entries within the given directory", ->
      paths = fsUtils.list(project.getPath())
      expect(paths).toContain project.resolve('css.css')
      expect(paths).toContain project.resolve('coffee.coffee')
      expect(paths).toContain project.resolve('two-hundred.txt')

    it "returns an empty array for paths that aren't directories or don't exist", ->
      expect(fsUtils.list(project.resolve('sample.js'))).toEqual []
      expect(fsUtils.list('/non/existent/directory')).toEqual []

    it "can filter the paths by an optional array of file extensions", ->
      paths = fsUtils.list(project.getPath(), ['.css', 'coffee'])
      expect(paths).toContain project.resolve('css.css')
      expect(paths).toContain project.resolve('coffee.coffee')
      expect(path).toMatch /(css|coffee)$/ for path in paths

  describe ".listAsync(path, [extensions,] callback)", ->
    paths = null

    it "calls the callback with the absolute paths of entries within the given directory", ->
      waitsFor (done) ->
        fsUtils.listAsync project.getPath(), (err, result) ->
          paths = result
          done()
      runs ->
        expect(paths).toContain project.resolve('css.css')
        expect(paths).toContain project.resolve('coffee.coffee')
        expect(paths).toContain project.resolve('two-hundred.txt')

    it "can filter the paths by an optional array of file extensions", ->
      waitsFor (done) ->
        fsUtils.listAsync project.getPath(), ['css', '.coffee'], (err, result) ->
          paths = result
          done()
      runs ->
        expect(paths).toContain project.resolve('css.css')
        expect(paths).toContain project.resolve('coffee.coffee')
        expect(path).toMatch /(css|coffee)$/ for path in paths
