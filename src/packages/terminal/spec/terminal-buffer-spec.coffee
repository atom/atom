RootView = require 'root-view'
TerminalBuffer  = require 'terminal/lib/terminal-buffer'
_ = require 'underscore'
$ = require 'jquery'
{$$} = require 'space-pen'
fs = require 'fs'

describe 'Terminal Buffer', ->
  [buffer] = []

  beforeEach ->
    buffer = new TerminalBuffer

  describe "when a sequence of characters is entered", ->
    it "processes each character", ->
      spyOn(buffer, "inputCharacter").andCallThrough()
      buffer.input("abc")
      expect(buffer.inputCharacter).toHaveBeenCalledWith("a")
      expect(buffer.inputCharacter).toHaveBeenCalledWith("b")
      expect(buffer.inputCharacter).toHaveBeenCalledWith("c")
      expect(buffer.lastLine().text()).toBe("abc")

  describe "when a line changes", ->
    it "is marked as dirty", ->
      buffer.lastLine().rendered()
      buffer.lastLine().append("a")
      expect(buffer.lastLine().dirty).toBeTruthy()
    it "is included in dirtyLines()", ->
      buffer.lastLine().append("a")
      expect(buffer.getDirtyLines().length).toBe(1)

  describe "when a character is entered", ->
    it "adds the character to the buffer", ->
      expect(buffer.length()).toBe 0
      buffer.inputCharacter('a')
      expect(buffer.length()).toBe 1

  describe "when a special character is entered", ->
    describe "newline", ->
      it "adds a new line", ->
        buffer.inputCharacter('\n')
        expect(buffer.numLines()).toBe(2)
    describe "backspace", ->
      it "removes the last character", ->
        buffer.inputCharacter('a')
        buffer.inputCharacter(String.fromCharCode(8))
        expect(buffer.lastLine().text().length).toBe(0)

  fdescribe "when a control sequence is entered", ->
    beforeEach ->
      spyOn(buffer, 'evaluateEscapeSequence').andCallThrough()
    describe "cursor movement", ->
      describe "forward", ->
      describe "back", ->
      describe "up", ->
      describe "down", ->
    describe "sgr", ->
      describe "multiple codes seperated by ;", ->
        it "assigns all attributes", ->
          buffer.input("#{TerminalBuffer.escapeSequence("31;1m")}a")
          expect(buffer.lastLine().lastVisibleCharacter().color).toBe(1)
          expect(buffer.lastLine().lastVisibleCharacter().bold).toBe(true)
      describe "reset", ->
        it "resets all attributes", ->
          buffer.input("#{TerminalBuffer.escapeSequence("31m")}a#{TerminalBuffer.escapeSequence("0m")}A")
          expect(buffer.lastLine().lastVisibleCharacter().char).toBe("A")
          expect(buffer.lastLine().lastVisibleCharacter().color).toBe(0)
      describe "bold", ->
        it "sets characters to be bold", ->
          buffer.input("#{TerminalBuffer.escapeSequence("1m")}a")
          expect(buffer.lastLine().lastVisibleCharacter().bold).toBe(true)
      describe "italic", ->
        it "sets characters to be italic", ->
          buffer.input("#{TerminalBuffer.escapeSequence("3m")}a")
          expect(buffer.lastLine().lastVisibleCharacter().italic).toBe(true)
      describe "underlined", ->
        it "sets characters to be underlined", ->
          buffer.input("#{TerminalBuffer.escapeSequence("4m")}a")
          expect(buffer.lastLine().lastVisibleCharacter().underlined).toBe(true)
      describe "reverse", ->
      describe "hidden", ->
      describe "text color", ->
        it "sets the text color", ->
          buffer.input("#{TerminalBuffer.escape}[31mA")
          expect(buffer.lastLine().lastVisibleCharacter().char).toBe("A")
          expect(buffer.lastLine().lastVisibleCharacter().color).toBe(1)
          expect(buffer.evaluateEscapeSequence).toHaveBeenCalledWith("m", "31")
      describe "background color", ->
        it "sets the background color", ->
          buffer.input("#{TerminalBuffer.escape}[41mA")
          expect(buffer.lastLine().lastVisibleCharacter().backgroundColor).toBe(1)
          expect(buffer.evaluateEscapeSequence).toHaveBeenCalledWith("m", "41")

  fdescribe "cursor", ->
    describe "when characters are entered", ->
      it "moves to the end of the entered text", ->
        buffer.input("abc")
        expect(buffer.cursor.x).toBe(3)
      it "moves to the next line", ->
        buffer.input("a#{TerminalBuffer.enter}b")
        expect(buffer.cursor.y).toBe(1)
        expect(buffer.cursor.x).toBe(1)
    describe "when it is moved", ->

  fdescribe "screen", ->
    describe "coordinates", ->
      it "converts to line number", ->
        expect(buffer.screenToLine([1,1])).toEqual([1,1])
    describe "set scrolling region", ->
    describe "when a character is entered at the end of a line", ->
      it "inserts the character on the next line"
    describe "when the screen size changes", ->
      it "reformats the text in the buffer"
    describe "when the cursor is moved to screen coordinates", ->
      it "moves the cursor to the corresponding line", ->
