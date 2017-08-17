temp = require('temp').track()
TextBuffer = require('text-buffer')
Project = require '../src/project'
fs = require 'fs-plus'
path = require 'path'
{Directory} = require 'pathwatcher'
GitRepository = require '../src/git-repository'

describe "Project", ->
  beforeEach ->
    atom.project.setPaths([atom.project.getDirectories()[0]?.resolve('dir')])

    # Wait for project's service consumers to be asynchronously added
    waits(1)

  afterEach ->
    temp.cleanupSync()

  describe "serialization", ->
    deserializedProject = null

    afterEach ->
      deserializedProject?.destroy()

    it "does not deserialize paths to non directories", ->
      deserializedProject = new Project({notificationManager: atom.notifications, packageManager: atom.packages, confirm: atom.confirm})
      state = atom.project.serialize()
      state.paths.push('/directory/that/does/not/exist')

      waitsForPromise ->
        deserializedProject.deserialize(state, atom.deserializers)

      runs ->
        expect(deserializedProject.getPaths()).toEqual(atom.project.getPaths())

    it "does not include unretained buffers in the serialized state", ->
      waitsForPromise ->
        atom.project.bufferForPath('a')

      runs ->
        expect(atom.project.getBuffers().length).toBe 1

        deserializedProject = new Project({notificationManager: atom.notifications, packageManager: atom.packages, confirm: atom.confirm})

      waitsForPromise ->
        deserializedProject.deserialize(atom.project.serialize({isUnloading: false}))

      runs ->
        expect(deserializedProject.getBuffers().length).toBe 0

    it "listens for destroyed events on deserialized buffers and removes them when they are destroyed", ->
      waitsForPromise ->
        atom.workspace.open('a')

      runs ->
        expect(atom.project.getBuffers().length).toBe 1
        deserializedProject = new Project({notificationManager: atom.notifications, packageManager: atom.packages, confirm: atom.confirm})

      waitsForPromise ->
        deserializedProject.deserialize(atom.project.serialize({isUnloading: false}))

      runs ->
        expect(deserializedProject.getBuffers().length).toBe 1
        deserializedProject.getBuffers()[0].destroy()
        expect(deserializedProject.getBuffers().length).toBe 0

    it "does not deserialize buffers when their path is a directory that exists", ->
      pathToOpen = path.join(temp.mkdirSync('atom-spec-project'), 'file.txt')

      waitsForPromise ->
        atom.workspace.open(pathToOpen)

      runs ->
        expect(atom.project.getBuffers().length).toBe 1
        fs.mkdirSync(pathToOpen)
        deserializedProject = new Project({notificationManager: atom.notifications, packageManager: atom.packages, confirm: atom.confirm})
        deserializedProject.deserialize(atom.project.serialize({isUnloading: false}))
        expect(deserializedProject.getBuffers().length).toBe 0

    it "does not deserialize buffers when their path is inaccessible", ->
      return if process.platform is 'win32' # chmod not supported on win32
      pathToOpen = path.join(temp.mkdirSync('atom-spec-project'), 'file.txt')
      fs.writeFileSync(pathToOpen, '')

      waitsForPromise ->
        atom.workspace.open(pathToOpen)

      runs ->
        expect(atom.project.getBuffers().length).toBe 1
        fs.chmodSync(pathToOpen, '000')
        deserializedProject = new Project({notificationManager: atom.notifications, packageManager: atom.packages, confirm: atom.confirm})
        deserializedProject.deserialize(atom.project.serialize({isUnloading: false}))
        expect(deserializedProject.getBuffers().length).toBe 0

    it "serializes marker layers and history only if Atom is quitting", ->
      waitsForPromise ->
        atom.workspace.open('a')

      bufferA = null
      layerA = null
      markerA = null

      runs ->
        bufferA = atom.project.getBuffers()[0]
        layerA = bufferA.addMarkerLayer(persistent: true)
        markerA = layerA.markPosition([0, 3])
        bufferA.append('!')

      waitsForPromise ->
        notQuittingProject = new Project({notificationManager: atom.notifications, packageManager: atom.packages, confirm: atom.confirm})
        notQuittingProject.deserialize(atom.project.serialize({isUnloading: false})).then ->
          expect(notQuittingProject.getBuffers()[0].getMarkerLayer(layerA.id)?.getMarker(markerA.id)).toBeUndefined()
          expect(notQuittingProject.getBuffers()[0].undo()).toBe(false)

      waitsForPromise ->
        quittingProject = new Project({notificationManager: atom.notifications, packageManager: atom.packages, confirm: atom.confirm})
        quittingProject.deserialize(atom.project.serialize({isUnloading: true})).then ->
          expect(quittingProject.getBuffers()[0].getMarkerLayer(layerA.id)?.getMarker(markerA.id)).not.toBeUndefined()
          expect(quittingProject.getBuffers()[0].undo()).toBe(true)

  describe "when an editor is saved and the project has no path", ->
    it "sets the project's path to the saved file's parent directory", ->
      tempFile = temp.openSync().path
      atom.project.setPaths([])
      expect(atom.project.getPaths()[0]).toBeUndefined()
      editor = null

      waitsForPromise ->
        atom.workspace.open().then (o) -> editor = o

      waitsForPromise ->
        editor.saveAs(tempFile)

      runs ->
        expect(atom.project.getPaths()[0]).toBe path.dirname(tempFile)

  describe "before and after saving a buffer", ->
    [buffer] = []
    beforeEach ->
      waitsForPromise ->
        atom.project.bufferForPath(path.join(__dirname, 'fixtures', 'sample.js')).then (o) ->
          buffer = o
          buffer.retain()

    afterEach ->
      buffer.release()

    it "emits save events on the main process", ->
      spyOn(atom.project.applicationDelegate, 'emitDidSavePath')
      spyOn(atom.project.applicationDelegate, 'emitWillSavePath')

      waitsForPromise -> buffer.save()

      runs ->
        expect(atom.project.applicationDelegate.emitDidSavePath.calls.length).toBe(1)
        expect(atom.project.applicationDelegate.emitDidSavePath).toHaveBeenCalledWith(buffer.getPath())
        expect(atom.project.applicationDelegate.emitWillSavePath.calls.length).toBe(1)
        expect(atom.project.applicationDelegate.emitWillSavePath).toHaveBeenCalledWith(buffer.getPath())

  describe "when a watch error is thrown from the TextBuffer", ->
    editor = null
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open(require.resolve('./fixtures/dir/a')).then (o) -> editor = o

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
      expect(notification.getMessage()).toContain path.join('fixtures', 'dir', 'a')

  describe "when a custom repository-provider service is provided", ->
    [fakeRepositoryProvider, fakeRepository] = []

    beforeEach ->
      fakeRepository = {destroy: -> null}
      fakeRepositoryProvider = {
        repositoryForDirectory: (directory) -> Promise.resolve(fakeRepository)
        repositoryForDirectorySync: (directory) -> fakeRepository
      }

    it "uses it to create repositories for any directories that need one", ->
      projectPath = temp.mkdirSync('atom-project')
      atom.project.setPaths([projectPath])
      expect(atom.project.getRepositories()).toEqual [null]

      atom.packages.serviceHub.provide("atom.repository-provider", "0.1.0", fakeRepositoryProvider)
      waitsFor -> atom.project.repositoryProviders.length > 1
      runs -> atom.project.getRepositories()[0] is fakeRepository

    it "does not create any new repositories if every directory has a repository", ->
      repositories = atom.project.getRepositories()
      expect(repositories.length).toEqual 1
      expect(repositories[0]).toBeTruthy()

      atom.packages.serviceHub.provide("atom.repository-provider", "0.1.0", fakeRepositoryProvider)
      waitsFor -> atom.project.repositoryProviders.length > 1
      runs -> expect(atom.project.getRepositories()).toBe repositories

    it "stops using it to create repositories when the service is removed", ->
      atom.project.setPaths([])

      disposable = atom.packages.serviceHub.provide("atom.repository-provider", "0.1.0", fakeRepositoryProvider)
      waitsFor -> atom.project.repositoryProviders.length > 1
      runs ->
        disposable.dispose()
        atom.project.addPath(temp.mkdirSync('atom-project'))
        expect(atom.project.getRepositories()).toEqual [null]

  describe "when a custom directory-provider service is provided", ->
    class DummyDirectory
      constructor: (@path) ->
      getPath: -> @path
      getFile: -> {existsSync: -> false}
      getSubdirectory: -> {existsSync: -> false}
      isRoot: -> true
      existsSync: -> @path.endsWith('does-exist')
      contains: (filePath) -> filePath.startsWith(@path)

    serviceDisposable = null

    beforeEach ->
      serviceDisposable = atom.packages.serviceHub.provide("atom.directory-provider", "0.1.0", {
        directoryForURISync: (uri) ->
          if uri.startsWith("ssh://")
            new DummyDirectory(uri)
          else
            null
      })

      waitsFor ->
        atom.project.directoryProviders.length > 0

    it "uses the provider's custom directories for any paths that it handles", ->
      localPath = temp.mkdirSync('local-path')
      remotePath = "ssh://foreign-directory:8080/does-exist"

      atom.project.setPaths([localPath, remotePath])

      directories = atom.project.getDirectories()
      expect(directories[0].getPath()).toBe localPath
      expect(directories[0] instanceof Directory).toBe true
      expect(directories[1].getPath()).toBe remotePath
      expect(directories[1] instanceof DummyDirectory).toBe true

      # It does not add new remote paths that do not exist
      nonExistentRemotePath = "ssh://another-directory:8080/does-not-exist"
      atom.project.addPath(nonExistentRemotePath)
      expect(atom.project.getDirectories().length).toBe 2

      # It adds new remote paths if their directories exist.
      newRemotePath = "ssh://another-directory:8080/does-exist"
      atom.project.addPath(newRemotePath)
      directories = atom.project.getDirectories()
      expect(directories[2].getPath()).toBe newRemotePath
      expect(directories[2] instanceof DummyDirectory).toBe true

    it "stops using the provider when the service is removed", ->
      serviceDisposable.dispose()
      atom.project.setPaths(["ssh://foreign-directory:8080/does-exist"])
      expect(atom.project.getDirectories().length).toBe(0)

  describe ".open(path)", ->
    [absolutePath, newBufferHandler] = []

    beforeEach ->
      absolutePath = require.resolve('./fixtures/dir/a')
      newBufferHandler = jasmine.createSpy('newBufferHandler')
      atom.project.onDidAddBuffer(newBufferHandler)

    describe "when given an absolute path that isn't currently open", ->
      it "returns a new edit session for the given path and emits 'buffer-created'", ->
        editor = null
        waitsForPromise ->
          atom.workspace.open(absolutePath).then (o) -> editor = o

        runs ->
          expect(editor.buffer.getPath()).toBe absolutePath
          expect(newBufferHandler).toHaveBeenCalledWith editor.buffer

    describe "when given a relative path that isn't currently opened", ->
      it "returns a new edit session for the given path (relative to the project root) and emits 'buffer-created'", ->
        editor = null
        waitsForPromise ->
          atom.workspace.open(absolutePath).then (o) -> editor = o

        runs ->
          expect(editor.buffer.getPath()).toBe absolutePath
          expect(newBufferHandler).toHaveBeenCalledWith editor.buffer

    describe "when passed the path to a buffer that is currently opened", ->
      it "returns a new edit session containing currently opened buffer", ->
        editor = null

        waitsForPromise ->
          atom.workspace.open(absolutePath).then (o) -> editor = o

        runs ->
          newBufferHandler.reset()

        waitsForPromise ->
          atom.workspace.open(absolutePath).then ({buffer}) ->
            expect(buffer).toBe editor.buffer

        waitsForPromise ->
          atom.workspace.open('a').then ({buffer}) ->
            expect(buffer).toBe editor.buffer
            expect(newBufferHandler).not.toHaveBeenCalled()

    describe "when not passed a path", ->
      it "returns a new edit session and emits 'buffer-created'", ->
        editor = null
        waitsForPromise ->
          atom.workspace.open().then (o) -> editor = o

        runs ->
          expect(editor.buffer.getPath()).toBeUndefined()
          expect(newBufferHandler).toHaveBeenCalledWith(editor.buffer)

  describe ".bufferForPath(path)", ->
    buffer = null

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

        waitsForPromise ->
          Promise.all([
            atom.project.bufferForPath('c'),
            atom.project.bufferForPath('c')
          ]).then ([buffer1, buffer2]) ->
            expect(buffer1).toBe(buffer2)

      it "retries loading the buffer if it previously failed", ->
        waitsForPromise shouldReject: true, ->
          spyOn(TextBuffer, 'load').andCallFake ->
            Promise.reject(new Error('Could not open file'))
          atom.project.bufferForPath('b')

        waitsForPromise shouldReject: false, ->
          TextBuffer.load.andCallThrough()
          atom.project.bufferForPath('b')

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

    it "creates a new repository if a previous one with the same directory had been destroyed", ->
      repository = null
      directory = new Directory(path.join(__dirname, '..'))

      waitsForPromise ->
        atom.project.repositoryForDirectory(directory).then (repo) -> repository = repo

      runs ->
        expect(repository.isDestroyed()).toBe(false)
        repository.destroy()
        expect(repository.isDestroyed()).toBe(true)

      waitsForPromise ->
        atom.project.repositoryForDirectory(directory).then (repo) -> repository = repo

      runs ->
        expect(repository.isDestroyed()).toBe(false)

  describe ".setPaths(paths)", ->
    describe "when path is a file", ->
      it "sets its path to the files parent directory and updates the root directory", ->
        filePath = require.resolve('./fixtures/dir/a')
        atom.project.setPaths([filePath])
        expect(atom.project.getPaths()[0]).toEqual path.dirname(filePath)
        expect(atom.project.getDirectories()[0].path).toEqual path.dirname(filePath)

    describe "when path is a directory", ->
      it "assigns the directories and repositories", ->
        directory1 = temp.mkdirSync("non-git-repo")
        directory2 = temp.mkdirSync("git-repo1")
        directory3 = temp.mkdirSync("git-repo2")

        gitDirPath = fs.absolute(path.join(__dirname, 'fixtures', 'git', 'master.git'))
        fs.copySync(gitDirPath, path.join(directory2, ".git"))
        fs.copySync(gitDirPath, path.join(directory3, ".git"))

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

    describe "when no paths are given", ->
      it "clears its path", ->
        atom.project.setPaths([])
        expect(atom.project.getPaths()).toEqual []
        expect(atom.project.getDirectories()).toEqual []

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

    it "doesn't add redundant paths", ->
      onDidChangePathsSpy = jasmine.createSpy('onDidChangePaths spy')
      atom.project.onDidChangePaths(onDidChangePathsSpy)
      [oldPath] = atom.project.getPaths()

      # Doesn't re-add an existing root directory
      atom.project.addPath(oldPath)
      expect(atom.project.getPaths()).toEqual([oldPath])
      expect(onDidChangePathsSpy).not.toHaveBeenCalled()

      # Doesn't add an entry for a file-path within an existing root directory
      atom.project.addPath(path.join(oldPath, 'some-file.txt'))
      expect(atom.project.getPaths()).toEqual([oldPath])
      expect(onDidChangePathsSpy).not.toHaveBeenCalled()

      # Does add an entry for a directory within an existing directory
      newPath = path.join(oldPath, "a-dir")
      atom.project.addPath(newPath)
      expect(atom.project.getPaths()).toEqual([oldPath, newPath])
      expect(onDidChangePathsSpy).toHaveBeenCalled()

    it "doesn't add non-existent directories", ->
      previousPaths = atom.project.getPaths()
      atom.project.addPath('/this-definitely/does-not-exist')
      expect(atom.project.getPaths()).toEqual(previousPaths)

  describe ".removePath(path)", ->
    onDidChangePathsSpy = null

    beforeEach ->
      onDidChangePathsSpy = jasmine.createSpy('onDidChangePaths listener')
      atom.project.onDidChangePaths(onDidChangePathsSpy)

    it "removes the directory and repository for the path", ->
      result = atom.project.removePath(atom.project.getPaths()[0])
      expect(atom.project.getDirectories()).toEqual([])
      expect(atom.project.getRepositories()).toEqual([])
      expect(atom.project.getPaths()).toEqual([])
      expect(result).toBe true
      expect(onDidChangePathsSpy).toHaveBeenCalled()

    it "does nothing if the path is not one of the project's root paths", ->
      originalPaths = atom.project.getPaths()
      result = atom.project.removePath(originalPaths[0] + "xyz")
      expect(result).toBe false
      expect(atom.project.getPaths()).toEqual(originalPaths)
      expect(onDidChangePathsSpy).not.toHaveBeenCalled()

    it "doesn't destroy the repository if it is shared by another root directory", ->
      atom.project.setPaths([__dirname, path.join(__dirname, "..", "src")])
      atom.project.removePath(__dirname)
      expect(atom.project.getPaths()).toEqual([path.join(__dirname, "..", "src")])
      expect(atom.project.getRepositories()[0].isSubmodule("src")).toBe false

    it "removes a path that is represented as a URI", ->
      atom.packages.serviceHub.provide("atom.directory-provider", "0.1.0", {
        directoryForURISync: (uri) ->
          {
            getPath: -> uri
            getSubdirectory: -> {}
            isRoot: -> true
            existsSync: -> true
            off: ->
          }
      })

      ftpURI = "ftp://example.com/some/folder"

      atom.project.setPaths([ftpURI])
      expect(atom.project.getPaths()).toEqual [ftpURI]

      atom.project.removePath(ftpURI)
      expect(atom.project.getPaths()).toEqual []

  describe ".onDidAddBuffer()", ->
    it "invokes the callback with added text buffers", ->
      buffers = []
      added = []

      waitsForPromise ->
        atom.project.buildBuffer(require.resolve('./fixtures/dir/a'))
          .then (o) -> buffers.push(o)

      runs ->
        expect(buffers.length).toBe 1
        atom.project.onDidAddBuffer (buffer) -> added.push(buffer)

      waitsForPromise ->
        atom.project.buildBuffer(require.resolve('./fixtures/dir/b'))
          .then (o) -> buffers.push(o)

      runs ->
        expect(buffers.length).toBe 2
        expect(added).toEqual [buffers[1]]

  describe ".observeBuffers()", ->
    it "invokes the observer with current and future text buffers", ->
      buffers = []
      observed = []

      waitsForPromise ->
        atom.project.buildBuffer(require.resolve('./fixtures/dir/a'))
          .then (o) -> buffers.push(o)

      waitsForPromise ->
        atom.project.buildBuffer(require.resolve('./fixtures/dir/b'))
          .then (o) -> buffers.push(o)

      runs ->
        expect(buffers.length).toBe 2
        atom.project.observeBuffers (buffer) -> observed.push(buffer)
        expect(observed).toEqual buffers

      waitsForPromise ->
        atom.project.buildBuffer(require.resolve('./fixtures/dir/b'))
          .then (o) -> buffers.push(o)

      runs ->
        expect(observed.length).toBe 3
        expect(buffers.length).toBe 3
        expect(observed).toEqual buffers

  describe ".relativize(path)", ->
    it "returns the path, relative to whichever root directory it is inside of", ->
      atom.project.addPath(temp.mkdirSync("another-path"))

      rootPath = atom.project.getPaths()[0]
      childPath = path.join(rootPath, "some", "child", "directory")
      expect(atom.project.relativize(childPath)).toBe path.join("some", "child", "directory")

      rootPath = atom.project.getPaths()[1]
      childPath = path.join(rootPath, "some", "child", "directory")
      expect(atom.project.relativize(childPath)).toBe path.join("some", "child", "directory")

    it "returns the given path if it is not in any of the root directories", ->
      randomPath = path.join("some", "random", "path")
      expect(atom.project.relativize(randomPath)).toBe randomPath

  describe ".relativizePath(path)", ->
    it "returns the root path that contains the given path, and the path relativized to that root path", ->
      atom.project.addPath(temp.mkdirSync("another-path"))

      rootPath = atom.project.getPaths()[0]
      childPath = path.join(rootPath, "some", "child", "directory")
      expect(atom.project.relativizePath(childPath)).toEqual [rootPath, path.join("some", "child", "directory")]

      rootPath = atom.project.getPaths()[1]
      childPath = path.join(rootPath, "some", "child", "directory")
      expect(atom.project.relativizePath(childPath)).toEqual [rootPath, path.join("some", "child", "directory")]

    describe "when the given path isn't inside of any of the project's path", ->
      it "returns null for the root path, and the given path unchanged", ->
        randomPath = path.join("some", "random", "path")
        expect(atom.project.relativizePath(randomPath)).toEqual [null, randomPath]

    describe "when the given path is a URL", ->
      it "returns null for the root path, and the given path unchanged", ->
        url = "http://the-path"
        expect(atom.project.relativizePath(url)).toEqual [null, url]

    describe "when the given path is inside more than one root folder", ->
      it "uses the root folder that is closest to the given path", ->
        atom.project.addPath(path.join(atom.project.getPaths()[0], 'a-dir'))

        inputPath = path.join(atom.project.getPaths()[1], 'somewhere/something.txt')

        expect(atom.project.getDirectories()[0].contains(inputPath)).toBe true
        expect(atom.project.getDirectories()[1].contains(inputPath)).toBe true
        expect(atom.project.relativizePath(inputPath)).toEqual [
          atom.project.getPaths()[1],
          path.join('somewhere', 'something.txt')
        ]

  describe ".contains(path)", ->
    it "returns whether or not the given path is in one of the root directories", ->
      rootPath = atom.project.getPaths()[0]
      childPath = path.join(rootPath, "some", "child", "directory")
      expect(atom.project.contains(childPath)).toBe true

      randomPath = path.join("some", "random", "path")
      expect(atom.project.contains(randomPath)).toBe false

  describe ".resolvePath(uri)", ->
    it "normalizes disk drive letter in passed path on #win32", ->
      expect(atom.project.resolvePath("d:\\file.txt")).toEqual "D:\\file.txt"
