App = require 'app'
fs = require 'fs'

describe "App", ->
  app = null

  beforeEach ->
    app = new App()

  afterEach ->
    window.close() for window in app.windows()
    waitsFor ->
      app.windows().length == 0

  describe "open", ->
    describe "when opening a filePath", ->
      it "loads a buffer with filePath contents and displays it in a new window", ->
        filePath = require.resolve 'fixtures/sample.txt'
        expect(app.windows().length).toBe 0

        app.open filePath

        expect(app.windows().length).toBe 1
        newWindow = app.windows()[0]

        expect(newWindow.rootView.editor.buffer.url).toEqual filePath
        expect(newWindow.rootView.editor.buffer.getText()).toEqual fs.read(filePath)

    describe "when opening a dirPath", ->
      it "loads an empty buffer", ->
        dirPath = require.resolve 'fixtures'
        expect(app.windows().length).toBe 0

        app.open dirPath

        expect(app.windows().length).toBe 1
        newWindow = app.windows()[0]

        expect(newWindow.rootView.editor.buffer.url).toBeUndefined
        expect(newWindow.rootView.editor.buffer.getText()).toBe ""
