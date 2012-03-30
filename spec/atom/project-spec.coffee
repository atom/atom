Project = require 'project'
fs = require 'fs'

describe "Project", ->
  project = null
  beforeEach ->
    project = new Project(require.resolve('fixtures/dir'))

  describe ".getFilePaths()", ->
    it "returns a promise which resolves to a list of all file paths in the project, recursively", ->
      expectedPaths = (path.replace(project.path, '') for path in fs.listTree(project.path) when fs.isFile path)

      waitsForPromise ->
        project.getFilePaths().done (result) ->
          expect(result).toEqual(expectedPaths)

  describe ".open(path)", ->
    absolutePath = null
    beforeEach ->
      absolutePath = require.resolve('fixtures/dir/a')

    it "always returns the same buffer for the same canonical path", ->
      buffer = project.open(absolutePath)
      expect(project.open(absolutePath)).toBe buffer
      expect(project.open('a')).toBe buffer

    describe "when given an absolute path", ->
      it "returns a buffer for the given path", ->
        expect(project.open(absolutePath).path).toBe absolutePath

    describe "when given a relative path", ->
      it "returns a buffer for the given path (relative to the project root)", ->
        expect(project.open('a').path).toBe absolutePath

  describe ".resolve(path)", ->
    it "returns an absolute path based on the project's root", ->
      absolutePath = require.resolve('fixtures/dir/a')
      expect(project.resolve('a')).toBe absolutePath
      expect(project.resolve(absolutePath + '/../a')).toBe absolutePath
      expect(project.resolve('a/../a')).toBe absolutePath

