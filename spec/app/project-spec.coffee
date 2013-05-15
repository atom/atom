Project = require 'project'
fsUtils = require 'fs-utils'
_ = require 'underscore'
BufferedProcess = require 'buffered-process'

describe "Project", ->
  beforeEach ->
    project.setPath(project.resolve('dir'))

  describe "when an edit session is destroyed", ->
    it "removes edit session and calls destroy on buffer (if buffer is not referenced by other edit sessions)", ->
      editSession = project.open("a")
      anotherEditSession = project.open("a")

      expect(project.editSessions.length).toBe 2
      expect(editSession.buffer).toBe anotherEditSession.buffer

      editSession.destroy()
      expect(project.editSessions.length).toBe 1

      anotherEditSession.destroy()
      expect(project.editSessions.length).toBe 0

  describe "when an edit session is saved and the project has no path", ->
    it "sets the project's path to the saved file's parent directory", ->
      path = project.resolve('a')
      project.setPath(undefined)
      expect(project.getPath()).toBeUndefined()
      editSession = project.open()
      editSession.saveAs('/tmp/atom-test-save-sets-project-path')
      expect(project.getPath()).toBe '/tmp'
      fsUtils.remove('/tmp/atom-test-save-sets-project-path')

  describe ".open(path)", ->
    [fooOpener, barOpener, absolutePath, newBufferHandler, newEditSessionHandler] = []
    beforeEach ->
      absolutePath = fsUtils.resolveOnLoadPath('fixtures/dir/a')
      newBufferHandler = jasmine.createSpy('newBufferHandler')
      project.on 'buffer-created', newBufferHandler
      newEditSessionHandler = jasmine.createSpy('newEditSessionHandler')
      project.on 'edit-session-created', newEditSessionHandler

      fooOpener = (path, options) -> { foo: path, options } if path?.match(/\.foo/)
      barOpener = (path) -> { bar: path } if path?.match(/^bar:\/\//)
      Project.registerOpener(fooOpener)
      Project.registerOpener(barOpener)

    afterEach ->
      Project.unregisterOpener(fooOpener)
      Project.unregisterOpener(barOpener)

    describe "when passed a path that doesn't match a custom opener", ->
      describe "when given an absolute path that hasn't been opened previously", ->
        it "returns a new edit session for the given path and emits 'buffer-created' and 'edit-session-created' events", ->
          editSession = project.open(absolutePath)
          expect(editSession.buffer.getPath()).toBe absolutePath
          expect(newBufferHandler).toHaveBeenCalledWith editSession.buffer
          expect(newEditSessionHandler).toHaveBeenCalledWith editSession

      describe "when given a relative path that hasn't been opened previously", ->
        it "returns a new edit session for the given path (relative to the project root) and emits 'buffer-created' and 'edit-session-created' events", ->
          editSession = project.open('a')
          expect(editSession.buffer.getPath()).toBe absolutePath
          expect(newBufferHandler).toHaveBeenCalledWith editSession.buffer
          expect(newEditSessionHandler).toHaveBeenCalledWith editSession

      describe "when passed the path to a buffer that has already been opened", ->
        it "returns a new edit session containing previously opened buffer and emits a 'edit-session-created' event", ->
          editSession = project.open(absolutePath)
          newBufferHandler.reset()
          expect(project.open(absolutePath).buffer).toBe editSession.buffer
          expect(project.open('a').buffer).toBe editSession.buffer
          expect(newBufferHandler).not.toHaveBeenCalled()
          expect(newEditSessionHandler).toHaveBeenCalledWith editSession

      describe "when not passed a path", ->
        it "returns a new edit session and emits 'buffer-created' and 'edit-session-created' events", ->
          editSession = project.open()
          expect(editSession.buffer.getPath()).toBeUndefined()
          expect(newBufferHandler).toHaveBeenCalledWith(editSession.buffer)
          expect(newEditSessionHandler).toHaveBeenCalledWith editSession

    describe "when passed a path that matches a custom opener", ->
      it "returns the resource returned by the custom opener", ->
        expect(project.open("a.foo", hey: "there")).toEqual { foo: "a.foo", options: {hey: "there"} }
        expect(project.open("bar://baz")).toEqual { bar: "bar://baz" }

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

  describe ".resolve(uri)", ->
    describe "when passed an absolute or relative path", ->
      it "returns an absolute path based on the project's root", ->
        absolutePath = fsUtils.resolveOnLoadPath('fixtures/dir/a')
        expect(project.resolve('a')).toBe absolutePath
        expect(project.resolve(absolutePath + '/../a')).toBe absolutePath
        expect(project.resolve('a/../a')).toBe absolutePath

    describe "when passed a uri with a scheme", ->
      it "does not modify uris that begin with a scheme", ->
        expect(project.resolve('http://zombo.com')).toBe 'http://zombo.com'

  describe ".relativize(path)", ->
    it "returns an relative path based on the project's root", ->
      absolutePath = fsUtils.resolveOnLoadPath('fixtures/dir')
      expect(project.relativize(fsUtils.join(absolutePath, "b"))).toBe "b"
      expect(project.relativize(fsUtils.join(absolutePath, "b/file.coffee"))).toBe "b/file.coffee"
      expect(project.relativize(fsUtils.join(absolutePath, "file.coffee"))).toBe "file.coffee"

  describe ".setPath(path)", ->
    describe "when path is a file", ->
      it "sets its path to the files parent directory and updates the root directory", ->
        project.setPath(fsUtils.resolveOnLoadPath('fixtures/dir/a'))
        expect(project.getPath()).toEqual fsUtils.resolveOnLoadPath('fixtures/dir')
        expect(project.getRootDirectory().path).toEqual fsUtils.resolveOnLoadPath('fixtures/dir')

    describe "when path is a directory", ->
      it "sets its path to the directory and updates the root directory", ->
        project.setPath(fsUtils.resolveOnLoadPath('fixtures/dir/a-dir'))
        expect(project.getPath()).toEqual fsUtils.resolveOnLoadPath('fixtures/dir/a-dir')
        expect(project.getRootDirectory().path).toEqual fsUtils.resolveOnLoadPath('fixtures/dir/a-dir')

    describe "when path is null", ->
      it "sets its path and root directory to null", ->
        project.setPath(null)
        expect(project.getPath()?).toBeFalsy()
        expect(project.getRootDirectory()?).toBeFalsy()

  describe ".getFilePaths()", ->
    it "returns file paths using a promise", ->
      paths = null
      waitsForPromise ->
        project.getFilePaths().done (foundPaths) -> paths = foundPaths

      runs ->
        expect(paths.length).toBeGreaterThan 0

    it "ignores files that return true from atom.ignorePath(path)", ->
      spyOn(project, 'isPathIgnored').andCallFake (path) -> fsUtils.base(path).match /a$/

      paths = null
      waitsForPromise ->
        project.getFilePaths().done (foundPaths) -> paths = foundPaths

      runs ->
        expect(paths).not.toContain(project.resolve('a'))
        expect(paths).toContain(project.resolve('b'))

    describe "when config.core.hideGitIgnoredFiles is true", ->
      it "ignores files that are present in .gitignore if the project is a git repo", ->
        config.set "core.hideGitIgnoredFiles", true
        project.setPath(fsUtils.resolveOnLoadPath('fixtures/git/working-dir'))
        paths = null
        waitsForPromise ->
          project.getFilePaths().done (foundPaths) -> paths = foundPaths

        runs ->
          expect(paths).not.toContain('ignored.txt')

    describe "ignored file name", ->
      ignoredFile = null

      beforeEach ->
        ignoredFile = fsUtils.join(fsUtils.resolveOnLoadPath('fixtures/dir'), 'ignored.txt')
        fsUtils.write(ignoredFile, "")

      afterEach ->
        fsUtils.remove(ignoredFile)

      it "ignores ignored.txt file", ->
        paths = null
        config.get("core.ignoredNames").push("ignored.txt")
        config.update()
        waitsForPromise ->
          project.getFilePaths().done (foundPaths) -> paths = foundPaths

        runs ->
          expect(paths).not.toContain('ignored.txt')

    describe "ignored folder name", ->
      ignoredFile = null

      beforeEach ->
        ignoredFile = fsUtils.join(fsUtils.resolveOnLoadPath('fixtures/dir'), 'ignored/ignored.txt')
        fsUtils.write(ignoredFile, "")

      afterEach ->
        fsUtils.remove(ignoredFile)

      it "ignores ignored folder", ->
        paths = null
        config.get("core.ignoredNames").push("ignored.txt")
        config.set("core.ignoredNames", config.get("core.ignoredNames"))
        waitsForPromise ->
          project.getFilePaths().done (foundPaths) -> paths = foundPaths

        runs ->
          expect(paths).not.toContain('ignored/ignored.txt')

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
        project.setPath(fsUtils.resolveOnLoadPath('fixtures/evil-files'))
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
          expect(fsUtils.base(paths[4])).toBe "utfa\u0306.md"

      it "handles breaks in the search subprocess's output following the filename", ->
        spyOn(BufferedProcess.prototype, 'bufferStream')

        iterator = jasmine.createSpy('iterator')
        project.scan /a+/, iterator

        stdout = BufferedProcess.prototype.bufferStream.argsForCall[0][1]
        stdout ":#{fsUtils.resolveOnLoadPath('fixtures/dir/a')}\n"
        stdout "1;0 3:aaa bbb\n2;3 2:cc aa cc\n"

        expect(iterator.argsForCall[0][0]).toEqual
          path: project.resolve('a')
          match: 'aaa'
          range: [[0, 0], [0, 3]]

        expect(iterator.argsForCall[1][0]).toEqual
          path: project.resolve('a')
          match: 'aa'
          range: [[1, 3], [1, 5]]

      describe "when the core.excludeVcsIgnoredPaths config is truthy", ->
        [projectPath, ignoredPath] = []

        beforeEach ->
          projectPath = fsUtils.resolveOnLoadPath('fixtures/git/working-dir')
          ignoredPath = fsUtils.join(projectPath, 'ignored.txt')
          fsUtils.write(ignoredPath, 'this match should not be included')

        afterEach ->
          fsUtils.remove(ignoredPath) if fsUtils.exists(ignoredPath)

        it "excludes ignored files", ->
          project.setPath(projectPath)
          config.set('core.excludeVcsIgnoredPaths', true)
          paths = []
          matches = []
          waitsForPromise ->
            project.scan /match/, ({path, match, range}) ->
              paths.push(path)
              matches.push(match)

          runs ->
            expect(paths.length).toBe 0
            expect(matches.length).toBe 0

      it "includes files and folders that begin with a '.'", ->
        projectPath = '/tmp/atom-tests/folder-with-dot-file'
        filePath = fsUtils.join(projectPath, '.text')
        fsUtils.write(filePath, 'match this')
        project.setPath(projectPath)
        paths = []
        matches = []
        waitsForPromise ->
          project.scan /match this/, ({path, match, range}) ->
            paths.push(path)
            matches.push(match)

        runs ->
          expect(paths.length).toBe 1
          expect(paths[0]).toBe filePath
          expect(matches.length).toBe 1

  describe "serialization", ->
    it "restores the project path", ->
      newProject = Project.deserialize(project.serialize())
      expect(newProject.getPath()).toBe project.getPath()
