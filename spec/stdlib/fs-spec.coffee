fs = require 'fs'

describe "fs", ->
  describe ".async", ->
    describe ".list(directoryPath, recursive)", ->
      directoryPath = null
      beforeEach -> directoryPath = require.resolve 'fixtures/file-finder-dir'

      describe "when recursive is true", ->
        it "returns a promise that resolves to the recursive contents of that directory", ->
          waitsFor (complete) ->
            fs.async.list(directoryPath, true).done (result) ->
              expect(result).toEqual fs.list(directoryPath, true)
              complete()

      describe "when recursive is false", ->
        it "returns a promise that resolves to the contents of that directory", ->
          waitsFor (complete) ->
            fs.async.list(directoryPath).done (result) ->
              expect(result).toEqual fs.list(directoryPath)
              complete()

