path = require 'path'
{Directory} = require 'pathwatcher'
GitRepository = require '../src/git-repository'
GitRepositoryProvider = require '../src/git-repository-provider'

describe "GitRepositoryProvider", ->
  describe ".repositoryForDirectory(directory)", ->

    describe "when specified a Directory with a Git repository", ->
      it "returns a Promise that resolves to a GitRepository", ->
        provider = new GitRepositoryProvider atom.project
        theResult = null

        waitsForPromise ->
          directory = new Directory path.join(__dirname, 'fixtures/git/master.git')
          provider.repositoryForDirectory(directory).then (result) -> theResult = result

        runs ->
          expect(theResult).toBeInstanceOf GitRepository
          expect(provider.pathToRepository[theResult.getPath()]).toBeTruthy()
          expect(theResult.statusTask).toBeTruthy()

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
      provider = new GitRepositoryProvider atom.project
      theResult = 'dummy_value'

      it "returns a Promise that resolves to null", ->
        waitsForPromise ->
          directory = new Directory '/tmp'
          provider.repositoryForDirectory(directory).then (result) -> theResult = result

      runs ->
        expect(theResult).toBe null
