fs = require 'fs'

describe "fs", ->
  describe ".async", ->
    describe ".list(directoryPath)", ->
      directoryPath = nil
      beforeEach -> directoryPath = require.resolve 'fixtures/file-finder-dir'

      it "returns a promise that resolves to the contents of that directory", ->
        waitsFor (complete) ->
          promise = fs.async.list(directoryPath)
          promise.done (result) ->
            expect(result).toEqual fs.list(directoryPath)
          promise.done complete

