Git = require 'git'
fs = require 'fs'

describe "Git", ->

  beforeEach ->
    fs.remove('/tmp/.git') if fs.isDirectory('/tmp/.git')

  describe "getPath()", ->
    it "returns the repository path for a .git directory path", ->
      repo = new Git(require.resolve('fixtures/git/master.git/HEAD'))
      expect(repo.getPath()).toBe require.resolve('fixtures/git/master.git') + '/'

    it "returns the repository path for a repository path", ->
      repo = new Git(require.resolve('fixtures/git/master.git'))
      expect(repo.getPath()).toBe require.resolve('fixtures/git/master.git') + '/'

  describe "getHead()", ->
    it "returns null for a non-repository", ->
      repo = new Git('/tmp/nogit.txt')
      expect(repo.getHead()).toBeNull

    it "returns a branch name for a non-empty repository", ->
      repo = new Git(require.resolve('fixtures/git/master.git'))
      expect(repo.getHead()).toBe 'refs/heads/master'

  describe "getShortHead()", ->
    it "returns null for a non-repository", ->
      repo = new Git('/tmp/nogit.txt')
      expect(repo.getShortHead()).toBeNull

    it "returns a branch name for a non-empty repository", ->
      repo = new Git(require.resolve('fixtures/git/master.git'))
      expect(repo.getShortHead()).toBe 'master'

  describe "isIgnored()", ->
    it "returns true for an ignored path", ->
      repo = new Git(require.resolve('fixtures/git/ignore.git'))
      expect(repo.isIgnored('a.txt')).toBeTruthy()

    it "returns false for a non-ignored path", ->
      repo = new Git(require.resolve('fixtures/git/ignore.git'))
      expect(repo.isIgnored('b.txt')).toBeFalsy()
