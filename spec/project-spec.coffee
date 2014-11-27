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
    atom.project.setPaths([atom.project.resolve('dir')])

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
      filePath = atom.project.resolve 'a'
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

  describe ".resolve(uri)", ->
    describe "when passed an absolute or relative path", ->
      it "returns an absolute path based on the atom.project's root", ->
        absolutePath = require.resolve('./fixtures/dir/a')
        expect(atom.project.resolve('a')).toBe absolutePath
        expect(atom.project.resolve(absolutePath + '/../a')).toBe absolutePath
        expect(atom.project.resolve('a/../a')).toBe absolutePath
        expect(atom.project.resolve()).toBeUndefined()

    describe "when passed a uri with a scheme", ->
      it "does not modify uris that begin with a scheme", ->
        expect(atom.project.resolve('http://zombo.com')).toBe 'http://zombo.com'

    describe "when the project has no path", ->
      it "returns undefined for relative URIs", ->
        atom.project.setPaths([])
        expect(atom.project.resolve('test.txt')).toBeUndefined()
        expect(atom.project.resolve('http://github.com')).toBe 'http://github.com'
        absolutePath = fs.absolute(__dirname)
        expect(atom.project.resolve(absolutePath)).toBe absolutePath

  describe ".setPaths(path)", ->
    describe "when path is a file", ->
      it "sets its path to the files parent directory and updates the root directory", ->
        atom.project.setPaths([require.resolve('./fixtures/dir/a')])
        expect(atom.project.getPaths()[0]).toEqual path.dirname(require.resolve('./fixtures/dir/a'))
        expect(atom.project.getDirectories()[0].path).toEqual path.dirname(require.resolve('./fixtures/dir/a'))

    describe "when path is a directory", ->
      it "sets its path to the directory and updates the root directory", ->
        directory = fs.absolute(path.join(__dirname, 'fixtures', 'dir', 'a-dir'))
        atom.project.setPaths([directory])
        expect(atom.project.getPaths()[0]).toEqual directory
        expect(atom.project.getDirectories()[0].path).toEqual directory

    describe "when path is null", ->
      it "sets its path and root directory to null", ->
        atom.project.setPaths([])
        expect(atom.project.getPaths()[0]?).toBeFalsy()
        expect(atom.project.getDirectories()[0]?).toBeFalsy()

    it "normalizes the path to remove consecutive slashes, ., and .. segments", ->
      atom.project.setPaths(["#{require.resolve('./fixtures/dir/a')}#{path.sep}b#{path.sep}#{path.sep}.."])
      expect(atom.project.getPaths()[0]).toEqual path.dirname(require.resolve('./fixtures/dir/a'))
      expect(atom.project.getDirectories()[0].path).toEqual path.dirname(require.resolve('./fixtures/dir/a'))

  describe ".replace()", ->
    [filePath, commentFilePath, sampleContent, sampleCommentContent] = []

    beforeEach ->
      atom.project.setPaths([atom.project.resolve('../')])

      filePath = atom.project.resolve('sample.js')
      commentFilePath = atom.project.resolve('sample-with-comments.js')
      sampleContent = fs.readFileSync(filePath).toString()
      sampleCommentContent = fs.readFileSync(commentFilePath).toString()

    afterEach ->
      fs.writeFileSync(filePath, sampleContent)
      fs.writeFileSync(commentFilePath, sampleCommentContent)

    describe "when a file doesn't exist", ->
      it "calls back with an error", ->
        errors = []
        missingPath = path.resolve('/not-a-file.js')
        expect(fs.existsSync(missingPath)).toBeFalsy()

        waitsForPromise ->
          atom.project.replace /items/gi, 'items', [missingPath], (result, error) ->
            errors.push(error)

        runs ->
          expect(errors).toHaveLength 1
          expect(errors[0].path).toBe missingPath

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
        editor = null
        results = []

        waitsForPromise ->
          atom.project.open('sample.js').then (o) -> editor = o

        runs ->
          expect(editor.isModified()).toBeFalsy()

        waitsForPromise ->
          atom.project.replace /items/gi, 'items', [filePath], (result) ->
            results.push(result)

        runs ->
          expect(results).toHaveLength 1
          expect(results[0].filePath).toBe filePath
          expect(results[0].replacements).toBe 6

          expect(editor.isModified()).toBeFalsy()

      it "does not replace when the path is not specified", ->
        editor = null
        results = []

        waitsForPromise ->
          atom.project.open('sample-with-comments.js').then (o) -> editor = o

        waitsForPromise ->
          atom.project.replace /items/gi, 'items', [commentFilePath], (result) ->
            results.push(result)

        runs ->
          expect(results).toHaveLength 1
          expect(results[0].filePath).toBe commentFilePath

      it "does NOT save when modified", ->
        editor = null
        results = []

        waitsForPromise ->
          atom.project.open('sample.js').then (o) -> editor = o

        runs ->
          editor.buffer.setTextInRange([[0,0],[0,0]], 'omg')
          expect(editor.isModified()).toBeTruthy()

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
        atom.project.setPaths([path.join(__dirname, 'fixtures', 'evil-files')])
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
          atom.project.setPaths([projectPath])
          atom.config.set('core.excludeVcsIgnoredPaths', true)
          resultHandler = jasmine.createSpy("result found")
          waitsForPromise ->
            atom.project.scan /match/, (results) ->
              resultHandler()

          runs ->
            expect(resultHandler).not.toHaveBeenCalled()

      it "includes only files when a directory filter is specified", ->
        projectPath = path.join(path.join(__dirname, 'fixtures', 'dir'))
        atom.project.setPaths([projectPath])

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
        atom.project.setPaths([projectPath])
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
        editor = null
        results = []

        waitsForPromise ->
          atom.project.open('a').then (o) ->
            editor = o
            editor.setText("Elephant")

        waitsForPromise ->
          atom.project.scan /a|Elephant/, (result) -> results.push result

        runs ->
          expect(results).toHaveLength 3
          resultForA = _.find results, ({filePath}) -> path.basename(filePath) == 'a'
          expect(resultForA.matches).toHaveLength 1
          expect(resultForA.matches[0].matchText).toBe 'Elephant'

      it "ignores buffers outside the project", ->
        editor = null
        results = []

        waitsForPromise ->
          atom.project.open(temp.openSync().path).then (o) ->
            editor = o
            editor.setText("Elephant")

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
