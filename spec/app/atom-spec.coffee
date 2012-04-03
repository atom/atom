Atom = require 'atom'
fs = require 'fs'

describe "Atom", ->
  closeAllWindows = ->
    window.close() for window in atom.windows
    waitsFor "there to be no windows", ->
      atom.windows.length == 0


  describe ".open(path)", ->
    beforeEach ->
      closeAllWindows()

    afterEach ->
      closeAllWindows()

    describe "when opening a file", ->
      it "displays it in a new window with the contents of the file loaded", ->
        filePath = null

        filePath = require.resolve 'fixtures/sample.txt'
        expect(atom.windows.length).toBe 0

        atom.open filePath

        waitsFor "window to open", ->
          atom.windows.length > 0

        runs ->
          expect(atom.windows.length).toBe 1
          newWindow = atom.windows[0]
          expect(newWindow.rootView.activeEditor().buffer.getPath()).toEqual filePath
          expect(newWindow.rootView.activeEditor().buffer.getText()).toEqual fs.read(filePath)

  describe ".windowOpened(window)", ->
    atom = null

    beforeEach ->
      atom = new Atom

    afterEach ->
      atom.destroy()

    it "adds the window to the windows array if it isn't already present", ->
      atom.windowOpened window
      atom.windowOpened window
      expect(atom.windows).toEqual [window]



