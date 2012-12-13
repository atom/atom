Project = require 'project'
fs = require 'fs'

describe "Project", ->
  project = null
  beforeEach ->
    project = new Project(require.resolve('fixtures/dir'))

  afterEach ->
    project.destroy()

  describe "when editSession is destroyed", ->
    it "removes edit session and calls destroy on buffer (if buffer is not referenced by other edit sessions)", ->
      editSession = project.buildEditSessionForPath("a")
      anotherEditSession = project.buildEditSessionForPath("a")

      expect(project.editSessions.length).toBe 2
      expect(editSession.buffer).toBe anotherEditSession.buffer

      editSession.destroy()
      expect(project.editSessions.length).toBe 1

      anotherEditSession.destroy()
      expect(project.editSessions.length).toBe 0

  describe ".buildEditSessionForPath(path)", ->
    [absolutePath, newBufferHandler, newEditSessionHandler] = []
    beforeEach ->
      absolutePath = require.resolve('fixtures/dir/a')
      newBufferHandler = jasmine.createSpy('newBufferHandler')
      project.on 'new-buffer', newBufferHandler
      newEditSessionHandler = jasmine.createSpy('newEditSessionHandler')
      project.on 'new-edit-session', newEditSessionHandler

    describe "when given an absolute path that hasn't been opened previously", ->
      it "returns a new edit session for the given path and emits 'new-buffer' and 'new-edit-session' events", ->
        editSession = project.buildEditSessionForPath(absolutePath)
        expect(editSession.buffer.getPath()).toBe absolutePath
        expect(newBufferHandler).toHaveBeenCalledWith editSession.buffer
        expect(newEditSessionHandler).toHaveBeenCalledWith editSession

    describe "when given a relative path that hasn't been opened previously", ->
      it "returns a new edit session for the given path (relative to the project root) and emits 'new-buffer' and 'new-edit-session' events", ->
        editSession = project.buildEditSessionForPath('a')
        expect(editSession.buffer.getPath()).toBe absolutePath
        expect(newBufferHandler).toHaveBeenCalledWith editSession.buffer
        expect(newEditSessionHandler).toHaveBeenCalledWith editSession

    describe "when passed the path to a buffer that has already been opened", ->
      it "returns a new edit session containing previously opened buffer and emits a 'new-edit-session' event", ->
        editSession = project.buildEditSessionForPath(absolutePath)
        newBufferHandler.reset()
        expect(project.buildEditSessionForPath(absolutePath).buffer).toBe editSession.buffer
        expect(project.buildEditSessionForPath('a').buffer).toBe editSession.buffer
        expect(newBufferHandler).not.toHaveBeenCalled()
        expect(newEditSessionHandler).toHaveBeenCalledWith editSession

    describe "when not passed a path", ->
      it "returns a new edit session and emits 'new-buffer' and 'new-edit-session' events", ->
        editSession = project.buildEditSessionForPath()
        expect(editSession.buffer.getPath()).toBeUndefined()
        expect(newBufferHandler).toHaveBeenCalledWith(editSession.buffer)
        expect(newEditSessionHandler).toHaveBeenCalledWith editSession

  describe ".bufferForPath(path)", ->
    describe "when opening a previously opened path", ->
      it "does not create a new buffer", ->
        buffer = project.bufferForPath("a").retain()
        expect(project.bufferForPath("a")).toBe buffer

        alternativeBuffer = project.bufferForPath("b").retain().release()
        expect(alternativeBuffer).not.toBe buffer
        buffer.release()

      it "creates a new buffer if the previous buffer was destroyed", ->
        buffer = project.bufferForPath("a").retain().release()
        expect(project.bufferForPath("a").retain().release()).not.toBe buffer

  describe ".resolve(path)", ->
    it "returns an absolute path based on the project's root", ->
      absolutePath = require.resolve('fixtures/dir/a')
      expect(project.resolve('a')).toBe absolutePath
      expect(project.resolve(absolutePath + '/../a')).toBe absolutePath
      expect(project.resolve('a/../a')).toBe absolutePath

  describe ".relativize(path)", ->
    it "returns an relative path based on the project's root", ->
      absolutePath = require.resolve('fixtures/dir')
      expect(project.relativize(fs.join(absolutePath, "b"))).toBe "b"
      expect(project.relativize(fs.join(absolutePath, "b/file.coffee"))).toBe "b/file.coffee"
      expect(project.relativize(fs.join(absolutePath, "file.coffee"))).toBe "file.coffee"

  describe ".setPath(path)", ->
    describe "when path is a file", ->
      it "sets its path to the files parent directory and updates the root directory", ->
        project.setPath(require.resolve('fixtures/dir/a'))
        expect(project.getPath()).toEqual require.resolve('fixtures/dir')
        expect(project.getRootDirectory().path).toEqual require.resolve('fixtures/dir')

    describe "when path is a directory", ->
      it "sets its path to the directory and updates the root directory", ->
        project.setPath(require.resolve('fixtures/dir/a-dir'))
        expect(project.getPath()).toEqual require.resolve('fixtures/dir/a-dir')
        expect(project.getRootDirectory().path).toEqual require.resolve('fixtures/dir/a-dir')

    describe "when path is null", ->
      it "sets its path and root directory to null", ->
        project.setPath(null)
        expect(project.getPath()?).toBeFalsy()
        expect(project.getRootDirectory()?).toBeFalsy()

  describe ".getFilePaths()", ->
    it "asynchronously returns file paths using a promise", ->
      paths = null
      waitsForPromise ->
        project.getFilePaths().done (foundPaths) -> paths = foundPaths

      runs ->
        expect(paths.length).toBeGreaterThan 0

    it "ignores files that return true from atom.ignorePath(path)", ->
      spyOn(project, 'isPathIgnored').andCallFake (path) -> fs.base(path).match /a$/

      paths = null
      waitsForPromise ->
        project.getFilePaths().done (foundPaths) -> paths = foundPaths

      runs ->
        expect(paths).not.toContain('a')
        expect(paths).toContain('b')

    it "ignores files in gitignore for projects in a git tree", ->
      project.setHideIgnoredFiles(true)
      project.setPath(require.resolve('fixtures/git/working-dir'))
      paths = null
      waitsForPromise ->
        project.getFilePaths().done (foundPaths) -> paths = foundPaths

      runs ->
        expect(paths).not.toContain('ignored.txt')

  describe ".scan(options, callback)", ->
    describe "when called with a regex", ->
      it "calls the callback with all regex matches in all files in the project", ->
        matches = []
        waitsForPromise ->
          project.scan /(a)+/, ({path, match, range}) ->
            matches.push({path, match, range})

        runs ->
          expect(matches[0]).toEqual
            path: project.resolve('a')
            match: 'aaa'
            range: [[0, 0], [0, 3]]

          expect(matches[1]).toEqual
            path: project.resolve('a')
            match: 'aa'
            range: [[1, 3], [1, 5]]

      it "works with with escaped literals (like $ and ^)", ->
        matches = []
        waitsForPromise ->
          project.scan /\$\w+/, ({path, match, range}) ->
            matches.push({path, match, range})

        runs ->
          expect(matches.length).toBe 1

          expect(matches[0]).toEqual
            path: project.resolve('a')
            match: '$bill'
            range: [[2, 6], [2, 11]]

      it "works on evil filenames", ->
        project.setPath(require.resolve('fixtures/evil-files'))
        paths = []
        matches = []
        waitsForPromise ->
          project.scan /evil/, ({path, match, range}) ->
            paths.push(path)
            matches.push(match)

        runs ->
          expect(paths.length).toBe 5
          matches.forEach (match) -> expect(match).toEqual 'evil'
          expect(paths[0]).toMatch /a_file_with_utf8.txt$/
          expect(paths[1]).toMatch /file with spaces.txt$/
          expect(paths[2]).toMatch /goddam\nnewlines$/m
          expect(paths[3]).toMatch /quote".txt$/m
          expect(fs.base(paths[4])).toBe "utfa\u0306.md"

      it "handles breaks in the search subprocess's output following the filename", ->
        spyOn $native, 'exec'

        iterator = jasmine.createSpy('iterator')
        project.scan /a+/, iterator

        stdout = $native.exec.argsForCall[0][1].stdout
        stdout ":#{require.resolve('fixtures/dir/a')}\n"
        stdout "1;0 3:aaa bbb\n2;3 2:cc aa cc\n"

        expect(iterator.argsForCall[0][0]).toEqual
          path: project.resolve('a')
          match: 'aaa'
          range: [[0, 0], [0, 3]]

        expect(iterator.argsForCall[1][0]).toEqual
          path: project.resolve('a')
          match: 'aa'
          range: [[1, 3], [1, 5]]

    describe "hiding ignored files", ->
      it "defaults @hideIgnoredFiles to false", ->
        expect(project.getHideIgnoredFiles()).toBe(false)

      it "implements a setter for the @hideIgnoredFiles option", ->
        project.setHideIgnoredFiles(true)
        expect(project.getHideIgnoredFiles()).toBe(true)
        project.setHideIgnoredFiles(false)
        expect(project.getHideIgnoredFiles()).toBe(false)
