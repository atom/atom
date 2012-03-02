Project = require 'project'
fs = require 'fs'

describe "Project", ->
  project = null
  beforeEach ->
    project = new Project(require.resolve('fixtures/dir'))

  describe ".getFilePaths()", ->
    it "returns a promise which resolves to a list of all file urls in the project, recursively", ->
      expectedPaths = (url.replace(project.url, '') for url in fs.listTree(project.url) when fs.isFile url)

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
        expect(project.open(absolutePath).url).toBe absolutePath

    describe "when given a relative path", ->
      it "returns a buffer for the given path (relative to the project root)", ->
        expect(project.open('a').url).toBe absolutePath

  describe ".resolve(path)", ->
    it "returns an absolute path based on the project's root", ->
      absolutePath = require.resolve('fixtures/dir/a')
      expect(project.resolve('a')).toBe absolutePath
      expect(project.resolve(absolutePath + '/../a')).toBe absolutePath
      expect(project.resolve('a/../a')).toBe absolutePath

