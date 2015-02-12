path = require 'path'
{Directory} = require 'pathwatcher'
GitRepository = require '../src/git-repository'
GitRepositoryProvider = require '../src/git-repository-provider'

describe "GitRepositoryProvider", ->
  describe ".repositoryForDirectory(directory)", ->

    describe "when specified a Directory with a Git repository", ->
      it "returns a Promise that resolves to a GitRepository", ->
        waitsForPromise ->
          provider = new GitRepositoryProvider atom.project
          directory = new Directory path.join(__dirname, 'fixtures/git/master.git')
          provider.repositoryForDirectory(directory).then (result) ->
            expect(result).toBeInstanceOf GitRepository
            expect(provider.pathToRepository[result.getPath()]).toBeTruthy()
            expect(result.statusTask).toBeTruthy()

      it "returns the same GitRepository for different Directory objects in the same repo", ->
        provider = new GitRepositoryProvider atom.project
        firstRepo = null
        secondRepo = null

        waitsForPromise ->
          directory = new Directory path.join(__dirname, 'fixtures/git/master.git')
          provider.repositoryForDirectory(directory).then (result) -> firstRepo = result

        waitsForPromise ->
          directory = new Directory path.join(__dirname, 'fixtures/git/master.git/objects')
          provider.repositoryForDirectory(directory).then (result) -> secondRepo = result

        runs ->
          expect(firstRepo).toBeInstanceOf GitRepository
          expect(firstRepo).toBe secondRepo

    describe "when specified a Directory without a Git repository", ->
      it "returns a Promise that resolves to null", ->
        waitsForPromise ->
          provider = new GitRepositoryProvider atom.project
          directory = new Directory '/tmp'
          provider.repositoryForDirectory(directory).then (result) ->
            expect(result).toBe null
