Atom = require 'atom'
fs = require 'fs'
_ = require 'underscore'

describe "Atom", ->
  beforeEach ->
    spyOn(Atom.prototype, "setUpKeymap")

  describe ".open(path)", ->
    newWindow = null

    afterEach ->
      newWindow?.close()

    describe "when opening a file", ->
      it "displays it in a new window with the contents of the file loaded", ->
        filePath = null

        filePath = require.resolve 'fixtures/sample.txt'
        previousWindowCount = atom.windows.length

        atom.open filePath

        waitsFor "window to open", ->
          atom.windows.length > previousWindowCount

        runs ->
          expect(atom.windows.length).toBe previousWindowCount + 1
          newWindow = _.last(atom.windows)
          expect(newWindow.rootView.activeEditor().buffer.getPath()).toEqual filePath
          expect(newWindow.rootView.activeEditor().buffer.getText()).toEqual fs.read(filePath)

  describe ".windowOpened(window)", ->
    atom = null

    beforeEach ->
      atom = new Atom

    it "adds the window to the windows array if it isn't already present", ->
      atom.windowOpened window
      atom.windowOpened window
      expect(atom.windows).toEqual [window]



