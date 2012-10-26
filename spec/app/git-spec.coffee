Git = require 'git'

describe "Git", ->

  describe "getPath()", ->
    it "returns the repository path for a .git directory path", ->
      repo = new Git(require.resolve('fixtures/git/master.git/HEAD'))
      expect(repo.getPath()).toBe require.resolve('fixtures/git/master.git') + '/'

    it "returns the repository path for a repository path", ->
      repo = new Git(require.resolve('fixtures/git/master.git'))
      expect(repo.getPath()).toBe require.resolve('fixtures/git/master.git') + '/'

  describe "getHead()", ->
    it "returns null for a empty repository", ->
      repo = new Git(require.resolve('fixtures/git/nohead.git'))
      expect(repo.getHead()).toBeNull

    it "returns a branch name for a non-empty repository", ->
      repo = new Git(require.resolve('fixtures/git/master.git'))
      expect(repo.getHead()).toBe 'refs/heads/master'

  describe "getShortHead()", ->
    it "returns null for a empty repository", ->
      repo = new Git(require.resolve('fixtures/git/nohead.git'))
      expect(repo.getShortHead()).toBeNull

    it "returns a branch name for a non-empty repository", ->
      repo = new Git(require.resolve('fixtures/git/master.git'))
      expect(repo.getShortHead()).toBe 'master'
