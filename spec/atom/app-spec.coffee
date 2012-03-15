App = require 'app'
fs = require 'fs'

describe "App", ->
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
          expect(newWindow.rootView.editor.buffer.url).toEqual filePath
          expect(newWindow.rootView.editor.buffer.getText()).toEqual fs.read(filePath)

  describe ".windowOpened(window)", ->
    app = null

    beforeEach ->
      app = new App

    it "adds the window to the windows array if it isn't already present", ->
      app.windowOpened window
      app.windowOpened window
      expect(app.windows).toEqual [window]



