temp = require 'temp'
fstream = require 'fstream'
Project = require '../src/project'
_ = require 'underscore-plus'
fs = require 'fs-plus'
path = require 'path'
BufferedProcess = require '../src/buffered-process'
{Directory} = require 'pathwatcher'
GitRepository = require '../src/git-repository'
temp = require "temp"
{ncp} = require "../build/node_modules/ncp"

describe "Project", ->
  beforeEach ->
    atom.project.setPaths([atom.project.getDirectories()[0]?.resolve('dir')])

  describe "serialization", ->
    deserializedProject = null

    afterEach ->
      deserializedProject?.destroy()

    it "does not include unretained buffers in the serialized state", ->
      waitsForPromise ->
        atom.project.bufferForPath('a')

      runs ->
        expect(atom.project.getBuffers().length).toBe 1
        deserializedProject = atom.project.testSerialization()
        expect(deserializedProject.getBuffers().length).toBe 0

    it "listens for destroyed events on deserialized buffers and removes them when they are destroyed", ->
      waitsForPromise ->
        atom.project.open('a')

      runs ->
        expect(atom.project.getBuffers().length).toBe 1
        deserializedProject = atom.project.testSerialization()

        expect(deserializedProject.getBuffers().length).toBe 1
        deserializedProject.getBuffers()[0].destroy()
        expect(deserializedProject.getBuffers().length).toBe 0


    it "does not deserialize buffers when their path is a directory that exists", ->
      pathToOpen = path.join(temp.mkdirSync(), 'file.txt')

      waitsForPromise ->
        atom.project.open(pathToOpen)

      runs ->
        expect(atom.project.getBuffers().length).toBe 1
        fs.mkdirSync(pathToOpen)
        deserializedProject = atom.project.testSerialization()
        expect(deserializedProject.getBuffers().length).toBe 0

    it "does not deserialize buffers when their path is inaccessible", ->
      pathToOpen = path.join(temp.mkdirSync(), 'file.txt')
      fs.writeFileSync(pathToOpen, '')

      waitsForPromise ->
        atom.project.open(pathToOpen)

      runs ->
        expect(atom.project.getBuffers().length).toBe 1
        fs.chmodSync(pathToOpen, '000')
        deserializedProject = atom.project.testSerialization()
        expect(deserializedProject.getBuffers().length).toBe 0

  describe "when an editor is saved and the project has no path", ->
    it "sets the project's path to the saved file's parent directory", ->
      tempFile = temp.openSync().path
      atom.project.setPaths([])
      expect(atom.project.getPaths()[0]).toBeUndefined()
      editor = null

      waitsForPromise ->
        atom.project.open().then (o) -> editor = o

      runs ->
        editor.saveAs(tempFile)
        expect(atom.project.getPaths()[0]).toBe path.dirname(tempFile)

  describe "when a watch error is thrown from the TextBuffer", ->
    editor = null
    beforeEach ->
      waitsForPromise ->
        atom.project.open(require.resolve('./fixtures/dir/a')).then (o) -> editor = o

    it "creates a warning notification", ->
      atom.notifications.onDidAddNotification noteSpy = jasmine.createSpy()

      error = new Error('SomeError')
      error.eventType = 'resurrect'
      editor.buffer.emitter.emit 'will-throw-watch-error',
        handle: jasmine.createSpy()
        error: error

      expect(noteSpy).toHaveBeenCalled()

      notification = noteSpy.mostRecentCall.args[0]
      expect(notification.getType()).toBe 'warning'
      expect(notification.getDetail()).toBe 'SomeError'
      expect(notification.getMessage()).toContain '`resurrect`'
      expect(notification.getMessage()).toContain 'fixtures/dir/a'

  describe ".open(path)", ->
    [absolutePath, newBufferHandler] = []

    beforeEach ->
      absolutePath = require.resolve('./fixtures/dir/a')
      newBufferHandler = jasmine.createSpy('newBufferHandler')
      atom.project.on 'buffer-created', newBufferHandler

    describe "when given an absolute path that isn't currently open", ->
      it "returns a new edit session for the given path and emits 'buffer-created'", ->
        editor = null
        waitsForPromise ->
          atom.project.open(absolutePath).then (o) -> editor = o

        runs ->
          expect(editor.buffer.getPath()).toBe absolutePath
          expect(newBufferHandler).toHaveBeenCalledWith editor.buffer

    describe "when given a relative path that isn't currently opened", ->
      it "returns a new edit session for the given path (relative to the project root) and emits 'buffer-created'", ->
        editor = null
        waitsForPromise ->
          atom.project.open(absolutePath).then (o) -> editor = o

        runs ->
          expect(editor.buffer.getPath()).toBe absolutePath
          expect(newBufferHandler).toHaveBeenCalledWith editor.buffer

    describe "when passed the path to a buffer that is currently opened", ->
      it "returns a new edit session containing currently opened buffer", ->
        editor = null

        waitsForPromise ->
          atom.project.open(absolutePath).then (o) -> editor = o

        runs ->
          newBufferHandler.reset()

        waitsForPromise ->
          atom.project.open(absolutePath).then ({buffer}) ->
            expect(buffer).toBe editor.buffer

        waitsForPromise ->
          atom.project.open('a').then ({buffer}) ->
            expect(buffer).toBe editor.buffer
            expect(newBufferHandler).not.toHaveBeenCalled()

    describe "when not passed a path", ->
      it "returns a new edit session and emits 'buffer-created'", ->
        editor = null
        waitsForPromise ->
          atom.project.open().then (o) -> editor = o

        runs ->
          expect(editor.buffer.getPath()).toBeUndefined()
          expect(newBufferHandler).toHaveBeenCalledWith(editor.buffer)

    it "returns number of read bytes as progress indicator", ->
      filePath = atom.project.getDirectories()[0]?.resolve 'a'
      totalBytes = 0
      promise = atom.project.open(filePath)
      promise.progress (bytesRead) -> totalBytes = bytesRead

      waitsForPromise ->
        promise

      runs ->
        expect(totalBytes).toBe fs.statSync(filePath).size

  describe ".bufferForPath(path)", ->
    [buffer] = []
    beforeEach ->
      waitsForPromise ->
        atom.project.bufferForPath("a").then (o) ->
          buffer = o
          buffer.retain()

    afterEach ->
      buffer.release()

    describe "when opening a previously opened path", ->
      it "does not create a new buffer", ->
        waitsForPromise ->
          atom.project.bufferForPath("a").then (anotherBuffer) ->
            expect(anotherBuffer).toBe buffer

        waitsForPromise ->
          atom.project.bufferForPath("b").then (anotherBuffer) ->
            expect(anotherBuffer).not.toBe buffer

      it "creates a new buffer if the previous buffer was destroyed", ->
        buffer.release()

        waitsForPromise ->
          atom.project.bufferForPath("b").then (anotherBuffer) ->
            expect(anotherBuffer).not.toBe buffer

  describe ".repositoryForDirectory(directory)", ->
    it "resolves to null when the directory does not have a repository", ->
      waitsForPromise ->
        directory = new Directory("/tmp")
        atom.project.repositoryForDirectory(directory).then (result) ->
          expect(result).toBeNull()
          expect(atom.project.repositoryProviders.length).toBeGreaterThan 0
          expect(atom.project.repositoryPromisesByPath.size).toBe 0

    it "resolves to a GitRepository and is cached when the given directory is a Git repo", ->
      waitsForPromise ->
        directory = new Directory(path.join(__dirname, '..'))
        promise = atom.project.repositoryForDirectory(directory)
        promise.then (result) ->
          expect(result).toBeInstanceOf GitRepository
          dirPath = directory.getRealPathSync()
          expect(result.getPath()).toBe path.join(dirPath, '.git')

          # Verify that the result is cached.
          expect(atom.project.repositoryForDirectory(directory)).toBe(promise)

  describe ".setPaths(path)", ->
    describe "when path is a file", ->
      it "sets its path to the files parent directory and updates the root directory", ->
        atom.project.setPaths([require.resolve('./fixtures/dir/a')])
        expect(atom.project.getPaths()[0]).toEqual path.dirname(require.resolve('./fixtures/dir/a'))
        expect(atom.project.getDirectories()[0].path).toEqual path.dirname(require.resolve('./fixtures/dir/a'))

    describe "when path is a directory", ->
      it "assigns the directories and repositories", ->
        directory1 = temp.mkdirSync("non-git-repo")
        directory2 = temp.mkdirSync("git-repo1")
        directory3 = temp.mkdirSync("git-repo2")

        waitsFor (done) ->
          ncp(
            fs.absolute(path.join(__dirname, 'fixtures', 'git', 'master.git')),
            path.join(directory2, ".git"),
            done
          )

        waitsFor (done) ->
          ncp(
            fs.absolute(path.join(__dirname, 'fixtures', 'git', 'master.git')),
            path.join(directory3, ".git"),
            done
          )

        runs ->
          atom.project.setPaths([directory1, directory2, directory3])

          [repo1, repo2, repo3] = atom.project.getRepositories()
          expect(repo1).toBeNull()
          expect(repo2.getShortHead()).toBe "master"
          expect(repo2.getPath()).toBe fs.realpathSync(path.join(directory2, ".git"))
          expect(repo3.getShortHead()).toBe "master"
          expect(repo3.getPath()).toBe fs.realpathSync(path.join(directory3, ".git"))

      it "calls callbacks registered with ::onDidChangePaths", ->
        onDidChangePathsSpy = jasmine.createSpy('onDidChangePaths spy')
        atom.project.onDidChangePaths(onDidChangePathsSpy)

        paths = [ temp.mkdirSync("dir1"), temp.mkdirSync("dir2") ]
        atom.project.setPaths(paths)

        expect(onDidChangePathsSpy.callCount).toBe 1
        expect(onDidChangePathsSpy.mostRecentCall.args[0]).toEqual(paths)

    describe "when path is null", ->
      it "sets its path and root directory to null", ->
        atom.project.setPaths([])
        expect(atom.project.getPaths()[0]?).toBeFalsy()
        expect(atom.project.getDirectories()[0]?).toBeFalsy()

    it "normalizes the path to remove consecutive slashes, ., and .. segments", ->
      atom.project.setPaths(["#{require.resolve('./fixtures/dir/a')}#{path.sep}b#{path.sep}#{path.sep}.."])
      expect(atom.project.getPaths()[0]).toEqual path.dirname(require.resolve('./fixtures/dir/a'))
      expect(atom.project.getDirectories()[0].path).toEqual path.dirname(require.resolve('./fixtures/dir/a'))

  describe ".addPath(path)", ->
    it "calls callbacks registered with ::onDidChangePaths", ->
      onDidChangePathsSpy = jasmine.createSpy('onDidChangePaths spy')
      atom.project.onDidChangePaths(onDidChangePathsSpy)

      [oldPath] = atom.project.getPaths()

      newPath = temp.mkdirSync("dir")
      atom.project.addPath(newPath)

      expect(onDidChangePathsSpy.callCount).toBe 1
      expect(onDidChangePathsSpy.mostRecentCall.args[0]).toEqual([oldPath, newPath])

    describe "when the project already has the path or one of its descendants", ->
      it "doesn't add it again", ->
        onDidChangePathsSpy = jasmine.createSpy('onDidChangePaths spy')
        atom.project.onDidChangePaths(onDidChangePathsSpy)

        [oldPath] = atom.project.getPaths()

        atom.project.addPath(oldPath)
        atom.project.addPath(path.join(oldPath, "some-file.txt"))
        atom.project.addPath(path.join(oldPath, "a-dir"))
        atom.project.addPath(path.join(oldPath, "a-dir", "oh-git"))

        expect(atom.project.getPaths()).toEqual([oldPath])
        expect(onDidChangePathsSpy).not.toHaveBeenCalled()

  describe ".relativize(path)", ->
    it "returns the path, relative to whichever root directory it is inside of", ->
      rootPath = atom.project.getPaths()[0]
      childPath = path.join(rootPath, "some", "child", "directory")
      expect(atom.project.relativize(childPath)).toBe path.join("some", "child", "directory")

    it "returns the given path if it is not in any of the root directories", ->
      randomPath = path.join("some", "random", "path")
      expect(atom.project.relativize(randomPath)).toBe randomPath

  describe ".contains(path)", ->
    it "returns whether or not the given path is in one of the root directories", ->
      rootPath = atom.project.getPaths()[0]
      childPath = path.join(rootPath, "some", "child", "directory")
      expect(atom.project.contains(childPath)).toBe true

      randomPath = path.join("some", "random", "path")
      expect(atom.project.contains(randomPath)).toBe false

  describe ".eachBuffer(callback)", ->
    beforeEach ->
      atom.project.bufferForPathSync('a')

    it "invokes the callback for existing buffer", ->
      count = 0
      count = 0
      callbackBuffer = null
      callback = (buffer) ->
        callbackBuffer = buffer
        count++
      atom.project.eachBuffer(callback)
      expect(count).toBe 1
      expect(callbackBuffer).toBe atom.project.getBuffers()[0]

    it "invokes the callback for new buffers", ->
      count = 0
      callbackBuffer = null
      callback = (buffer) ->
        callbackBuffer = buffer
        count++

      atom.project.eachBuffer(callback)
      count = 0
      callbackBuffer = null
      atom.project.bufferForPathSync(require.resolve('./fixtures/sample.txt'))
      expect(count).toBe 1
      expect(callbackBuffer).toBe atom.project.getBuffers()[1]
