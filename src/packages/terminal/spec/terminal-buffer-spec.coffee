RootView = require 'root-view'
TerminalBuffer  = require 'terminal/lib/terminal-buffer'
_ = require 'underscore'
$ = require 'jquery'
{$$} = require 'space-pen'
fs = require 'fs'

fdescribe 'Terminal Buffer', ->
  [buffer, view] = []

  beforeEach ->
    view =
      input: (data) ->
        @data ?= []
        @data.push data
    buffer = new TerminalBuffer(view)

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
    describe "when auto-wrap mode is enabled", ->
      it "adds characters to the next line when the end of the line is reached", ->
        buffer.autowrap = true
        buffer.inputCharacter("a") for [1..buffer.size[1] + 2]
        expect(buffer.numLines()).toBe(2)
        expect(buffer.getLine(1).text()).toBe("aa")

  describe "when a special character is entered", ->
    describe "enquire", ->
      it "responds with a ack response", ->
        buffer.inputCharacter(String.fromCharCode(5))
        expect(view.data[0]).toBe(String.fromCharCode(6))
    describe "newline", ->
      it "adds a new line", ->
        buffer.inputCharacter('\n')
        expect(buffer.numLines()).toBe(2)
      it "scrolls down when scrolling region is active", ->
        buffer.setScrollingRegion([1,3])
        buffer.inputCharacter('\n')
        expect(buffer.numLines()).toBe(3)
    describe "backspace", ->
      it "moves the cursor back by one", ->
        buffer.inputCharacter('a')
        expect(buffer.cursor.x).toBe(2)
        buffer.inputCharacter(String.fromCharCode(8))
        expect(buffer.cursor.x).toBe(1)
    describe 'carriage return', ->
      it "moves the cursor to the beginning of the line", ->
        buffer.input("abcde")
        buffer.inputCharacter(String.fromCharCode(13))
        expect(buffer.cursor.x).toBe(1)
    describe 'tab', ->
      it "moves the cursor to the next tabstop", ->
        expect(buffer.cursor.x).toBe(1)
        buffer.input('\t')
        expect(buffer.cursor.x).toBe(9)
      it "moves the cursor by one or more characters", ->
        buffer.input('abcdefg\t')
        expect(buffer.cursor.x).toBe(9)
        buffer.input('abcdefg\t')
        expect(buffer.cursor.x).toBe(17)

  describe "when a control sequence is entered", ->
    beforeEach ->
      spyOn(buffer, 'evaluateEscapeSequence').andCallThrough()
    describe "cancel", ->
      it "discards the current escape sequence", ->
        buffer.input("ab#{TerminalBuffer.escapeSequence(String.fromCharCode(24))}cde")
        expect(buffer.text()).toBe("abcde\n")
    describe "simple sequences", ->
      describe "save cursor", ->
        it "saves cursor position and restores it", ->
          buffer.input("abcdef")
          buffer.moveCursorTo([1,4])
          buffer.input("#{TerminalBuffer.escape}7")
          buffer.moveCursorTo([1,6])
          buffer.input("#{TerminalBuffer.escape}8")
          expect(buffer.cursor.x).toBe(4)
    describe "cursor movement", ->
      describe "forward", ->
        it "moves the cursor to the right", ->
          buffer.input("abc")
          buffer.moveCursorTo([1,1])
          buffer.input(TerminalBuffer.escapeSequence("C"))
          expect(buffer.cursor.x).toBe(2)
          buffer.input(TerminalBuffer.escapeSequence("4C"))
          expect(buffer.cursor.x).toBe(4)
      describe "back", ->
        it "moves the cursor to the left", ->
          buffer.input("abc")
          buffer.moveCursorTo([1,3])
          buffer.input(TerminalBuffer.escapeSequence("D"))
          expect(buffer.cursor.x).toBe(2)
          buffer.input(TerminalBuffer.escapeSequence("4D"))
          expect(buffer.cursor.x).toBe(1)
      describe "up", ->
        it "moves the cursor to the previous line", ->
          buffer.input("a\nb\nc\nd")
          expect(buffer.cursor.y).toBe(4)
          buffer.input(TerminalBuffer.escapeSequence("A"))
          expect(buffer.cursor.y).toBe(3)
          buffer.input(TerminalBuffer.escapeSequence("4A"))
          expect(buffer.cursor.y).toBe(1)
      describe "down", ->
        it "moves the cursor to the next line", ->
          buffer.input("a\nb\nc\nd")
          buffer.moveCursorTo([1,1])
          buffer.input(TerminalBuffer.escapeSequence("B"))
          expect(buffer.cursor.y).toBe(2)
          buffer.input(TerminalBuffer.escapeSequence("4B"))
          expect(buffer.cursor.y).toBe(4)
      describe "set cursor", ->
        it "moves the cursor to the coordinates", ->
          buffer.input(TerminalBuffer.escapeSequence("3;1H"))
          expect(buffer.cursor.y).toBe(3)
          expect(buffer.cursor.x).toBe(1)
      describe "set cursor line", ->
        it "moves cursor to the line", ->
          buffer.input(TerminalBuffer.escapeSequence("3d"))
          expect(buffer.cursor.y).toBe(3)
          expect(buffer.cursor.x).toBe(1)
        it "moves cursor relative to current line", ->
          buffer.moveCursorTo([3,1])
          buffer.input(TerminalBuffer.escapeSequence("3e"))
          expect(buffer.cursor.y).toBe(6)
          expect(buffer.cursor.x).toBe(1)
      describe "set cursor character", ->
        it "moves cursor in line", ->
          buffer.input(TerminalBuffer.escapeSequence("4G"))
          expect(buffer.cursor.y).toBe(1)
          expect(buffer.cursor.x).toBe(4)
          buffer.input(TerminalBuffer.escapeSequence("2`"))
          expect(buffer.cursor.y).toBe(1)
          expect(buffer.cursor.x).toBe(2)
        it "moves cursor relative in line", ->
          buffer.moveCursorTo([1,10])
          buffer.input(TerminalBuffer.escapeSequence("4a"))
          expect(buffer.cursor.y).toBe(1)
          expect(buffer.cursor.x).toBe(14)
      describe "next line", ->
        it "moves cursor down", ->
          buffer.input(TerminalBuffer.escapeSequence("2E"))
          expect(buffer.cursor.y).toBe(3)
      describe "previous line", ->
        it "moves cursor up", ->
          buffer.moveCursorTo([5,1])
          buffer.input(TerminalBuffer.escapeSequence("2F"))
          expect(buffer.cursor.y).toBe(3)
          buffer.input(TerminalBuffer.escapeSequence("5F"))
          expect(buffer.cursor.y).toBe(1)
      describe "tabs", ->
        it "moves to next tab stop", ->
          buffer.input(TerminalBuffer.escapeSequence("I"))
          expect(buffer.cursor.x).toBe(9)
          buffer.input(TerminalBuffer.escapeSequence("2I"))
          expect(buffer.cursor.x).toBe(25)
        it "moves to previous tab stop", ->
          buffer.input("\t\t\t")
          buffer.input(TerminalBuffer.escapeSequence("2Z"))
          expect(buffer.cursor.x).toBe(9)
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
      it "only clears inside the scrolling region", ->
        buffer.input("ab")
        buffer.setScrollingRegion([2,3])
        buffer.moveCursorTo([1,1])
        buffer.input("cd")
        buffer.moveCursorTo([2,1])
        buffer.input("e")
        buffer.input(TerminalBuffer.escapeSequence("2J"))
        expect(buffer.text()).toBe("ab\n\n\n")
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
        expect(buffer.cursorLine().length()).toBe(3)
        expect(buffer.text()).toBe("ae\n")
    describe "erase character", ->
      it "clears the character under the cursor", ->
        buffer.input("abcde")
        buffer.moveCursorTo([1,2])
        buffer.input(TerminalBuffer.escapeSequence("3X"))
        expect(buffer.cursorLine().length()).toBe(6)
        expect(buffer.text()).toBe("ae\n")
    describe "insert line", ->
      it "inserts a new line", ->
        buffer.input(TerminalBuffer.escapeSequence("3L"))
        expect(buffer.numLines()).toBe(4)
      it "scrolls if a scrolling region is set", ->
        buffer.setScrollingRegion([1,2])
        buffer.input(TerminalBuffer.escapeSequence("3L"))
        expect(buffer.numLines()).toBe(2)
    describe "delete line", ->
      it "deletes the line under the cursor", ->
        buffer.input("a\nb\nc\nd\ne\nf")
        buffer.moveCursorTo([2,1])
        expect(buffer.getLine(1).number).toBe(1)
        buffer.input(TerminalBuffer.escapeSequence("3M"))
        expect(buffer.text()).toBe("a\ne\nf\n")
        expect(buffer.getLine(1).number).toBe(1)
    describe "scroll up", ->
      it "moves lines up", ->
        buffer.input("a\nb")
        buffer.input(TerminalBuffer.escapeSequence("S"))
        expect(buffer.text()).toBe("b\n\n")
      it "scrolls inside the scrolling region", ->
        buffer.input("a\nb\nc\nd")
        buffer.setScrollingRegion([2,3])
        buffer.input(TerminalBuffer.escapeSequence("2S"))
        expect(buffer.text()).toBe("a\n\n\nd\n")
    describe "scroll down", ->
      it "moves lines down", ->
        buffer.input("a\nb")
        buffer.input(TerminalBuffer.escapeSequence("T"))
        expect(buffer.text()).toBe("\na\n")
      it "scrolls inside the scrolling region", ->
        buffer.input("a\nb\nc\nd")
        buffer.setScrollingRegion([2,3])
        buffer.input(TerminalBuffer.escapeSequence("2T"))
        expect(buffer.text()).toBe("a\n\n\nd\n")
    describe "mouse tracking", ->
      it "is ignored", ->
        buffer.input("a\nb")
        buffer.input(TerminalBuffer.escapeSequence("1;2;3;4;5T"))
        expect(buffer.text()).toBe("a\nb\n")
    describe "send device attributes", ->
      it "responds as a VT102", ->
        buffer.input(TerminalBuffer.escapeSequence("c"))
        expect(view.data[0]).toBe(TerminalBuffer.escapeSequence("?6c"))
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
        it "enables reverse mode", ->
          buffer.input("#{TerminalBuffer.escapeSequence("7m")}a")
          expect(buffer.lastLine().lastVisibleCharacter().reversed).toBe(true)
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
    describe "use alternate screen buffer", ->
      it "uses an alternate screen buffer", ->
        buffer.input("abcdef")
        buffer.input(TerminalBuffer.escapeSequence("?47h"))
        buffer.input("alt")
        expect(buffer.text()).toBe("alt\n")
        buffer.input(TerminalBuffer.escapeSequence("?47l"))
        expect(buffer.text()).toBe("abcdef\n")
    describe "dec private mode", ->
      describe "autowrap", ->
        it "enables autowrap", ->
          buffer.input(TerminalBuffer.escapeSequence("?7h"))
          expect(buffer.autowrap).toBe(true)
          buffer.input(TerminalBuffer.escapeSequence("?7l"))
          expect(buffer.autowrap).toBe(false)
      describe "show/hide cursor", ->
        it "determines if the cursor is shown", ->
          buffer.input("a")
          expect(buffer.cursorLine().lastCharacter().cursor).toBe(true)
          buffer.input(TerminalBuffer.escapeSequence("?25l"))
          expect(buffer.cursorLine().lastCharacter().cursor).toBe(false)
          buffer.input(TerminalBuffer.escapeSequence("?25h"))
          expect(buffer.cursorLine().lastCharacter().cursor).toBe(true)
      describe "use alternate screen buffer", ->
        it "uses an alternate screen buffer", ->
          buffer.input("abcdef")
          buffer.input(TerminalBuffer.escapeSequence("?1047h"))
          buffer.input("alt")
          expect(buffer.text()).toBe("alt\n")
          buffer.input(TerminalBuffer.escapeSequence("?1047l"))
          expect(buffer.text()).toBe("abcdef\n")
      describe "save cursor", ->
        it "saves cursor position and restores it", ->
          buffer.input("abcdef")
          buffer.moveCursorTo([1,4])
          buffer.input(TerminalBuffer.escapeSequence("?1048h"))
          buffer.moveCursorTo([1,6])
          buffer.input(TerminalBuffer.escapeSequence("?1048l"))
          expect(buffer.cursor.x).toBe(4)
      describe "save cursor and use alternate screen buffer", ->
        beforeEach ->
          buffer.input("abcdef")
        it "uses an alternate screen buffer", ->
          buffer.input(TerminalBuffer.escapeSequence("?1049h"))
          buffer.input("alt")
          expect(buffer.text()).toBe("alt\n")
          buffer.input(TerminalBuffer.escapeSequence("?1049l"))
          expect(buffer.text()).toBe("abcdef\n")
        it "restores the original cursor position", ->
          buffer.moveCursorTo([1,4])
          buffer.input(TerminalBuffer.escapeSequence("?1049h"))
          buffer.moveCursorTo([1,6])
          buffer.input(TerminalBuffer.escapeSequence("?1049l"))
          expect(buffer.cursor.x).toBe(4)
    describe "window title", ->
      it "updates the title of the buffer", ->
        buffer.input("#{TerminalBuffer.escape}]2;Window Title#{TerminalBuffer.bell}")
        expect(buffer.title).toBe("Window Title")
        expect(buffer.text()).toBe("\n")
    describe "status report", ->
      it "reports the terminal is ok", ->
        buffer.input(TerminalBuffer.escapeSequence("5n"))
        expect(view.data[0]).toBe(TerminalBuffer.escapeSequence("0n"))
      it "reports the cursor position", ->
        buffer.moveCursorTo([5,3])
        buffer.input(TerminalBuffer.escapeSequence("6n"))
        expect(view.data[0]).toBe(TerminalBuffer.escapeSequence("5;3R"))
        buffer.input(TerminalBuffer.escapeSequence("?6n"))
        expect(view.data[0]).toBe(TerminalBuffer.escapeSequence("5;3R"))
      it "reports that a printer is not ready", ->
        buffer.input(TerminalBuffer.escapeSequence("?15n"))
        expect(view.data[0]).toBe(TerminalBuffer.escapeSequence("1n"))
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
        expect(buffer.numLines()).toBe(10)
        expect(buffer.scrollingRegion.firstLine).toBe(1)
        expect(buffer.screenToLine([1,1])).toEqual([1,1])
      it "modifies the cursor coordinates", ->
        buffer.setScrollingRegion([10,20])
        buffer.moveCursorTo([10,1])
        expect(buffer.cursor.y).toBe(19)
      it "only adds lines if needed", ->
        buffer.input("a")
        buffer.setScrollingRegion([1,10])
        buffer.setScrollingRegion([1,5])
        buffer.setScrollingRegion([1,10])
        expect(buffer.scrollingRegion.height).toBe(10)
        expect(buffer.numLines()).toBe(10)
        expect(buffer.scrollingRegion.firstLine).toBe(1)
        expect(buffer.screenToLine([1,1])).toEqual([1,1])
      it "never adds more lines", ->
        buffer.setScrollingRegion([1,3])
        buffer.setScrollingRegion([1,2])
        buffer.setScrollingRegion([1,3])
        buffer.setScrollingRegion([1,2])
        buffer.setScrollingRegion([1,3])
        buffer.setScrollingRegion([1,2])
        buffer.setScrollingRegion([1,3])
        expect(buffer.numLines()).toBe(3)
    describe "when a character is entered at the end of a line", ->
      it "inserts the character on the next line"
    describe "when the screen size changes", ->
      it "reformats the text in the buffer"
    describe "when the cursor is moved to screen coordinates", ->
      it "moves the cursor to the corresponding line", ->
