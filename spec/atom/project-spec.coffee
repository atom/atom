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

