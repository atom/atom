fs = require 'fs'

describe "fs", ->
  describe ".async", ->
    describe ".list(directoryPath)", ->
      directoryPath = null
      beforeEach -> directoryPath = require.resolve 'fixtures/file-finder-dir'

      it "returns a promise that resolves to the contents of that directory", ->
        waitsFor (complete) ->
          fs.async.list(directoryPath).done (result) ->
            expect(result).toEqual fs.list(directoryPath)
            complete()
