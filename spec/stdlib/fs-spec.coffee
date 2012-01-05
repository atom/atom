fs = require 'fs'

describe "fs", ->
  describe ".async", ->
    describe ".listFiles(directoryPath, recursive)", ->
      directoryPath = null
      beforeEach -> directoryPath = require.resolve 'fixtures/dir'

      describe "when recursive is true", ->
        it "returns a promise that resolves to the recursive contents of that directory that are files", ->
          waitsFor (complete) ->
            fs.async.listFiles(directoryPath, true).done (result) ->
              expect(result).toEqual (path for path in fs.list(directoryPath, true) when fs.isFile(path))
              complete()

      describe "when recursive is false", ->
        it "returns a promise that resolves to the contents of that directory that are files", ->
          waitsFor (complete) ->
            fs.async.listFiles(directoryPath).done (result) ->
              expect(result).toEqual (path for path in fs.list(directoryPath) when fs.isFile(path))
              complete()

