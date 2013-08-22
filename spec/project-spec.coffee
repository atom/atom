Project = require 'project'
fsUtils = require 'fs-utils'
path = require 'path'
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
      project.setPath(undefined)
      expect(project.getPath()).toBeUndefined()
      editSession = project.open()
      editSession.saveAs('/tmp/atom-test-save-sets-project-path')
      expect(project.getPath()).toBe '/tmp'
      fsUtils.remove('/tmp/atom-test-save-sets-project-path')

  describe "when an edit session is deserialized", ->
    it "emits an 'edit-session-created' event and stores the edit session", ->
      handler = jasmine.createSpy('editSessionCreatedHandler')
      project.on 'edit-session-created', handler

      editSession1 = project.open("a")
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
      absolutePath = fsUtils.resolveOnLoadPath('fixtures/dir/a')
      newBufferHandler = jasmine.createSpy('newBufferHandler')
      project.on 'buffer-created', newBufferHandler
      newEditSessionHandler = jasmine.createSpy('newEditSessionHandler')
      project.on 'edit-session-created', newEditSessionHandler

      fooOpener = (pathToOpen, options) -> { foo: pathToOpen, options } if pathToOpen?.match(/\.foo/)
      barOpener = (pathToOpen) -> { bar: pathToOpen } if pathToOpen?.match(/^bar:\/\//)
      Project.registerOpener(fooOpener)
      Project.registerOpener(barOpener)

    afterEach ->
      Project.unregisterOpener(fooOpener)
      Project.unregisterOpener(barOpener)

    describe "when passed a path that doesn't match a custom opener", ->
      it "creates the edit session with the configured `editor.tabLength` and `editor.softWrap` settings", ->
        config.set('editor.tabLength', 4)
        config.set('editor.softWrap', true)
        config.set('editor.softTabs', false)
        editSession1 = project.open('a')
        expect(editSession1.getTabLength()).toBe 4
        expect(editSession1.getSoftWrap()).toBe true
        expect(editSession1.getSoftTabs()).toBe false

        config.set('editor.tabLength', 100)
        config.set('editor.softWrap', false)
        config.set('editor.softTabs', true)
        editSession2 = project.open('b')
        expect(editSession2.getTabLength()).toBe 100
        expect(editSession2.getSoftWrap()).toBe false
        expect(editSession2.getSoftTabs()).toBe true

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
        pathToOpen = project.resolve('a.foo')
        expect(project.open(pathToOpen, hey: "there")).toEqual { foo: pathToOpen, options: {hey: "there"} }
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
      spyOn(project, 'isPathIgnored').andCallFake (filePath) -> path.basename(filePath).match /a$/

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
        ignoredFile = path.join(fsUtils.resolveOnLoadPath('fixtures/dir'), 'ignored.txt')
        fsUtils.writeSync(ignoredFile, "")

      afterEach ->
        fsUtils.remove(ignoredFile)

      it "ignores ignored.txt file", ->
        paths = null
        config.pushAtKeyPath("core.ignoredNames", "ignored.txt")
        waitsForPromise ->
          project.getFilePaths().done (foundPaths) -> paths = foundPaths

        runs ->
          expect(paths).not.toContain('ignored.txt')

    describe "ignored folder name", ->
      ignoredFile = null

      beforeEach ->
        ignoredFile = path.join(fsUtils.resolveOnLoadPath('fixtures/dir'), 'ignored/ignored.txt')
        fsUtils.writeSync(ignoredFile, "")

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
          project.scan /(a)+/, (match) -> matches.push(match)

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
          project.scan /\$\w+/, (match) -> matches.push(match)

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
          project.scan /evil/, (result) ->
            paths.push(result.path)
            matches.push(result.match)

        runs ->
          expect(paths.length).toBe 5
          matches.forEach (match) -> expect(match).toEqual 'evil'
          expect(paths[0]).toMatch /a_file_with_utf8.txt$/
          expect(paths[1]).toMatch /file with spaces.txt$/
          expect(paths[2]).toMatch /goddam\nnewlines$/m
          expect(paths[3]).toMatch /quote".txt$/m
          expect(path.basename(paths[4])).toBe "utfa\u0306.md"

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
          ignoredPath = path.join(projectPath, 'ignored.txt')
          fsUtils.writeSync(ignoredPath, 'this match should not be included')

        afterEach ->
          fsUtils.remove(ignoredPath) if fsUtils.exists(ignoredPath)

        it "excludes ignored files", ->
          project.setPath(projectPath)
          config.set('core.excludeVcsIgnoredPaths', true)
          paths = []
          matches = []
          waitsForPromise ->
            project.scan /match/, (result) ->
              paths.push(result.path)
              matches.push(result.match)

          runs ->
            expect(paths.length).toBe 0
            expect(matches.length).toBe 0

      it "includes files and folders that begin with a '.'", ->
        projectPath = '/tmp/atom-tests/folder-with-dot-file'
        filePath = path.join(projectPath, '.text')
        fsUtils.writeSync(filePath, 'match this')
        project.setPath(projectPath)
        paths = []
        matches = []
        waitsForPromise ->
          project.scan /match this/, (result) ->
            paths.push(result.path)
            matches.push(result.match)

        runs ->
          expect(paths.length).toBe 1
          expect(paths[0]).toBe filePath
          expect(matches.length).toBe 1

      it "excludes values in core.ignoredNames", ->
        projectPath = '/tmp/atom-tests/folder-with-dot-git/.git'
        filePath = path.join(projectPath, 'test.txt')
        fsUtils.writeSync(filePath, 'match this')
        project.setPath(projectPath)
        paths = []
        matches = []
        waitsForPromise ->
          project.scan /match/, (result) ->
            paths.push(result.path)
            matches.push(result.match)

        runs ->
          expect(paths.length).toBe 0
          expect(matches.length).toBe 0
