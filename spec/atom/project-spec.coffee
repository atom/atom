Project = require 'project'
fs = require 'fs'

describe "Project", ->
  project = null
  beforeEach ->
    project = new Project(require.resolve('fixtures/dir'))

  describe ".list()", ->
    it "returns a promise which resolves to a list of all file urls in the project, recursively", ->
      waitsFor (complete) ->
        project.list().done (result) ->
          expect(result).toEqual(fs.list(project.url, true))
          complete()

