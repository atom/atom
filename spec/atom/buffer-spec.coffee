Buffer = require 'buffer'
fs = require 'fs'

describe 'Buffer', ->
  describe 'constructor', ->
    describe "when given a url", ->
      describe "when a file exists for the url", ->
        it "loads the contents of that file", ->
          filePath = require.resolve 'fixtures/sample.txt'
          buffer = new Buffer filePath
          expect(buffer.getText()).toBe fs.read(filePath)

      describe "when no file exists for the url", ->
        it "creates an empty buffer", ->
          filePath = "does-not-exist.txt"
          expect(fs.exists(filePath)).toBeFalsy()

          buffer = new Buffer filePath
          expect(buffer.getText()).toBe ""

    describe "when no url is given", ->
      it "creates an empty buffer", ->
        buffer = new Buffer null
        expect(buffer.getText()).toBe ""

  describe "save", ->
    describe "when the buffer has a url", ->
      filePath = null

      beforeEach ->
        filePath = require.resolve('fixtures') + '/temp.txt'
        expect(fs.exists(filePath)).toBeFalsy()

      afterEach ->
        fs.remove filePath

      it "saves the contents of the buffer to the url", ->
        buffer = new Buffer filePath
        buffer.setText 'Buffer contents!'
        buffer.save()
        expect(fs.read(filePath)).toEqual 'Buffer contents!'

    describe "when the buffer no url", ->
      it "throw an exception", ->
        buffer = new Buffer
        expect(-> buffer.save()).toThrow()

  describe "getMode", ->
    describe "when given a url", ->
      it "sets 'mode' based on the file extension", ->
        buffer = new Buffer 'something.js'
        expect(buffer.getMode().name).toBe 'javascript'

    describe "when no url is given", ->
      it "sets 'mode' to text mode", ->
        buffer = new Buffer 'something'
        expect(buffer.getMode().name).toBe 'text'
