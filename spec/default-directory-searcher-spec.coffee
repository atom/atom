DefaultDirectorySearcher = require '../src/default-directory-searcher'
Task = require '../src/task'
path = require 'path'

describe "DefaultDirectorySearcher", ->
  [searcher, dirPath] = []

  beforeEach ->
    dirPath = path.resolve(__dirname, 'fixtures', 'dir')
    searcher = new DefaultDirectorySearcher

  it "terminates the task after running a search", ->
    options =
      ignoreCase: false
      includeHidden: false
      excludeVcsIgnores: true
      inclusions: []
      globalExclusions: ['a-dir']
      didMatch: ->
      didError: ->
      didSearchPaths: ->
    searchPromise = searcher.search([{getPath: -> dirPath}], /abcdefg/, options)
    spyOn(Task::, 'terminate').andCallThrough()

    waitsForPromise -> searchPromise

    runs ->
      expect(Task::terminate).toHaveBeenCalled()
