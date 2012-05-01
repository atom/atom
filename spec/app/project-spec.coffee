Project = require 'project'
fs = require 'fs'

describe "Project", ->
  project = null
  beforeEach ->
    project = new Project(require.resolve('fixtures/dir'))

  describe ".open(path)", ->
    [absolutePath, newBufferHandler] = []
    beforeEach ->
      absolutePath = require.resolve('fixtures/dir/a')
      newBufferHandler = jasmine.createSpy('newBufferHandler')
      project.on 'new-buffer', newBufferHandler

    describe "when given an absolute path that hasn't been opened previously", ->
      it "returns a new buffer for the given path and emits a 'new-buffer' event", ->
        buffer = project.open(absolutePath)
        expect(buffer.path).toBe absolutePath
        expect(newBufferHandler).toHaveBeenCalledWith buffer

    describe "when given a relative path that hasn't been opened previously", ->
      it "returns a buffer for the given path (relative to the project root) and emits a 'new-buffer' event", ->
        buffer = project.open('a')
        expect(buffer.path).toBe absolutePath
        expect(newBufferHandler).toHaveBeenCalledWith buffer

    describe "when passed the path to a buffer that has already been opened", ->
      it "returns the previously opened buffer", ->
        buffer = project.open(absolutePath)
        newBufferHandler.reset()
        expect(project.open(absolutePath)).toBe buffer
        expect(project.open('a')).toBe buffer
        expect(newBufferHandler).not.toHaveBeenCalled()

    describe "when not passed a path", ->
      it "returns a new buffer and emits a new-buffer event", ->
        buffer = project.open()
        expect(buffer.path).toBeUndefined()
        expect(newBufferHandler).toHaveBeenCalledWith(buffer)

  describe ".getFilePaths()", ->
    it "returns a promise which resolves to a list of all file paths in the project, recursively", ->
      expectedPaths = (path.replace(project.path, '') for path in fs.listTree(project.path) when fs.isFile path)

      waitsForPromise ->
        project.getFilePaths().done (result) ->
          expect(result).toEqual(expectedPaths)

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
