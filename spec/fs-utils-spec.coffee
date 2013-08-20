fsUtils = require 'fs-utils'
fs = require 'fs'
path = require 'path'
temp = require 'temp'

describe "fsUtils", ->
  describe ".read(path)", ->
    it "return contents of file", ->
      expect(fsUtils.read(require.resolve("fixtures/sample.txt"))).toBe "Some text.\n"

    it "does not through an exception when the path is a binary file", ->
      expect(-> fsUtils.read(require.resolve("fixtures/binary-file.png"))).not.toThrow()

  describe ".isFileSync(path)", ->
    fixturesDir = fsUtils.resolveOnLoadPath('fixtures')

    it "returns true with a file path", ->
      expect(fsUtils.isFileSync(path.join(fixturesDir,  'sample.js'))).toBe true

    it "returns false with a directory path", ->
      expect(fsUtils.isFileSync(fixturesDir)).toBe false

    it "returns false with a non-existent path", ->
      expect(fsUtils.isFileSync(path.join(fixturesDir, 'non-existent'))).toBe false
      expect(fsUtils.isFileSync(null)).toBe false

  describe ".exists(path)", ->
    it "returns true when path exsits", ->
      expect(fsUtils.exists(fsUtils.resolveOnLoadPath('fixtures'))).toBe true

    it "returns false when path doesn't exsit", ->
      expect(fsUtils.exists(fsUtils.resolveOnLoadPath("fixtures") + "/-nope-does-not-exist")).toBe false
      expect(fsUtils.exists("")).toBe false
      expect(fsUtils.exists(null)).toBe false

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
      onPath = (childPath) ->
        paths.push(childPath)
        true
      fsUtils.traverseTreeSync fixturesDir, onPath, onPath
      expect(paths).toEqual fsUtils.listTreeSync(fixturesDir)

    it "does not recurse into a directory if it is pruned", ->
      paths = []
      onPath = (childPath) ->
        if childPath.match(/\/dir$/)
          false
        else
          paths.push(childPath)
          true
      fsUtils.traverseTreeSync fixturesDir, onPath, onPath

      expect(paths.length).toBeGreaterThan 0
      for filePath in paths
        expect(filePath).not.toMatch /\/dir\//

    it "returns entries if path is a symlink", ->
      symlinkPath = path.join(fixturesDir, 'symlink-to-dir')
      symlinkPaths = []
      onSymlinkPath = (path) -> symlinkPaths.push(path.substring(symlinkPath.length + 1))

      regularPath = path.join(fixturesDir, 'dir')
      paths = []
      onPath = (path) -> paths.push(path.substring(regularPath.length + 1))

      fsUtils.traverseTreeSync(symlinkPath, onSymlinkPath, onSymlinkPath)
      fsUtils.traverseTreeSync(regularPath, onPath, onPath)

      expect(symlinkPaths).toEqual(paths)

    it "ignores missing symlinks", ->
      directory = temp.mkdirSync('symlink-in-here')
      paths = []
      onPath = (childPath) -> paths.push(childPath)
      fs.symlinkSync(path.join(directory, 'source'), path.join(directory, 'destination'))
      fsUtils.traverseTreeSync(directory, onPath)
      expect(paths.length).toBe 0

  describe ".md5ForPath(path)", ->
    it "returns the MD5 hash of the file at the given path", ->
      expect(fsUtils.md5ForPath(require.resolve('fixtures/sample.js'))).toBe 'dd38087d0d7e3e4802a6d3f9b9745f2b'

  describe ".list(path, extensions)", ->
    it "returns the absolute paths of entries within the given directory", ->
      paths = fsUtils.listSync(project.getPath())
      expect(paths).toContain project.resolve('css.css')
      expect(paths).toContain project.resolve('coffee.coffee')
      expect(paths).toContain project.resolve('two-hundred.txt')

    it "returns an empty array for paths that aren't directories or don't exist", ->
      expect(fsUtils.listSync(project.resolve('sample.js'))).toEqual []
      expect(fsUtils.listSync('/non/existent/directory')).toEqual []

    it "can filter the paths by an optional array of file extensions", ->
      paths = fsUtils.listSync(project.getPath(), ['.css', 'coffee'])
      expect(paths).toContain project.resolve('css.css')
      expect(paths).toContain project.resolve('coffee.coffee')
      expect(listedPath).toMatch /(css|coffee)$/ for listedPath in paths

  describe ".list(path, [extensions,] callback)", ->
    paths = null

    it "calls the callback with the absolute paths of entries within the given directory", ->
      waitsFor (done) ->
        fsUtils.list project.getPath(), (err, result) ->
          paths = result
          done()
      runs ->
        expect(paths).toContain project.resolve('css.css')
        expect(paths).toContain project.resolve('coffee.coffee')
        expect(paths).toContain project.resolve('two-hundred.txt')

    it "can filter the paths by an optional array of file extensions", ->
      waitsFor (done) ->
        fsUtils.list project.getPath(), ['css', '.coffee'], (err, result) ->
          paths = result
          done()
      runs ->
        expect(paths).toContain project.resolve('css.css')
        expect(paths).toContain project.resolve('coffee.coffee')
        expect(listedPath).toMatch /(css|coffee)$/ for listedPath in paths

  describe ".absolute(relativePath)", ->
    it "converts a leading ~ segment to the HOME directory", ->
      expect(fsUtils.absolute('~')).toBe fs.realpathSync(process.env.HOME)
      expect(fsUtils.absolute(path.join('~', 'does', 'not', 'exist'))).toBe path.join(process.env.HOME, 'does', 'not', 'exist')
      expect(fsUtils.absolute('~test')).toBe '~test'
