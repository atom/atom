temp = require 'temp'
fstream = require 'fstream'
Project = require '../src/project'
{_, fs} = require 'atom'
path = require 'path'
platform = require './spec-helper-platform'
BufferedProcess = require '../src/buffered-process'

describe "Project", ->
  beforeEach ->
    project.setPath(project.resolve('dir'))

  describe "serialization", ->
    deserializedProject = null

    afterEach ->
      deserializedProject?.destroy()

    it "destroys unretained buffers and does not include them in the serialized state", ->
      project.bufferForPathSync('a')
      expect(project.getBuffers().length).toBe 1
      deserializedProject = deserialize(project.serialize())
      expect(deserializedProject.getBuffers().length).toBe 0
      expect(project.getBuffers().length).toBe 0

  describe "when an edit session is destroyed", ->
    it "removes edit session and calls destroy on buffer (if buffer is not referenced by other edit sessions)", ->
      editSession = project.openSync("a")
      anotherEditSession = project.openSync("a")

      expect(project.editSessions.length).toBe 2
      expect(editSession.buffer).toBe anotherEditSession.buffer

      editSession.destroy()
      expect(project.editSessions.length).toBe 1

      anotherEditSession.destroy()
      expect(project.editSessions.length).toBe 0

  describe "when an edit session is saved and the project has no path", ->
    it "sets the project's path to the saved file's parent directory", ->
      tempFile = temp.openSync().path
      project.setPath(undefined)
      expect(project.getPath()).toBeUndefined()
      editSession = project.openSync()
      editSession.saveAs(tempFile)
      expect(project.getPath()).toBe path.dirname(tempFile)

  describe "when an edit session is deserialized", ->
    it "emits an 'edit-session-created' event and stores the edit session", ->
      handler = jasmine.createSpy('editSessionCreatedHandler')
      project.on 'edit-session-created', handler

      editSession1 = project.openSync("a")
      expect(handler.callCount).toBe 1
      expect(project.getEditSessions().length).toBe 1
      expect(project.getEditSessions()[0]).toBe editSession1

      editSession2 = deserialize(editSession1.serialize())
      expect(handler.callCount).toBe 2
      expect(project.getEditSessions().length).toBe 2
      expect(project.getEditSessions()[0]).toBe editSession1
      expect(project.getEditSessions()[1]).toBe editSession2

  describe ".open(path)", ->
    [fooOpener, barOpener, absolutePath, newBufferHandler, newEditSessionHandler] = []
    beforeEach ->
      absolutePath = require.resolve('./fixtures/dir/a')
      newBufferHandler = jasmine.createSpy('newBufferHandler')
      project.on 'buffer-created', newBufferHandler
      newEditSessionHandler = jasmine.createSpy('newEditSessionHandler')
      project.on 'edit-session-created', newEditSessionHandler

      fooOpener = (pathToOpen, options) -> { foo: pathToOpen, options } if pathToOpen?.match(/\.foo/)
      barOpener = (pathToOpen) -> { bar: pathToOpen } if pathToOpen?.match(/^bar:\/\//)
      project.registerOpener(fooOpener)
      project.registerOpener(barOpener)

    afterEach ->
      project.unregisterOpener(fooOpener)
      project.unregisterOpener(barOpener)

    describe "when passed a path that doesn't match a custom opener", ->
      describe "when given an absolute path that hasn't been opened previously", ->
        it "returns a new edit session for the given path and emits 'buffer-created' and 'edit-session-created' events", ->
          editSession = project.openSync(absolutePath)
          expect(editSession.buffer.getPath()).toBe absolutePath
          expect(newBufferHandler).toHaveBeenCalledWith editSession.buffer
          expect(newEditSessionHandler).toHaveBeenCalledWith editSession

      describe "when given a relative path that hasn't been opened previously", ->
        it "returns a new edit session for the given path (relative to the project root) and emits 'buffer-created' and 'edit-session-created' events", ->
          editSession = project.openSync('a')
          expect(editSession.buffer.getPath()).toBe absolutePath
          expect(newBufferHandler).toHaveBeenCalledWith editSession.buffer
          expect(newEditSessionHandler).toHaveBeenCalledWith editSession

      describe "when passed the path to a buffer that has already been opened", ->
        it "returns a new edit session containing previously opened buffer and emits a 'edit-session-created' event", ->
          editSession = project.openSync(absolutePath)
          newBufferHandler.reset()
          expect(project.openSync(absolutePath).buffer).toBe editSession.buffer
          expect(project.openSync('a').buffer).toBe editSession.buffer
          expect(newBufferHandler).not.toHaveBeenCalled()
          expect(newEditSessionHandler).toHaveBeenCalledWith editSession

      describe "when not passed a path", ->
        it "returns a new edit session and emits 'buffer-created' and 'edit-session-created' events", ->
          editSession = project.openSync()
          expect(editSession.buffer.getPath()).toBeUndefined()
          expect(newBufferHandler).toHaveBeenCalledWith(editSession.buffer)
          expect(newEditSessionHandler).toHaveBeenCalledWith editSession

    describe "when passed a path that matches a custom opener", ->
      it "returns the resource returned by the custom opener", ->
        pathToOpen = project.resolve('a.foo')
        expect(project.openSync(pathToOpen, hey: "there")).toEqual { foo: pathToOpen, options: {hey: "there"} }
        expect(project.openSync("bar://baz")).toEqual { bar: "bar://baz" }

  describe ".openAsync(path)", ->
    [fooOpener, barOpener, absolutePath, newBufferHandler, newEditSessionHandler] = []

    beforeEach ->
      absolutePath = require.resolve('./fixtures/dir/a')
      newBufferHandler = jasmine.createSpy('newBufferHandler')
      project.on 'buffer-created', newBufferHandler
      newEditSessionHandler = jasmine.createSpy('newEditSessionHandler')
      project.on 'edit-session-created', newEditSessionHandler

      fooOpener = (pathToOpen, options) -> { foo: pathToOpen, options } if pathToOpen?.match(/\.foo/)
      barOpener = (pathToOpen) -> { bar: pathToOpen } if pathToOpen?.match(/^bar:\/\//)
      project.registerOpener(fooOpener)
      project.registerOpener(barOpener)

    afterEach ->
      project.unregisterOpener(fooOpener)
      project.unregisterOpener(barOpener)

    describe "when passed a path that doesn't match a custom opener", ->
      describe "when given an absolute path that isn't currently open", ->
        it "returns a new edit session for the given path and emits 'buffer-created' and 'edit-session-created' events", ->
          editSession = null
          waitsForPromise ->
            project.openAsync(absolutePath).then (o) -> editSession = o

          runs ->
            expect(editSession.buffer.getPath()).toBe absolutePath
            expect(newBufferHandler).toHaveBeenCalledWith editSession.buffer
            expect(newEditSessionHandler).toHaveBeenCalledWith editSession

      describe "when given a relative path that isn't currently opened", ->
        it "returns a new edit session for the given path (relative to the project root) and emits 'buffer-created' and 'edit-session-created' events", ->
          editSession = null
          waitsForPromise ->
            project.openAsync(absolutePath).then (o) -> editSession = o

          runs ->
            expect(editSession.buffer.getPath()).toBe absolutePath
            expect(newBufferHandler).toHaveBeenCalledWith editSession.buffer
            expect(newEditSessionHandler).toHaveBeenCalledWith editSession

      describe "when passed the path to a buffer that is currently opened", ->
        it "returns a new edit session containing currently opened buffer and emits a 'edit-session-created' event", ->
          editSession = null
          waitsForPromise ->
            project.openAsync(absolutePath).then (o) -> editSession = o

          runs ->
            newBufferHandler.reset()
            expect(project.openSync(absolutePath).buffer).toBe editSession.buffer
            expect(project.openSync('a').buffer).toBe editSession.buffer
            expect(newBufferHandler).not.toHaveBeenCalled()
            expect(newEditSessionHandler).toHaveBeenCalledWith editSession

      describe "when not passed a path", ->
        it "returns a new edit session and emits 'buffer-created' and 'edit-session-created' events", ->
          editSession = null
          waitsForPromise ->
            project.openAsync().then (o) -> editSession = o

          runs ->
            expect(editSession.buffer.getPath()).toBeUndefined()
            expect(newBufferHandler).toHaveBeenCalledWith(editSession.buffer)
            expect(newEditSessionHandler).toHaveBeenCalledWith editSession

    describe "when passed a path that matches a custom opener", ->
      it "returns the resource returned by the custom opener", ->
        waitsForPromise ->
          pathToOpen = project.resolve('a.foo')
          project.openAsync(pathToOpen, hey: "there").then (item) ->
            expect(item).toEqual { foo: pathToOpen, options: {hey: "there"} }

        waitsForPromise ->
          project.openAsync("bar://baz").then (item) ->
            expect(item).toEqual { bar: "bar://baz" }

    it "returns number of read bytes as progress indicator", ->
      filePath = project.resolve 'a'
      totalBytes = 0
      promise = project.openAsync(filePath)
      promise.progress (bytesRead) -> totalBytes = bytesRead

      waitsForPromise ->
        promise

      runs ->
        expect(totalBytes).toBe fs.statSync(filePath).size

  describe ".bufferForPathSync(path)", ->
    describe "when opening a previously opened path", ->
      it "does not create a new buffer", ->
        buffer = project.bufferForPathSync("a").retain()
        expect(project.bufferForPathSync("a")).toBe buffer

        alternativeBuffer = project.bufferForPathSync("b").retain().release()
        expect(alternativeBuffer).not.toBe buffer
        buffer.release()

      it "creates a new buffer if the previous buffer was destroyed", ->
        buffer = project.bufferForPathSync("a").retain().release()
        expect(project.bufferForPathSync("a").retain().release()).not.toBe buffer

  describe ".bufferForPathAsync(path)", ->
    [buffer] = []
    beforeEach ->
      waitsForPromise ->
        project.bufferForPathAsync("a").then (o) ->
          buffer = o
          buffer.retain()

    afterEach ->
      buffer.release()

    describe "when opening a previously opened path", ->
      it "does not create a new buffer", ->
        waitsForPromise ->
          project.bufferForPathAsync("a").then (anotherBuffer) ->
            expect(anotherBuffer).toBe buffer

        waitsForPromise ->
          project.bufferForPathAsync("b").then (anotherBuffer) ->
            expect(anotherBuffer).not.toBe buffer

      it "creates a new buffer if the previous buffer was destroyed", ->
        buffer.release()

        waitsForPromise ->
          project.bufferForPathAsync("b").then (anotherBuffer) ->
            expect(anotherBuffer).not.toBe buffer

  describe ".resolve(uri)", ->
    describe "when passed an absolute or relative path", ->
      it "returns an absolute path based on the project's root", ->
        absolutePath = require.resolve('./fixtures/dir/a')
        expect(project.resolve('a')).toBe absolutePath
        expect(project.resolve(absolutePath + '/../a')).toBe absolutePath
        expect(project.resolve('a/../a')).toBe absolutePath

    describe "when passed a uri with a scheme", ->
      it "does not modify uris that begin with a scheme", ->
        expect(project.resolve('http://zombo.com')).toBe 'http://zombo.com'

  describe ".setPath(path)", ->
    describe "when path is a file", ->
      it "sets its path to the files parent directory and updates the root directory", ->
        project.setPath(require.resolve('./fixtures/dir/a'))
        expect(project.getPath()).toEqual path.dirname(require.resolve('./fixtures/dir/a'))
        expect(project.getRootDirectory().path).toEqual path.dirname(require.resolve('./fixtures/dir/a'))

    describe "when path is a directory", ->
      it "sets its path to the directory and updates the root directory", ->
        directory = fs.absolute(path.join(__dirname, 'fixtures', 'dir', 'a-dir'))
        project.setPath(directory)
        expect(project.getPath()).toEqual directory
        expect(project.getRootDirectory().path).toEqual directory

    describe "when path is null", ->
      it "sets its path and root directory to null", ->
        project.setPath(null)
        expect(project.getPath()?).toBeFalsy()
        expect(project.getRootDirectory()?).toBeFalsy()

  describe ".scan(options, callback)", ->
    describe "when called with a regex", ->
      it "calls the callback with all regex results in all files in the project", ->
        results = []
        waitsForPromise ->
          project.scan /(a)+/, (result) ->
            results.push(result)

        runs ->
          expect(results).toHaveLength(3)
          expect(results[0].filePath).toBe project.resolve('a')
          expect(results[0].matches).toHaveLength(3)
          expect(results[0].matches[0]).toEqual
            matchText: 'aaa'
            lineText: 'aaa bbb'
            lineTextOffset: 0
            range: [[0, 0], [0, 3]]

      it "works with with escaped literals (like $ and ^)", ->
        results = []
        waitsForPromise ->
          project.scan /\$\w+/, (result) -> results.push(result)

        runs ->
          expect(results.length).toBe 1

          {filePath, matches} = results[0]
          expect(filePath).toBe project.resolve('a')
          expect(matches).toHaveLength 1
          expect(matches[0]).toEqual
            matchText: '$bill'
            lineText: 'dollar$bill'
            lineTextOffset: 0
            range: [[2, 6], [2, 11]]

      it "works on evil filenames", ->
        project.setPath(path.join(__dirname, 'fixtures', 'evil-files'))
        paths = []
        matches = []
        waitsForPromise ->
          project.scan /evil/, (result) ->
            paths.push(result.filePath)
            matches = matches.concat(result.matches)

        runs ->
          _.each(matches, (m) -> expect(m.matchText).toEqual 'evil')

          if platform.isWindows()
            expect(paths.length).toBe 3
            expect(paths[0]).toMatch /a_file_with_utf8.txt$/
            expect(paths[1]).toMatch /file with spaces.txt$/
            expect(path.basename(paths[2])).toBe "utfa\u0306.md"
          else
            expect(paths.length).toBe 5
            expect(paths[0]).toMatch /a_file_with_utf8.txt$/
            expect(paths[1]).toMatch /file with spaces.txt$/
            expect(paths[2]).toMatch /goddam\nnewlines$/m
            expect(paths[3]).toMatch /quote".txt$/m
            expect(path.basename(paths[4])).toBe "utfa\u0306.md"

      it "ignores case if the regex includes the `i` flag", ->
        results = []
        waitsForPromise ->
          project.scan /DOLLAR/i, (result) -> results.push(result)

        runs ->
          expect(results).toHaveLength 1

      describe "when the core.excludeVcsIgnoredPaths config is truthy", ->
        [projectPath, ignoredPath] = []

        beforeEach ->
          sourceProjectPath = path.join(__dirname, 'fixtures', 'git', 'working-dir')
          projectPath = path.join(temp.mkdirSync("atom"))

          writerStream = fstream.Writer(projectPath)
          fstream.Reader(sourceProjectPath).pipe(writerStream)

          waitsFor (done) ->
            writerStream.on 'close', done
            writerStream.on 'error', done

          runs ->
            fs.rename(path.join(projectPath, 'git.git'), path.join(projectPath, '.git'))
            ignoredPath = path.join(projectPath, 'ignored.txt')
            fs.writeSync(ignoredPath, 'this match should not be included')

        afterEach ->
          fs.remove(projectPath) if fs.exists(projectPath)

        it "excludes ignored files", ->
          project.setPath(projectPath)
          config.set('core.excludeVcsIgnoredPaths', true)
          resultHandler = jasmine.createSpy("result found")
          waitsForPromise ->
            project.scan /match/, (results) ->
              resultHandler()

          runs ->
            expect(resultHandler).not.toHaveBeenCalled()

      it "includes only files when a directory filter is specified", ->
        projectPath = path.join(path.join(__dirname, 'fixtures', 'dir'))
        project.setPath(projectPath)

        filePath = path.join(projectPath, 'a-dir', 'oh-git')

        paths = []
        matches = []
        waitsForPromise ->
          project.scan /aaa/, paths: ['a-dir/'], (result) ->
            paths.push(result.filePath)
            matches = matches.concat(result.matches)

        runs ->
          expect(paths.length).toBe 1
          expect(paths[0]).toBe filePath
          expect(matches.length).toBe 1

      it "includes files and folders that begin with a '.'", ->
        projectPath = temp.mkdirSync()
        filePath = path.join(projectPath, '.text')
        fs.writeSync(filePath, 'match this')
        project.setPath(projectPath)
        paths = []
        matches = []
        waitsForPromise ->
          project.scan /match this/, (result) ->
            paths.push(result.filePath)
            matches = matches.concat(result.matches)

        runs ->
          expect(paths.length).toBe 1
          expect(paths[0]).toBe filePath
          expect(matches.length).toBe 1

      it "excludes values in core.ignoredNames", ->
        projectPath = path.join(__dirname, 'fixtures', 'git', 'working-dir')
        ignoredNames = config.get("core.ignoredNames")
        ignoredNames.push("a")
        config.set("core.ignoredNames", ignoredNames)

        resultHandler = jasmine.createSpy("result found")
        waitsForPromise ->
          project.scan /dollar/, (results) ->
            console.log results
            resultHandler()

        runs ->
          expect(resultHandler).not.toHaveBeenCalled()
