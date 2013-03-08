RootView = require 'root-view'
TerminalBuffer  = require 'terminal/lib/terminal-buffer'
_ = require 'underscore'
$ = require 'jquery'
{$$} = require 'space-pen'
fs = require 'fs'

fdescribe 'Terminal Buffer', ->
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
      expect(buffer.length()).toBe 1
      buffer.inputCharacter('a')
      expect(buffer.length()).toBe 2
      window.console.log(buffer)

  describe "when a special character is entered", ->
    describe "newline", ->
      it "adds a new line", ->
        buffer.inputCharacter('\n')
        expect(buffer.numLines()).toBe(2)
    describe "backspace", ->
      it "moves the cursor back", ->
        buffer.inputCharacter('a')
        expect(buffer.cursor.x).toBe(2)
        buffer.inputCharacter(String.fromCharCode(8))
        expect(buffer.cursor.x).toBe(1)

  describe "when a control sequence is entered", ->
    beforeEach ->
      spyOn(buffer, 'evaluateEscapeSequence').andCallThrough()
    describe "cursor movement", ->
      describe "forward", ->
      describe "back", ->
      describe "up", ->
      describe "down", ->
      describe "set cursor", ->
        it "moves the cursor to the coordinates", ->
          buffer.input(TerminalBuffer.escapeSequence("3;1H"))
          expect(buffer.cursor.y).toBe(3)
          expect(buffer.cursor.x).toBe(1)
    describe "set screen region", ->
      it "creates a new screen region", ->
        expect(buffer.scrollingRegion).toBeFalsy()
        buffer.input(TerminalBuffer.escapeSequence("1;5r"))
        expect(buffer.scrollingRegion).toBeTruthy()
        expect(buffer.scrollingRegion.height).toBe(5)
    describe "clear text", ->
      it "deletes to end of the line", ->
        buffer.input("abcd\nc")
        buffer.moveCursorTo([1,3])
        buffer.input(TerminalBuffer.escapeSequence("0K"))
        expect(buffer.text()).toBe("ab\nc\n")
      it "deletes to beginning of the line", ->
        buffer.input("abcd\nc")
        buffer.moveCursorTo([1,3])
        buffer.input(TerminalBuffer.escapeSequence("1K"))
        expect(buffer.text()).toBe("cd\nc\n")
      it "deletes the entire line", ->
        buffer.input("ab\nc")
        buffer.moveCursorTo([1,2])
        buffer.input(TerminalBuffer.escapeSequence("2K"))
        expect(buffer.text()).toBe("\nc\n")
    describe "clear screen", ->
      it "deletes to the end of the screen", ->
        buffer.input("abcd\nc")
        buffer.moveCursorTo([1,3])
        buffer.input(TerminalBuffer.escapeSequence("0J"))
        expect(buffer.text()).toBe("ab\n\n")
      it "deletes to the beginning of the screen", ->
        buffer.input("ab\ncd\nc")
        buffer.moveCursorTo([2,2])
        buffer.input(TerminalBuffer.escapeSequence("1J"))
        expect(buffer.text()).toBe("\nd\nc\n")
      it "deletes the entire screen", ->
        buffer.input("ab\nc")
        buffer.moveCursorTo([1,2])
        buffer.input(TerminalBuffer.escapeSequence("2J"))
        expect(buffer.text()).toBe("\n\n")
    describe "insert blank character", ->
      it "inserts a blank character after the cursor", ->
        buffer.input("ab\nc")
        buffer.moveCursorTo([1,2])
        buffer.input(TerminalBuffer.escapeSequence("2@"))
        expect(buffer.text()).toBe("a#{String.fromCharCode(0)}#{String.fromCharCode(0)}b\nc\n")
    describe "delete character", ->
      it "deletes the character under the cursor", ->
        buffer.input("abcde")
        buffer.moveCursorTo([1,2])
        buffer.input(TerminalBuffer.escapeSequence("3P"))
        expect(buffer.text()).toBe("ae\n")
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

  describe "cursor", ->
    describe "when characters are entered", ->
      it "moves to the end of the entered text", ->
        buffer.input("abc")
        expect(buffer.cursor.x).toBe(4)
      it "moves to the next line", ->
        buffer.input("a#{TerminalBuffer.enter}b")
        expect(buffer.cursor.y).toBe(2)
        expect(buffer.cursor.x).toBe(2)
      it "moves to a screen coordinate", ->
        buffer.moveCursorTo([5,3])
        expect(buffer.cursor.y).toBe(5)
        expect(buffer.cursor.x).toBe(3)
      it "creates lines if the cursor is out of bounds", ->
        expect(buffer.numLines()).toBe(1)
        buffer.moveCursorTo([5,3])
        expect(buffer.numLines()).toBe(5)
        window.console.log buffer.cursorLine()
        expect(buffer.cursorLine().length()).toBe(3)
      it "inserts characters at the cursor", ->
        buffer.moveCursorTo([1,3])
        expect(buffer.cursorLine().length()).toBe(3)
        buffer.input("a")
        expect(buffer.cursorLine().length()).toBe(4)
    describe "when it is moved", ->

  describe "screen", ->
    describe "coordinates", ->
      it "converts to line number", ->
        expect(buffer.screenToLine([1,1])).toEqual([1,1])
    describe "set scrolling region", ->
      it "adds lines for the scrolling region", ->
        buffer.input("a")
        buffer.setScrollingRegion([1,10])
        expect(buffer.scrollingRegion.height).toBe(10)
        expect(buffer.numLines()).toBe(11)
        expect(buffer.scrollingRegion.firstLine).toBe(1)
        expect(buffer.screenToLine([1,1])).toEqual([2,1])
      it "modifies the cursor coordinates", ->
        buffer.setScrollingRegion([1,10])
        buffer.moveCursorTo([10,1])
        expect(buffer.cursor.y).toBe(11)
    describe "when a character is entered at the end of a line", ->
      it "inserts the character on the next line"
    describe "when the screen size changes", ->
      it "reformats the text in the buffer"
    describe "when the cursor is moved to screen coordinates", ->
      it "moves the cursor to the corresponding line", ->
