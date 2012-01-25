Buffer = require 'buffer'
fs = require 'fs'

describe 'Buffer', ->
  [filePath, fileContents, buffer] = []

  beforeEach ->
    filePath = require.resolve('fixtures/sample.js')
    fileContents = fs.read(filePath)
    buffer = new Buffer(filePath)

  describe 'constructor', ->
    describe "when given a path", ->
      describe "when a file exists for the path", ->
        it "loads the contents of that file", ->
          filePath = require.resolve 'fixtures/sample.txt'
          buffer = new Buffer(filePath)
          expect(buffer.getText()).toBe fs.read(filePath)

      describe "when no file exists for the path", ->
        it "creates an empty buffer", ->
          filePath = "does-not-exist.txt"
          expect(fs.exists(filePath)).toBeFalsy()

          buffer = new Buffer(filePath)
          expect(buffer.getText()).toBe ""

    describe "when no path is given", ->
      it "creates an empty buffer", ->
        buffer = new Buffer
        expect(buffer.getText()).toBe ""

  describe ".getLines()", ->
    it "returns an array of lines in the text contents", ->
      expect(buffer.getLines().length).toBe fileContents.split("\n").length
      expect(buffer.getLines().join('\n')).toBe fileContents

  describe "insert(position, string)", ->
    describe "when inserting a single character", ->
      it "inserts the given string at the given position", ->
        expect(buffer.getLine(1).charAt(6)).not.toBe 'q'
        buffer.insert({row: 1, col: 6}, 'q')
        expect(buffer.getLine(1).charAt(6)).toBe 'q'

      it "emits an event with the range of the change and the new text", ->
        insertHandler = jasmine.createSpy 'insertHandler'
        buffer.on 'insert', insertHandler

        buffer.insert({row: 1, col: 6}, 'q')

        expect(insertHandler).toHaveBeenCalled()
        [event] = insertHandler.argsForCall[0]

        expect(event.range.start).toEqual(row: 1, col: 6)
        expect(event.range.end).toEqual(row: 1, col: 6)
        expect(event.string).toBe 'q'

    describe "when inserting a newline", ->
      it "splits the portion of the line following the given position onto the next line", ->
        initialLineCount = buffer.getLines().length

        originalLine = buffer.getLine(2)
        lineBelowOriginalLine = buffer.getLine(3)

        buffer.insert({row: 2, col: 27}, '\n')

        expect(buffer.getLines().length).toBe(initialLineCount + 1)
        expect(buffer.getLine(2)).toBe originalLine.substring(0, 27)
        expect(buffer.getLine(3)).toBe originalLine.substring(27)
        expect(buffer.getLine(4)).toBe lineBelowOriginalLine

  describe ".save()", ->
    describe "when the buffer has a path", ->
      filePath = null

      beforeEach ->
        filePath = require.resolve('fixtures') + '/temp.txt'
        expect(fs.exists(filePath)).toBeFalsy()

      afterEach ->
        fs.remove filePath

      it "saves the contents of the buffer to the path", ->
        buffer = new Buffer filePath
        buffer.setText 'Buffer contents!'
        buffer.save()
        expect(fs.read(filePath)).toEqual 'Buffer contents!'

    describe "when the buffer no path", ->
      it "throw an exception", ->
        buffer = new Buffer
        expect(-> buffer.save()).toThrow()

