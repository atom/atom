{fs} = require 'atom-api'
path = require 'path'
temp = require 'temp'

describe "fs", ->
  fixturesDir = path.join(__dirname, 'fixtures')

  describe ".read(path)", ->
    it "return contents of file", ->
      expect(fs.read(require.resolve("./fixtures/sample.txt"))).toBe "Some text.\n"

    it "does not through an exception when the path is a binary file", ->
      expect(-> fs.read(require.resolve("./fixtures/binary-file.png"))).not.toThrow()

  describe ".isFileSync(path)", ->
    it "returns true with a file path", ->
      expect(fs.isFileSync(path.join(fixturesDir,  'sample.js'))).toBe true

    it "returns false with a directory path", ->
      expect(fs.isFileSync(fixturesDir)).toBe false

    it "returns false with a non-existent path", ->
      expect(fs.isFileSync(path.join(fixturesDir, 'non-existent'))).toBe false
      expect(fs.isFileSync(null)).toBe false

  describe ".exists(path)", ->
    it "returns true when path exsits", ->
      expect(fs.exists(fixturesDir)).toBe true

    it "returns false when path doesn't exsit", ->
      expect(fs.exists(path.join(fixturesDir, "-nope-does-not-exist"))).toBe false
      expect(fs.exists("")).toBe false
      expect(fs.exists(null)).toBe false

  describe ".makeTree(path)", ->
    beforeEach ->
      fs.remove("/tmp/a") if fs.exists("/tmp/a")

    it "creates all directories in path including any missing parent directories", ->
      fs.makeTree("/tmp/a/b/c")
      expect(fs.exists("/tmp/a/b/c")).toBeTruthy()

  describe ".traverseTreeSync(path, onFile, onDirectory)", ->
    it "calls fn for every path in the tree at the given path", ->
      paths = []
      onPath = (childPath) ->
        paths.push(childPath)
        true
      fs.traverseTreeSync fixturesDir, onPath, onPath
      expect(paths).toEqual fs.listTreeSync(fixturesDir)

    it "does not recurse into a directory if it is pruned", ->
      paths = []
      onPath = (childPath) ->
        if childPath.match(/\/dir$/)
          false
        else
          paths.push(childPath)
          true
      fs.traverseTreeSync fixturesDir, onPath, onPath

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

      fs.traverseTreeSync(symlinkPath, onSymlinkPath, onSymlinkPath)
      fs.traverseTreeSync(regularPath, onPath, onPath)

      expect(symlinkPaths).toEqual(paths)

    it "ignores missing symlinks", ->
      directory = temp.mkdirSync('symlink-in-here')
      paths = []
      onPath = (childPath) -> paths.push(childPath)
      fs.symlinkSync(path.join(directory, 'source'), path.join(directory, 'destination'))
      fs.traverseTreeSync(directory, onPath)
      expect(paths.length).toBe 0

  describe ".md5ForPath(path)", ->
    it "returns the MD5 hash of the file at the given path", ->
      expect(fs.md5ForPath(require.resolve('./fixtures/sample.js'))).toBe 'dd38087d0d7e3e4802a6d3f9b9745f2b'

  describe ".list(path, extensions)", ->
    it "returns the absolute paths of entries within the given directory", ->
      paths = fs.listSync(project.getPath())
      expect(paths).toContain project.resolve('css.css')
      expect(paths).toContain project.resolve('coffee.coffee')
      expect(paths).toContain project.resolve('two-hundred.txt')

    it "returns an empty array for paths that aren't directories or don't exist", ->
      expect(fs.listSync(project.resolve('sample.js'))).toEqual []
      expect(fs.listSync('/non/existent/directory')).toEqual []

    it "can filter the paths by an optional array of file extensions", ->
      paths = fs.listSync(project.getPath(), ['.css', 'coffee'])
      expect(paths).toContain project.resolve('css.css')
      expect(paths).toContain project.resolve('coffee.coffee')
      expect(listedPath).toMatch /(css|coffee)$/ for listedPath in paths

  describe ".list(path, [extensions,] callback)", ->
    paths = null

    it "calls the callback with the absolute paths of entries within the given directory", ->
      waitsFor (done) ->
        fs.list project.getPath(), (err, result) ->
          paths = result
          done()
      runs ->
        expect(paths).toContain project.resolve('css.css')
        expect(paths).toContain project.resolve('coffee.coffee')
        expect(paths).toContain project.resolve('two-hundred.txt')

    it "can filter the paths by an optional array of file extensions", ->
      waitsFor (done) ->
        fs.list project.getPath(), ['css', '.coffee'], (err, result) ->
          paths = result
          done()
      runs ->
        expect(paths).toContain project.resolve('css.css')
        expect(paths).toContain project.resolve('coffee.coffee')
        expect(listedPath).toMatch /(css|coffee)$/ for listedPath in paths

  describe ".absolute(relativePath)", ->
    it "converts a leading ~ segment to the HOME directory", ->
      expect(fs.absolute('~')).toBe fs.realpathSync(process.env.HOME)
      expect(fs.absolute(path.join('~', 'does', 'not', 'exist'))).toBe path.join(process.env.HOME, 'does', 'not', 'exist')
      expect(fs.absolute('~test')).toBe '~test'
