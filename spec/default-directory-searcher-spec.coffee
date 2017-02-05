DefaultDirectorySearcher = require '../src/default-directory-searcher'
Task = require '../src/task'
fs = require 'fs-plus'
path = require 'path'
temp = require('temp').track()

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

  it "is able to replace files", ->
    tempDir = temp.mkdirSync('dir')
    tempFile = path.join(tempDir, 'test_file')
    fs.writeFileSync(tempFile, 'aaa')

    results = []
    waitsForPromise ->
      searcher.replace [tempFile], /a/, 'b', (result) ->
        results.push(result)

    runs ->
      expect(results).toEqual [
        {filePath: tempFile, replacements: 3},
      ]
      expect(fs.readFileSync(tempFile, 'utf8')).toBe 'bbb'
