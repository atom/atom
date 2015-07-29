DefaultDirectorySearcher = require "../src/default-directory-searcher"
path = require "path"
fs = require 'fs-plus'
temp = require "temp"

describe "DefaultDirectorySearcher", ->
  [searcher, dirPath] = []

  beforeEach ->
    dirPath = path.resolve(__dirname, 'fixtures', 'dir')
    searcher = new DefaultDirectorySearcher

  it "terminates the task after running a search", ->
    console.log searcher
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
    spyOn(searchPromise.directorySearch.task, 'terminate').andCallThrough()

    waitsForPromise -> searchPromise

    runs ->
      expect(searchPromise.directorySearch.task.terminate).toHaveBeenCalled()
      expect(searchPromise.directorySearch.task.childProcess).toBe null
