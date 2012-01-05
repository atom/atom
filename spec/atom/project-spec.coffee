Project = require 'project'
fs = require 'fs'

describe "Project", ->
  project = null
  beforeEach ->
    project = new Project(require.resolve('fixtures/dir'))

  describe ".getFilePaths()", ->
    it "returns a promise which resolves to a list of all file urls in the project, recursively", ->
      expectedPaths = (url for url in fs.list(project.url, true) when fs.isFile url)

      waitsForPromise ->
        project.getFilePaths().done (result) ->
          expect(result).toEqual(expectedPaths)

  describe ".open(path)", ->
    absolutePath = null
    beforeEach ->
      absolutePath = require.resolve('fixtures/dir/a')

    describe "when given an absolute path", ->
      it "returns a buffer for the given path", ->
        expect(project.open(absolutePath).url).toBe absolutePath

    describe "when given a relative path", ->
      it "returns a buffer for the given path (relative to the project root)", ->
        expect(project.open('a').url).toBe absolutePath

