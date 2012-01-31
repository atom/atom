Buffer = require 'buffer'
Range = require 'range'
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

  describe ".change(range, string)", ->
    describe "when used to insert (called with an empty range and a non-empty string)", ->
      describe "when the given string has no newlines", ->
        it "inserts the string at the location of the given range", ->
          range =
            start: {row: 3, column: 4}
            end: {row: 3, column: 4}

          buffer.change range, "foo"

          expect(buffer.getLine(2)).toBe "    if (items.length <= 1) return items;"
          expect(buffer.getLine(3)).toBe "    foovar pivot = items.shift(), current, left = [], right = [];"
          expect(buffer.getLine(4)).toBe "    while(items.length > 0) {"

      describe "when the given string has newlines", ->
        it "inserts the lines at the location of the given range", ->
          range =
            start: {row: 3, column: 4}
            end: {row: 3, column: 4}

          buffer.change range, "foo\n\nbar\nbaz"

          expect(buffer.getLine(2)).toBe "    if (items.length <= 1) return items;"
          expect(buffer.getLine(3)).toBe "    foo"
          expect(buffer.getLine(4)).toBe ""
          expect(buffer.getLine(5)).toBe "bar"
          expect(buffer.getLine(6)).toBe "bazvar pivot = items.shift(), current, left = [], right = [];"
          expect(buffer.getLine(7)).toBe "    while(items.length > 0) {"

    describe "when used to remove (called with a non-empty range and an empty string)", ->
      describe "when the range is contained within a single line", ->
        it "removes the characters within the range", ->
          range =
            start: {row: 3, column: 4}
            end: {row: 3, column: 7}

          buffer.change range, ""

          expect(buffer.getLine(2)).toBe "    if (items.length <= 1) return items;"
          expect(buffer.getLine(3)).toBe "     pivot = items.shift(), current, left = [], right = [];"
          expect(buffer.getLine(4)).toBe "    while(items.length > 0) {"

      describe "when the range spans 2 lines", ->
        it "removes the characters within the range and joins the lines", ->
          range =
            start: {row: 3, column: 16}
            end: {row: 4, column: 4}

          buffer.change range, ""

          expect(buffer.getLine(2)).toBe "    if (items.length <= 1) return items;"
          expect(buffer.getLine(3)).toBe "    var pivot = while(items.length > 0) {"
          expect(buffer.getLine(4)).toBe "      current = items.shift();"

      describe "when the range spans more than 2 lines", ->
        it "removes the characters within the range, joining the first and last line and removing the lines in-between", ->
          range =
            start: {row: 3, column: 16}
            end: {row: 11, column: 9}

          buffer.change range, ""

          expect(buffer.getLine(2)).toBe "    if (items.length <= 1) return items;"
          expect(buffer.getLine(3)).toBe "    var pivot = sort(Array.apply(this, arguments));"
          expect(buffer.getLine(4)).toBe "};"

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

  describe ".getTextInRange(range)", ->
    describe "when range is empty", ->
      it "returns an empty string", ->
        range = new Range([1,1], [1,1])
        expect(buffer.getTextInRange(range)).toBe ""

    describe "when range spans one line", ->
      it "returns characters in range", ->
        range = new Range([2,8], [2,13])
        expect(buffer.getTextInRange(range)).toBe "items"

        lineLength = buffer.getLine(2).length
        range = new Range([2,0], [2,lineLength])
        expect(buffer.getTextInRange(range)).toBe "    if (items.length <= 1) return items;"

    describe "when range spans multiple lines", ->
      it "returns characters in range (including newlines)", ->
        lineLength = buffer.getLine(2).length
        range = new Range([2,0], [3,0])
        expect(buffer.getTextInRange(range)).toBe "    if (items.length <= 1) return items;\n"

        lineLength = buffer.getLine(2).length
        range = new Range([2,10], [4,10])
        expect(buffer.getTextInRange(range)).toBe "ems.length <= 1) return items;\n    var pivot = items.shift(), current, left = [], right = [];\n    while("
