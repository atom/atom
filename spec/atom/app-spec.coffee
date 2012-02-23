App = require 'app'
fs = require 'fs'

xdescribe "App", ->
  app = null

  beforeEach ->
    app = new App()

  afterEach ->
    window.close() for window in app.windows()
    waitsFor ->
      app.windows().length == 0

  describe "open", ->
    describe "when opening a filePath", ->
      it "displays it in a new window with the contents of the file loaded", ->
        filePath = require.resolve 'fixtures/sample.txt'
        expect(app.windows().length).toBe 0

        app.open filePath

        expect(app.windows().length).toBe 1
        newWindow = app.windows()[0]
        expect(newWindow.rootView.editor.buffer.url).toEqual filePath
        expect(newWindow.rootView.editor.buffer.getText()).toEqual fs.read(filePath)

