App = require 'app'

describe "App", ->
  app = null

  beforeEach ->
    app = new App()

  afterEach ->
    window.x = app.windows()[0]
    setTimeout (-> window.x.close()), 1
    #w.close() for w in app.windows()

  describe "open", ->
    it "loads a buffer based on the given path and displays it in a new window", ->
      filePath = require.resolve 'fixtures/sample.txt'
      expect(app.windows().length).toBe 0

      app.open filePath

      expect(app.windows().length).toBe 1
      newWindow = app.windows()[0]

      expect(newWindow.editor.buffer.url).toEqual filePath
