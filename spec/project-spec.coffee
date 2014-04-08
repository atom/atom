temp = require 'temp'
fstream = require 'fstream'
Project = require '../src/project'
_ = require 'underscore-plus'
fs = require 'fs-plus'
path = require 'path'
platform = require './spec-helper-platform'
BufferedProcess = require '../src/buffered-process'

describe "Project", ->
  beforeEach ->
    atom.project.setPath(atom.project.resolve('dir'))

  describe "serialization", ->
    deserializedProject = null

    afterEach ->
      deserializedProject?.destroy()

    it "does not include unretained buffers in the serialized state", ->
      atom.project.bufferForPathSync('a')
      expect(atom.project.getBuffers().length).toBe 1

      deserializedProject = atom.project.testSerialization()
      expect(deserializedProject.getBuffers().length).toBe 0

    it "listens for destroyed events on deserialized buffers and removes them when they are destroyed", ->
      atom.project.openSync('a')
      expect(atom.project.getBuffers().length).toBe 1
      deserializedProject = atom.project.testSerialization()

      expect(deserializedProject.getBuffers().length).toBe 1
      deserializedProject.getBuffers()[0].destroy()
      expect(deserializedProject.getBuffers().length).toBe 0

  describe "when an edit session is destroyed", ->
    it "removes edit session and calls destroy on buffer (if buffer is not referenced by other edit sessions)", ->
      editor = atom.project.openSync("a")
      anotherEditor = atom.project.openSync("a")

      expect(atom.project.editors.length).toBe 2
      expect(editor.buffer).toBe anotherEditor.buffer

      editor.destroy()
      expect(atom.project.editors.length).toBe 1

      anotherEditor.destroy()
      expect(atom.project.editors.length).toBe 0

  describe "when an edit session is saved and the project has no path", ->
    it "sets the project's path to the saved file's parent directory", ->
      tempFile = temp.openSync().path
      atom.project.setPath(undefined)
      expect(atom.project.getPath()).toBeUndefined()
      editor = atom.project.openSync()
      editor.saveAs(tempFile)
      expect(atom.project.getPath()).toBe path.dirname(tempFile)

  describe "when an edit session is copied", ->
    it "emits an 'editor-created' event and stores the edit session", ->
      handler = jasmine.createSpy('editorCreatedHandler')
      atom.project.on 'editor-created', handler

      editor1 = atom.project.openSync("a")
      expect(handler.callCount).toBe 1
      expect(atom.project.getEditors().length).toBe 1
      expect(atom.project.getEditors()[0]).toBe editor1

      editor2 = editor1.copy()
      expect(handler.callCount).toBe 2
      expect(atom.project.getEditors().length).toBe 2
      expect(atom.project.getEditors()[0]).toBe editor1
      expect(atom.project.getEditors()[1]).toBe editor2

  describe ".openSync(path)", ->
    [absolutePath, newBufferHandler, newEditorHandler] = []
    beforeEach ->
      absolutePath = require.resolve('./fixtures/dir/a')
      newBufferHandler = jasmine.createSpy('newBufferHandler')
      atom.project.on 'buffer-created', newBufferHandler
      newEditorHandler = jasmine.createSpy('newEditorHandler')
      atom.project.on 'editor-created', newEditorHandler

    describe "when given an absolute path that hasn't been opened previously", ->
      it "returns a new edit session for the given path and emits 'buffer-created' and 'editor-created' events", ->
        editor = atom.project.openSync(absolutePath)
        expect(editor.buffer.getPath()).toBe absolutePath
        expect(newBufferHandler).toHaveBeenCalledWith editor.buffer
        expect(newEditorHandler).toHaveBeenCalledWith editor

    describe "when given a relative path that hasn't been opened previously", ->
      it "returns a new edit session for the given path (relative to the project root) and emits 'buffer-created' and 'editor-created' events", ->
        editor = atom.project.openSync('a')
        expect(editor.buffer.getPath()).toBe absolutePath
        expect(newBufferHandler).toHaveBeenCalledWith editor.buffer
        expect(newEditorHandler).toHaveBeenCalledWith editor

    describe "when passed the path to a buffer that has already been opened", ->
      it "returns a new edit session containing previously opened buffer and emits a 'editor-created' event", ->
        editor = atom.project.openSync(absolutePath)
        newBufferHandler.reset()
        expect(atom.project.openSync(absolutePath).buffer).toBe editor.buffer
        expect(atom.project.openSync('a').buffer).toBe editor.buffer
        expect(newBufferHandler).not.toHaveBeenCalled()
        expect(newEditorHandler).toHaveBeenCalledWith editor

    describe "when not passed a path", ->
      it "returns a new edit session and emits 'buffer-created' and 'editor-created' events", ->
        editor = atom.project.openSync()
        expect(editor.buffer.getPath()).toBeUndefined()
        expect(newBufferHandler).toHaveBeenCalledWith(editor.buffer)
        expect(newEditorHandler).toHaveBeenCalledWith editor

  describe ".open(path)", ->
    [absolutePath, newBufferHandler, newEditorHandler] = []

    beforeEach ->
      absolutePath = require.resolve('./fixtures/dir/a')
      newBufferHandler = jasmine.createSpy('newBufferHandler')
      atom.project.on 'buffer-created', newBufferHandler
      newEditorHandler = jasmine.createSpy('newEditorHandler')
      atom.project.on 'editor-created', newEditorHandler

    describe "when given an absolute path that isn't currently open", ->
      it "returns a new edit session for the given path and emits 'buffer-created' and 'editor-created' events", ->
        editor = null
        waitsForPromise ->
          atom.project.open(absolutePath).then (o) -> editor = o

        runs ->
          expect(editor.buffer.getPath()).toBe absolutePath
          expect(newBufferHandler).toHaveBeenCalledWith editor.buffer
          expect(newEditorHandler).toHaveBeenCalledWith editor

    describe "when given a relative path that isn't currently opened", ->
      it "returns a new edit session for the given path (relative to the project root) and emits 'buffer-created' and 'editor-created' events", ->
        editor = null
        waitsForPromise ->
          atom.project.open(absolutePath).then (o) -> editor = o

        runs ->
          expect(editor.buffer.getPath()).toBe absolutePath
          expect(newBufferHandler).toHaveBeenCalledWith editor.buffer
          expect(newEditorHandler).toHaveBeenCalledWith editor

    describe "when passed the path to a buffer that is currently opened", ->
      it "returns a new edit session containing currently opened buffer and emits a 'editor-created' event", ->
        editor = null
        waitsForPromise ->
          atom.project.open(absolutePath).then (o) -> editor = o

        runs ->
          newBufferHandler.reset()
          expect(atom.project.openSync(absolutePath).buffer).toBe editor.buffer
          expect(atom.project.openSync('a').buffer).toBe editor.buffer
          expect(newBufferHandler).not.toHaveBeenCalled()
          expect(newEditorHandler).toHaveBeenCalledWith editor

    describe "when not passed a path", ->
      it "returns a new edit session and emits 'buffer-created' and 'editor-created' events", ->
        editor = null
        waitsForPromise ->
          atom.project.open().then (o) -> editor = o

        runs ->
          expect(editor.buffer.getPath()).toBeUndefined()
          expect(newBufferHandler).toHaveBeenCalledWith(editor.buffer)
          expect(newEditorHandler).toHaveBeenCalledWith editor

    it "returns number of read bytes as progress indicator", ->
      filePath = atom.project.resolve 'a'
      totalBytes = 0
      promise = atom.project.open(filePath)
      promise.progress (bytesRead) -> totalBytes = bytesRead

      waitsForPromise ->
        promise

      runs ->
        expect(totalBytes).toBe fs.statSync(filePath).size

  describe ".bufferForPathSync(path)", ->
    describe "when opening a previously opened path", ->
      it "does not create a new buffer", ->
        buffer = atom.project.bufferForPathSync("a").retain()
        expect(atom.project.bufferForPathSync("a")).toBe buffer

        alternativeBuffer = atom.project.bufferForPathSync("b").retain().release()
        expect(alternativeBuffer).not.toBe buffer
        buffer.release()

      it "creates a new buffer if the previous buffer was destroyed", ->
        buffer = atom.project.bufferForPathSync("a").retain().release()
        expect(atom.project.bufferForPathSync("a").retain().release()).not.toBe buffer

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

  describe ".resolve(uri)", ->
    describe "when passed an absolute or relative path", ->
      it "returns an absolute path based on the atom.project's root", ->
        absolutePath = require.resolve('./fixtures/dir/a')
        expect(atom.project.resolve('a')).toBe absolutePath
        expect(atom.project.resolve(absolutePath + '/../a')).toBe absolutePath
        expect(atom.project.resolve('a/../a')).toBe absolutePath

    describe "when passed a uri with a scheme", ->
      it "does not modify uris that begin with a scheme", ->
        expect(atom.project.resolve('http://zombo.com')).toBe 'http://zombo.com'

  describe ".setPath(path)", ->
    describe "when path is a file", ->
      it "sets its path to the files parent directory and updates the root directory", ->
        atom.project.setPath(require.resolve('./fixtures/dir/a'))
        expect(atom.project.getPath()).toEqual path.dirname(require.resolve('./fixtures/dir/a'))
        expect(atom.project.getRootDirectory().path).toEqual path.dirname(require.resolve('./fixtures/dir/a'))

    describe "when path is a directory", ->
      it "sets its path to the directory and updates the root directory", ->
        directory = fs.absolute(path.join(__dirname, 'fixtures', 'dir', 'a-dir'))
        atom.project.setPath(directory)
        expect(atom.project.getPath()).toEqual directory
        expect(atom.project.getRootDirectory().path).toEqual directory

    describe "when path is null", ->
      it "sets its path and root directory to null", ->
        atom.project.setPath(null)
        expect(atom.project.getPath()?).toBeFalsy()
        expect(atom.project.getRootDirectory()?).toBeFalsy()

  describe ".replace()", ->
    [filePath, commentFilePath, sampleContent, sampleCommentContent] = []

    beforeEach ->
      atom.project.setPath(atom.project.resolve('../'))

      filePath = atom.project.resolve('sample.js')
      commentFilePath = atom.project.resolve('sample-with-comments.js')
      sampleContent = fs.readFileSync(filePath).toString()
      sampleCommentContent = fs.readFileSync(commentFilePath).toString()

    afterEach ->
      fs.writeFileSync(filePath, sampleContent)
      fs.writeFileSync(commentFilePath, sampleCommentContent)

    describe "when called with unopened files", ->
      it "replaces properly", ->
        results = []
        waitsForPromise ->
          atom.project.replace /items/gi, 'items', [filePath], (result) ->
            results.push(result)

        runs ->
          expect(results).toHaveLength 1
          expect(results[0].filePath).toBe filePath
          expect(results[0].replacements).toBe 6

    describe "when a buffer is already open", ->
      it "replaces properly and saves when not modified", ->
        editor = atom.project.openSync('sample.js')
        expect(editor.isModified()).toBeFalsy()

        results = []
        waitsForPromise ->
          atom.project.replace /items/gi, 'items', [filePath], (result) ->
            results.push(result)

        runs ->
          expect(results).toHaveLength 1
          expect(results[0].filePath).toBe filePath
          expect(results[0].replacements).toBe 6

          expect(editor.isModified()).toBeFalsy()

      it "does not replace when the path is not specified", ->
        editor = atom.project.openSync('sample.js')
        editor = atom.project.openSync('sample-with-comments.js')

        results = []
        waitsForPromise ->
          atom.project.replace /items/gi, 'items', [commentFilePath], (result) ->
            results.push(result)

        runs ->
          expect(results).toHaveLength 1
          expect(results[0].filePath).toBe commentFilePath

      it "does NOT save when modified", ->
        editor = atom.project.openSync('sample.js')
        editor.buffer.change([[0,0],[0,0]], 'omg')
        expect(editor.isModified()).toBeTruthy()

        results = []
        waitsForPromise ->
          atom.project.replace /items/gi, 'okthen', [filePath], (result) ->
            results.push(result)

        runs ->
          expect(results).toHaveLength 1
          expect(results[0].filePath).toBe filePath
          expect(results[0].replacements).toBe 6

          expect(editor.isModified()).toBeTruthy()

  describe ".scan(options, callback)", ->
    describe "when called with a regex", ->
      it "calls the callback with all regex results in all files in the project", ->
        results = []
        waitsForPromise ->
          atom.project.scan /(a)+/, (result) ->
            results.push(result)

        runs ->
          expect(results).toHaveLength(3)
          expect(results[0].filePath).toBe atom.project.resolve('a')
          expect(results[0].matches).toHaveLength(3)
          expect(results[0].matches[0]).toEqual
            matchText: 'aaa'
            lineText: 'aaa bbb'
            lineTextOffset: 0
            range: [[0, 0], [0, 3]]

      it "works with with escaped literals (like $ and ^)", ->
        results = []
        waitsForPromise ->
          atom.project.scan /\$\w+/, (result) -> results.push(result)

        runs ->
          expect(results.length).toBe 1

          {filePath, matches} = results[0]
          expect(filePath).toBe atom.project.resolve('a')
          expect(matches).toHaveLength 1
          expect(matches[0]).toEqual
            matchText: '$bill'
            lineText: 'dollar$bill'
            lineTextOffset: 0
            range: [[2, 6], [2, 11]]

      it "works on evil filenames", ->
        platform.generateEvilFiles()
        atom.project.setPath(path.join(__dirname, 'fixtures', 'evil-files'))
        paths = []
        matches = []
        waitsForPromise ->
          atom.project.scan /evil/, (result) ->
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
          atom.project.scan /DOLLAR/i, (result) -> results.push(result)

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
            fs.writeFileSync(ignoredPath, 'this match should not be included')

        afterEach ->
          fs.removeSync(projectPath) if fs.existsSync(projectPath)

        it "excludes ignored files", ->
          atom.project.setPath(projectPath)
          atom.config.set('core.excludeVcsIgnoredPaths', true)
          resultHandler = jasmine.createSpy("result found")
          waitsForPromise ->
            atom.project.scan /match/, (results) ->
              resultHandler()

          runs ->
            expect(resultHandler).not.toHaveBeenCalled()

      it "includes only files when a directory filter is specified", ->
        projectPath = path.join(path.join(__dirname, 'fixtures', 'dir'))
        atom.project.setPath(projectPath)

        filePath = path.join(projectPath, 'a-dir', 'oh-git')

        paths = []
        matches = []
        waitsForPromise ->
          atom.project.scan /aaa/, paths: ["a-dir#{path.sep}"], (result) ->
            paths.push(result.filePath)
            matches = matches.concat(result.matches)

        runs ->
          expect(paths.length).toBe 1
          expect(paths[0]).toBe filePath
          expect(matches.length).toBe 1

      it "includes files and folders that begin with a '.'", ->
        projectPath = temp.mkdirSync()
        filePath = path.join(projectPath, '.text')
        fs.writeFileSync(filePath, 'match this')
        atom.project.setPath(projectPath)
        paths = []
        matches = []
        waitsForPromise ->
          atom.project.scan /match this/, (result) ->
            paths.push(result.filePath)
            matches = matches.concat(result.matches)

        runs ->
          expect(paths.length).toBe 1
          expect(paths[0]).toBe filePath
          expect(matches.length).toBe 1

      it "excludes values in core.ignoredNames", ->
        projectPath = path.join(__dirname, 'fixtures', 'git', 'working-dir')
        ignoredNames = atom.config.get("core.ignoredNames")
        ignoredNames.push("a")
        atom.config.set("core.ignoredNames", ignoredNames)

        resultHandler = jasmine.createSpy("result found")
        waitsForPromise ->
          atom.project.scan /dollar/, (results) ->
            resultHandler()

        runs ->
          expect(resultHandler).not.toHaveBeenCalled()

      it "scans buffer contents if the buffer is modified", ->
        editor = atom.project.openSync("a")
        editor.setText("Elephant")
        results = []
        waitsForPromise ->
          atom.project.scan /a|Elephant/, (result) -> results.push result

        runs ->
          expect(results).toHaveLength 3
          resultForA = _.find results, ({filePath}) -> path.basename(filePath) == 'a'
          expect(resultForA.matches).toHaveLength 1
          expect(resultForA.matches[0].matchText).toBe 'Elephant'

      it "ignores buffers outside the project", ->
        editor = atom.project.openSync(temp.openSync().path)
        editor.setText("Elephant")
        results = []
        waitsForPromise ->
          atom.project.scan /Elephant/, (result) -> results.push result

        runs ->
          expect(results).toHaveLength 0

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
