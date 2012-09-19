$ = require 'jquery'
RootView = require 'root-view'

describe "WrapGuide", ->
  [rootView, editor, wrapGuide] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/sample.js'))
    requireExtension('wrap-guide')
    rootView.attachToDom()
    editor = rootView.getActiveEditor()
    wrapGuide = rootView.find('.wrap-guide').view()

  afterEach ->
    rootView.deactivate()

  describe "@initialize", ->
    it "appends a wrap guide to all existing and new editors", ->
      expect(rootView.panes.find('.pane').length).toBe 1
      expect(rootView.panes.find('.lines > .wrap-guide').length).toBe 1
      editor.splitRight()
      expect(rootView.find('.pane').length).toBe 2
      expect(rootView.panes.find('.lines > .wrap-guide').length).toBe 2

  describe "@updateGuide", ->
    it "positions the guide at the configured column", ->
      width = editor.charWidth * wrapGuide.column
      expect(width).toBeGreaterThan(0)
      expect(wrapGuide.position().left).toBe(width)

  describe "font-size-change", ->
    it "updates the wrap guide position", ->
      initial = wrapGuide.position().left
      expect(initial).toBeGreaterThan(0)
      rootView.trigger('increase-font-size')
      expect(wrapGuide.position().left).toBeGreaterThan(initial)
