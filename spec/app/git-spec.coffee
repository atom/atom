Git = require 'git'
fs = require 'fs'

describe "Git", ->

  beforeEach ->
    fs.remove('/tmp/.git') if fs.isDirectory('/tmp/.git')

  describe ".getPath()", ->
    it "returns the repository path for a .git directory path", ->
      repo = new Git(require.resolve('fixtures/git/master.git/HEAD'))
      expect(repo.getPath()).toBe require.resolve('fixtures/git/master.git') + '/'

    it "returns the repository path for a repository path", ->
      repo = new Git(require.resolve('fixtures/git/master.git'))
      expect(repo.getPath()).toBe require.resolve('fixtures/git/master.git') + '/'

  describe ".getHead()", ->
    it "returns null for a non-repository", ->
      repo = new Git('/tmp/nogit.txt')
      expect(repo.getHead()).toBeNull

    it "returns a branch name for a non-empty repository", ->
      repo = new Git(require.resolve('fixtures/git/master.git'))
      expect(repo.getHead()).toBe 'refs/heads/master'

  describe ".getShortHead()", ->
    it "returns null for a non-repository", ->
      repo = new Git('/tmp/nogit.txt')
      expect(repo.getShortHead()).toBeNull

    it "returns a branch name for a non-empty repository", ->
      repo = new Git(require.resolve('fixtures/git/master.git'))
      expect(repo.getShortHead()).toBe 'master'

  describe ".isPathIgnored(path)", ->
    it "returns true for an ignored path", ->
      repo = new Git(require.resolve('fixtures/git/ignore.git'))
      expect(repo.isPathIgnored('a.txt')).toBeTruthy()

    it "returns false for a non-ignored path", ->
      repo = new Git(require.resolve('fixtures/git/ignore.git'))
      expect(repo.isPathIgnored('b.txt')).toBeFalsy()

  describe ".isPathModified(path)", ->
    [repo, path, newPath, originalPathText] = []

    beforeEach ->
      repo = new Git(require.resolve('fixtures/git/working-dir'))
      path = require.resolve('fixtures/git/working-dir/file.txt')
      newPath = fs.join(require.resolve('fixtures/git/working-dir'), 'new-path.txt')
      originalPathText = fs.read(path)

    afterEach ->
      fs.write(path, originalPathText)
      fs.remove(newPath) if fs.exists(newPath)

    describe "when the path is unstaged", ->
      it "returns false if the path has not been modified", ->
        expect(repo.isPathModified(path)).toBeFalsy()

      it "returns true if the path is modified", ->
        fs.write(path, "change")
        expect(repo.isPathModified(path)).toBeTruthy()

      it "returns true if the path is deleted", ->
        fs.remove(path)
        expect(repo.isPathModified(path)).toBeTruthy()

      it "returns false if the path is new", ->
        expect(repo.isPathModified(newPath)).toBeFalsy()

  describe ".isPathNew(path)", ->
    [repo, path, newPath] = []

    beforeEach ->
      repo = new Git(require.resolve('fixtures/git/working-dir'))
      path = require.resolve('fixtures/git/working-dir/file.txt')
      newPath = fs.join(require.resolve('fixtures/git/working-dir'), 'new-path.txt')
      fs.write(newPath, "i'm new here")

    afterEach ->
      fs.remove(newPath) if fs.exists(newPath)

    describe "when the path is unstaged", ->
      it "returns true if the path is new", ->
        expect(repo.isPathNew(newPath)).toBeTruthy()

      it "returns false if the path isn't new", ->
        expect(repo.isPathNew(path)).toBeFalsy()
