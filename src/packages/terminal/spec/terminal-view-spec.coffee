RootView = require 'root-view'
TerminalView  = require 'terminal/lib/terminal-view'
TerminalBuffer  = require 'terminal/lib/terminal-buffer'
_ = require 'underscore'
$ = require 'jquery'
{$$} = require 'space-pen'
fs = require 'fs'

fdescribe 'Terminal', ->
  [terminalView] = []

  beforeEach ->
    window.rootView = new RootView(require.resolve('fixtures/sample.js'))
    rootView.enableKeymap()
    terminalView = new TerminalView

  afterEach ->
    rootView.deactivate()

  describe "login", ->
    it "opens a terminal session", ->
      terminalView.login()
      waitsFor ->
        terminalView.readData == true
      runs ->
        terminalView.input("echo 'hello, world' && exit 0\n")
        waitsFor ->
          terminalView.exited == true
        runs ->
          expect($(terminalView.content.find("pre.line-1")).text()).toBe("hello, world")
          expect(terminalView.write()).toBeFalsy()

    it "exits the terminal session", ->
      terminalView.login()
      spyOn(terminalView, "logout").andCallThrough()
      terminalView.detach()

      waitsFor ->
        terminalView.exited == true
      runs ->
        expect(terminalView.logout).toHaveBeenCalled()

  describe "terminal view output", ->
    it "is added to the buffer", ->
      terminalView.output("foo\nbar")
      terminalView.output(" baz")
      expect(terminalView.content.find("pre").size()).toBe(2)

  fdescribe "when a line in the buffer is dirty", ->
    it "updates the line item", ->
      terminalView.output("a")
      expect(terminalView.content.find("pre").text()).toBe("a")
    it "creates each character", ->
      terminalView.output("ab")
      expect(terminalView.content.find("pre").first().find("span.character").size()).toBe(3)
    it "removes the line if it is not in the buffer anymore", ->
      terminalView.output("a\nb")
      terminalView.output(TerminalBuffer.escapeSequence("M"))
      expect(terminalView.buffer.numLines()).toBe(1)
      expect(terminalView.content.find("pre").size()).toBe(1)
    it "inserts the line at the right position", ->
      b = terminalView.buffer
      b.input("a\nb\nc\nd\ne")
      b.renderedAll()
      b.dirtyLines = [b.getLine(2), b.getLine(4)]
      terminalView.update()
      b.dirtyLines = [b.getLine(1), b.getLine(0), b.getLine(3)]
      terminalView.update()
      expect(terminalView.content.find("pre").size()).toBe(5)
      expect(terminalView.content.find("pre").text()).toBe("abcde")

    describe "color", ->
      it "sets the text color", ->
        terminalView.output(TerminalBuffer.escapeSequence("31m"))
        terminalView.output("a")
        expect(terminalView.content.find("pre span").hasClass("color-1")).toBe(true)
    describe "background-color", ->
      it "has no background color by default", ->
        terminalView.output("a")
        expect(terminalView.content.find("pre span").hasClass("background-0")).toBe(false)
      it "sets the background color", ->
        terminalView.output(TerminalBuffer.escapeSequence("41m"))
        terminalView.output("a")
        expect(terminalView.content.find("pre span").hasClass("background-1")).toBe(true)
    describe "reversed colors", ->
      it "swaps the foreground and background colors", ->
        terminalView.output(TerminalBuffer.escapeSequence("7m"))
        terminalView.output(TerminalBuffer.escapeSequence("41m"))
        terminalView.output(TerminalBuffer.escapeSequence("34m"))
        terminalView.output("a")
        expect(terminalView.content.find("pre span").hasClass("color-1")).toBe(true)
        expect(terminalView.content.find("pre span").hasClass("background-4")).toBe(true)

    describe "text style", ->
      it "sets the style to bold", ->
        terminalView.output("#{TerminalBuffer.escapeSequence("1m")}a")
        expect(terminalView.content.find("pre span").hasClass("bold")).toBe(true)
      it "sets the style to italic", ->
        terminalView.output("#{TerminalBuffer.escapeSequence("3m")}a")
        expect(terminalView.content.find("pre span").hasClass("italic")).toBe(true)
      it "sets the style to underlined", ->
        terminalView.output("#{TerminalBuffer.escapeSequence("4m")}a")
        expect(terminalView.content.find("pre span").hasClass("underlined")).toBe(true)

  describe "when the alternate buffer is used", ->
    it "clears the display on enable", ->
      terminalView.content.append($("<span class='to-be-deleted'>a</span>"))
      terminalView.buffer.enableAlternateBuffer()
      terminalView.update()
      expect(terminalView.content.find('.to-be-deleted').length).toBe(0)
    it "clears the display on disable", ->
      terminalView.content.append($("<span class='to-be-deleted'>a</span>"))
      terminalView.buffer.enableAlternateBuffer()
      terminalView.update()
      expect(terminalView.content.find('.to-be-deleted').length).toBe(0)

  describe "when the cursor position changes", ->
    it "scrolls to the cursor", ->

  describe "when a control key combo is pressed", ->
    it "sends the control event to the process", ->
      spyOn(terminalView, "input")
      rootView.trigger("terminal:ctrl-c")
      expect(terminalView.input).toHaveBeenCalledWith(String.fromCharCode(3))

  describe "when the terminal view size changes", ->
    it "resizes the terminal buffer", ->
      terminalView.size = [5, 10]
      terminalView.setTerminalSize()