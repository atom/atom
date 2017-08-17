path = require 'path'
fs = require 'fs-plus'
temp = require('temp').track()
{Directory} = require 'pathwatcher'
GitRepository = require '../src/git-repository'
GitRepositoryProvider = require '../src/git-repository-provider'

describe "GitRepositoryProvider", ->
  provider = null

  beforeEach ->
    provider = new GitRepositoryProvider(atom.project, atom.config, atom.confirm)

  afterEach ->
    temp.cleanupSync()

  describe ".repositoryForDirectory(directory)", ->
    describe "when specified a Directory with a Git repository", ->
      it "returns a Promise that resolves to a GitRepository", ->
        waitsForPromise ->
          directory = new Directory path.join(__dirname, 'fixtures', 'git', 'master.git')
          provider.repositoryForDirectory(directory).then (result) ->
            expect(result).toBeInstanceOf GitRepository
            expect(provider.pathToRepository[result.getPath()]).toBeTruthy()
            expect(result.statusTask).toBeTruthy()
            expect(result.getType()).toBe 'git'

      it "returns the same GitRepository for different Directory objects in the same repo", ->
        firstRepo = null
        secondRepo = null

        waitsForPromise ->
          directory = new Directory path.join(__dirname, 'fixtures', 'git', 'master.git')
          provider.repositoryForDirectory(directory).then (result) -> firstRepo = result

        waitsForPromise ->
          directory = new Directory path.join(__dirname, 'fixtures', 'git', 'master.git', 'objects')
          provider.repositoryForDirectory(directory).then (result) -> secondRepo = result

        runs ->
          expect(firstRepo).toBeInstanceOf GitRepository
          expect(firstRepo).toBe secondRepo

    describe "when specified a Directory without a Git repository", ->
      it "returns a Promise that resolves to null", ->
        waitsForPromise ->
          directory = new Directory temp.mkdirSync('dir')
          provider.repositoryForDirectory(directory).then (result) ->
            expect(result).toBe null

    describe "when specified a Directory with an invalid Git repository", ->
      it "returns a Promise that resolves to null", ->
        waitsForPromise ->
          dirPath = temp.mkdirSync('dir')
          fs.writeFileSync(path.join(dirPath, '.git', 'objects'), '')
          fs.writeFileSync(path.join(dirPath, '.git', 'HEAD'), '')
          fs.writeFileSync(path.join(dirPath, '.git', 'refs'), '')

          directory = new Directory dirPath
          provider.repositoryForDirectory(directory).then (result) ->
            expect(result).toBe null

    describe "when specified a Directory with a valid gitfile-linked repository", ->
      it "returns a Promise that resolves to a GitRepository", ->
        waitsForPromise ->
          gitDirPath = path.join(__dirname, 'fixtures', 'git', 'master.git')
          workDirPath = temp.mkdirSync('git-workdir')
          fs.writeFileSync(path.join(workDirPath, '.git'), 'gitdir: ' + gitDirPath+'\n')

          directory = new Directory workDirPath
          provider.repositoryForDirectory(directory).then (result) ->
            expect(result).toBeInstanceOf GitRepository
            expect(provider.pathToRepository[result.getPath()]).toBeTruthy()
            expect(result.statusTask).toBeTruthy()
            expect(result.getType()).toBe 'git'

    describe "when specified a Directory without existsSync()", ->
      directory = null
      provider = null
      beforeEach ->
        # An implementation of Directory that does not implement existsSync().
        subdirectory = {}
        directory =
          getSubdirectory: ->
          isRoot: -> true
        spyOn(directory, "getSubdirectory").andReturn(subdirectory)

      it "returns null", ->
        repo = provider.repositoryForDirectorySync(directory)
        expect(repo).toBe null
        expect(directory.getSubdirectory).toHaveBeenCalledWith(".git")

      it "returns a Promise that resolves to null for the async implementation", ->
        waitsForPromise ->
          provider.repositoryForDirectory(directory).then (repo) ->
            expect(repo).toBe null
            expect(directory.getSubdirectory).toHaveBeenCalledWith(".git")
