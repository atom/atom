App = require 'app'
fs = require 'fs'

describe "App", ->
  app = null

  beforeEach ->
    app = new App()

  afterEach ->
    window.close() for window in app.windows()

  describe "open", ->
    it "loads a buffer based on the given path and displays it in a new window", ->
      filePath = require.resolve 'fixtures/sample.txt'
      expect(app.windows().length).toBe 0

      app.open filePath

      expect(app.windows().length).toBe 1
      newWindow = app.windows()[0]

      expect(newWindow.editor).toBeDefined()
      expect(newWindow.editor.buffer).toBeDefined()
      expect(newWindow.editor.buffer.url).toEqual filePath
      expect(newWindow.editor.buffer.getText()).toEqual fs.read(filePath)
