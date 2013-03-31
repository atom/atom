fs = require 'fs-utils'

describe "fs", ->
  describe ".read(path)", ->
    it "return contents of file", ->
      expect(fs.read(require.resolve("fixtures/sample.txt"))).toBe "Some text.\n"

    it "does not through an exception when the path is a binary file", ->
      expect(-> fs.read(require.resolve("fixtures/binary-file.png"))).not.toThrow()

  describe ".isFile(path)", ->
    fixturesDir = fs.resolveOnLoadPath('fixtures')

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
        expect(fs.directory(fs.resolveOnLoadPath('fixtures/dir/a'))).toBe fs.resolveOnLoadPath('fixtures/dir')

    describe "when called with a directory path", ->
      it "return the path it was given", ->
        expect(fs.directory("/a/b/c")).toBe "/a/b"
        expect(fs.directory("/a")).toBe ""
        expect(fs.directory("a")).toBe ""
        expect(fs.directory("/a/b/c++")).toBe "/a/b"

  describe ".base(path, ext)", ->
    describe "when called with an extension", ->
      it "return the base name without the extension when the path has the given extension", ->
        expect(fs.base("/a/b/c.txt", '.txt')).toBe "c"
        expect(fs.base("/a/b/c.txt", '.txt2')).toBe "c.txt"
        expect(fs.base("/a/b/c.+", '.+')).toBe "c"

  describe ".exists(path)", ->
    it "returns true when path exsits", ->
      expect(fs.exists(fs.resolveOnLoadPath('fixtures'))).toBe true

    it "returns false when path doesn't exsit", ->
      expect(fs.exists(fs.resolveOnLoadPath("fixtures") + "/-nope-does-not-exist")).toBe false
      expect(fs.exists("")).toBe false
      expect(fs.exists(null)).toBe false

  describe ".join(paths...)", ->
    it "concatenates the given paths with the directory separator", ->
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

  describe ".makeTree(path)", ->
    beforeEach ->
      fs.remove("/tmp/a") if fs.exists("/tmp/a")

    it "creates all directories in path including any missing parent directories", ->
      fs.makeTree("/tmp/a/b/c")
      expect(fs.exists("/tmp/a/b/c")).toBeTruthy()

  describe ".traverseTreeSync(path, onFile, onDirectory)", ->
    fixturesDir = null

    beforeEach ->
      fixturesDir = fs.resolveOnLoadPath('fixtures')

    it "calls fn for every path in the tree at the given path", ->
      paths = []
      onPath = (path) ->
        paths.push(path)
        true
      fs.traverseTreeSync fixturesDir, onPath, onPath
      expect(paths).toEqual fs.listTree(fixturesDir)

    it "does not recurse into a directory if it is pruned", ->
      paths = []
      onPath = (path) ->
        if path.match(/\/dir$/)
          false
        else
          paths.push(path)
          true
      fs.traverseTreeSync fixturesDir, onPath, onPath

      expect(paths.length).toBeGreaterThan 0
      for path in paths
        expect(path).not.toMatch /\/dir\//

    it "returns entries if path is a symlink", ->
      symlinkPath = fs.join(fixturesDir, 'symlink-to-dir')
      symlinkPaths = []
      onSymlinkPath = (path) -> symlinkPaths.push(path.substring(symlinkPath.length + 1))

      regularPath = fs.join(fixturesDir, 'dir')
      paths = []
      onPath = (path) -> paths.push(path.substring(regularPath.length + 1))

      fs.traverseTreeSync(symlinkPath, onSymlinkPath, onSymlinkPath)
      fs.traverseTreeSync(regularPath, onPath, onPath)

      expect(symlinkPaths).toEqual(paths)

  describe ".md5ForPath(path)", ->
    it "returns the MD5 hash of the file at the given path", ->
      expect(fs.md5ForPath(require.resolve('fixtures/sample.js'))).toBe 'dd38087d0d7e3e4802a6d3f9b9745f2b'

  describe ".list(path, extensions)", ->
    it "returns the absolute paths of entries within the given directory", ->
      paths = fs.list(project.getPath())
      expect(paths).toContain project.resolve('css.css')
      expect(paths).toContain project.resolve('coffee.coffee')
      expect(paths).toContain project.resolve('two-hundred.txt')

    it "returns an empty array for paths that aren't directories or don't exist", ->
      expect(fs.list(project.resolve('sample.js'))).toEqual []
      expect(fs.list('/non/existent/directory')).toEqual []

    it "can filter the paths by an optional array of file extensions", ->
      paths = fs.list(project.getPath(), ['.css', 'coffee'])
      expect(paths).toContain project.resolve('css.css')
      expect(paths).toContain project.resolve('coffee.coffee')
      expect(path).toMatch /(css|coffee)$/ for path in paths

  describe ".listAsync(path, [extensions,] callback)", ->
    paths = null

    it "calls the callback with the absolute paths of entries within the given directory", ->
      waitsFor (done) ->
        fs.listAsync project.getPath(), (err, result) ->
          paths = result
          done()
      runs ->
        expect(paths).toContain project.resolve('css.css')
        expect(paths).toContain project.resolve('coffee.coffee')
        expect(paths).toContain project.resolve('two-hundred.txt')

    it "can filter the paths by an optional array of file extensions", ->
      waitsFor (done) ->
        fs.listAsync project.getPath(), ['css', '.coffee'], (err, result) ->
          paths = result
          done()
      runs ->
        expect(paths).toContain project.resolve('css.css')
        expect(paths).toContain project.resolve('coffee.coffee')
        expect(path).toMatch /(css|coffee)$/ for path in paths
