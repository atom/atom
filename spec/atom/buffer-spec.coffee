Buffer = require 'buffer'
fs = require 'fs'

describe 'Buffer', ->
  describe 'constructor', ->
    it "loads the contents of the given url", ->
      filePath = require.resolve 'fixtures/sample.txt'
      buffer = new Buffer filePath
      expect(buffer.text).toBe fs.read(filePath)
