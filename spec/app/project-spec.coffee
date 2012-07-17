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
      editSession = project.open("a")
      anotherEditSession = project.open("a")
      buffer = editSession.buffer
      spyOn(buffer, 'destroy').andCallThrough()

      expect(project.editSessions.length).toBe 2
      expect(editSession.buffer).toBe anotherEditSession.buffer

      editSession.destroy()
      expect(buffer.destroy).not.toHaveBeenCalled()
      expect(project.editSessions.length).toBe 1

      anotherEditSession.destroy()
      expect(buffer.destroy).toHaveBeenCalled()
      expect(project.editSessions.length).toBe 0

  describe ".open(path)", ->
    [absolutePath, newBufferHandler, newEditSessionHandler] = []
    beforeEach ->
      absolutePath = require.resolve('fixtures/dir/a')
      newBufferHandler = jasmine.createSpy('newBufferHandler')
      project.on 'new-buffer', newBufferHandler
      newEditSessionHandler = jasmine.createSpy('newEditSessionHandler')
      project.on 'new-edit-session', newEditSessionHandler

    describe "when given an absolute path that hasn't been opened previously", ->
      it "returns a new edit session for the given path and emits 'new-buffer' and 'new-edit-session' events", ->
        editSession = project.open(absolutePath)
        expect(editSession.buffer.getPath()).toBe absolutePath
        expect(newBufferHandler).toHaveBeenCalledWith editSession.buffer
        expect(newEditSessionHandler).toHaveBeenCalledWith editSession

    describe "when given a relative path that hasn't been opened previously", ->
      it "returns a new edit session for the given path (relative to the project root) and emits 'new-buffer' and 'new-edit-session' events", ->
        editSession = project.open('a')
        expect(editSession.buffer.getPath()).toBe absolutePath
        expect(newBufferHandler).toHaveBeenCalledWith editSession.buffer
        expect(newEditSessionHandler).toHaveBeenCalledWith editSession

    describe "when passed the path to a buffer that has already been opened", ->
      it "returns a new edit session containing previously opened buffer and emits a 'new-edit-session' event", ->
        editSession = project.open(absolutePath)
        newBufferHandler.reset()
        expect(project.open(absolutePath).buffer).toBe editSession.buffer
        expect(project.open('a').buffer).toBe editSession.buffer
        expect(newBufferHandler).not.toHaveBeenCalled()
        expect(newEditSessionHandler).toHaveBeenCalledWith editSession

    describe "when not passed a path", ->
      it "returns a new edit session and emits 'new-buffer' and 'new-edit-session' events", ->
        editSession = project.open()
        expect(editSession.buffer.getPath()).toBeUndefined()
        expect(newBufferHandler).toHaveBeenCalledWith(editSession.buffer)
        expect(newEditSessionHandler).toHaveBeenCalledWith editSession

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
    it "ignores files that return true from atom.ignorePath(path)", ->
      spyOn(project, 'ignorePath').andCallFake (path) -> fs.base(path).match /a$/

      project.getFilePaths().done (paths) ->
        expect(paths).not.toContain('a')
        expect(paths).toContain('b')

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
            match: ['aaa', 'a']
            range: [[0, 0], [0, 3]]

          expect(matches[1]).toEqual
            path: project.resolve('a')
            match: ['aa', 'a']
            range: [[1, 3], [1, 5]]
