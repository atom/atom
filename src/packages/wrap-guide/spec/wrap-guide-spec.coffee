$ = require 'jquery'
RootView = require 'root-view'

describe "WrapGuide", ->
  [rootView, editor, wrapGuide] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    atom.loadPackage('wrap-guide')
    rootView.attachToDom()
    editor = rootView.getActiveEditor()
    wrapGuide = rootView.find('.wrap-guide').view()
    editor.width(editor.charWidth * wrapGuide.defaultColumn * 2)

  afterEach ->
    rootView.deactivate()

  describe "@initialize", ->
    it "appends a wrap guide to all existing and new editors", ->
      expect(rootView.panes.find('.pane').length).toBe 1
      expect(rootView.panes.find('.underlayer > .wrap-guide').length).toBe 1
      editor.splitRight()
      expect(rootView.find('.pane').length).toBe 2
      expect(rootView.panes.find('.underlayer > .wrap-guide').length).toBe 2

  describe "@updateGuide", ->
    it "positions the guide at the configured column", ->
      width = editor.charWidth * wrapGuide.defaultColumn
      expect(width).toBeGreaterThan(0)
      expect(wrapGuide.position().left).toBe(width)
      expect(wrapGuide).toBeVisible()

  describe "when the font size changes", ->
    it "updates the wrap guide position", ->
      initial = wrapGuide.position().left
      expect(initial).toBeGreaterThan(0)
      rootView.trigger('window:increase-font-size')
      expect(wrapGuide.position().left).toBeGreaterThan(initial)
      expect(wrapGuide).toBeVisible()

  describe "overriding getGuideColumn", ->
    it "invokes the callback with the editor path", ->
      editorPath = null
      wrapGuide.getGuideColumn = (path) ->
        editorPath = path
        80
      wrapGuide.updateGuide()
      expect(editorPath).toBe(require.resolve('fixtures/sample.js'))

    it "invokes the callback with a default value", ->
      column = null
      wrapGuide.getGuideColumn = (path, defaultColumn) ->
        editorPath = path
        column = defaultColumn
        defaultColumn

      wrapGuide.updateGuide()
      expect(column).toBeGreaterThan(0)

    # this is disabled because we no longer support passing config to an extension
    # at load time. we need to convert it to use the global config vars.
    xit "uses the function from the config data", ->
      rootView.find('.wrap-guide').remove()
      config =
        getGuideColumn: ->
          1
      atom.loadPackage('wrap-guide', config)
      wrapGuide = rootView.find('.wrap-guide').view()
      expect(wrapGuide.getGuideColumn).toBe(config.getGuideColumn)

    it "hides the guide when the column is less than 1", ->
      wrapGuide.getGuideColumn = (path) ->
        -1
      wrapGuide.updateGuide()
      expect(wrapGuide).toBeHidden()

  describe "when no lines exceed the guide column and the editor width is smaller than the guide column position", ->
    it "hides the guide", ->
      editor.width(10)
      wrapGuide.updateGuide()
      expect(wrapGuide).toBeHidden()
