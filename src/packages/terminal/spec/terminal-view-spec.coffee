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
    terminalView = window.loadPackage("terminal").packageMain.createView()

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

  describe "when a line in the buffer is dirty", ->
    it "updates the line item", ->
      terminalView.output("a")
      expect(terminalView.content.find("pre").text()).toBe("a")
    it "creates each character", ->
      terminalView.output("ab")
      expect(terminalView.content.find("pre").first().find("span.character").size()).toBe(3)

    describe "color", ->
      it "sets the text color", ->
        terminalView.output(TerminalBuffer.escapeSequence("31m"))
        terminalView.output("a")
        expect(terminalView.content.find("pre span").hasClass("color-1")).toBeTruthy()

    describe "background-color", ->
      it "sets the background color", ->
        terminalView.output(TerminalBuffer.escapeSequence("41m"))
        terminalView.output("a")
        expect(terminalView.content.find("pre span").hasClass("background-1")).toBeTruthy()
