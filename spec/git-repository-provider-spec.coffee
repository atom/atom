path = require 'path'
{Directory} = require 'pathwatcher'
GitRepository = require '../src/git-repository'
GitRepositoryProvider = require '../src/git-repository-provider'

describe "GitRepositoryProvider", ->
  describe ".repositoryForDirectory(directory)", ->

    describe "when specified a Directory with a Git repository", ->
      provider = new GitRepositoryProvider atom.project
      the_result = 'dummy_value'
      the_second_result = 'dummy_value2'

      it "returns a Promise that resolves to a GitRepository", ->
        waitsForPromise ->
          directory = new Directory path.join(__dirname, 'fixtures/git/master.git')
          provider.repositoryForDirectory(directory).then (result) -> the_result = result

        runs ->
          expect(the_result).toBeInstanceOf GitRepository
          expect(provider.pathToRepository[the_result.getPath()]).toBeTruthy()
          expect(the_result.statusTask).toBeTruthy()

        waitsForPromise ->
          directory = new Directory path.join(__dirname, 'fixtures/git/master.git/objects')
          provider.repositoryForDirectory(directory).then (result) -> the_second_result = result

        runs ->
          expect(the_second_result).toBeInstanceOf GitRepository
          expect(the_second_result).toBe the_result

    describe "when specified a Directory without a Git repository", ->
      provider = new GitRepositoryProvider atom.project
      the_result = 'dummy_value'

      it "returns a Promise that resolves to null", ->
        waitsForPromise ->
          directory = new Directory '/tmp'
          provider.repositoryForDirectory(directory).then (result) -> the_result = result

      runs ->
        expect(the_result).toBe null
