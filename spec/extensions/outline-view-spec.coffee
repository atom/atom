RootView = require 'root-view'
OutlineView = require 'outline-view'

describe "OutlineView", ->
  [rootView, outlineView] = []

  beforeEach ->
    rootView = new RootView(require.resolve('fixtures/coffee.coffee'))
    rootView.activateExtension(OutlineView)
    outlineView = OutlineView.instance
    rootView.attachToDom()

  afterEach ->
    rootView.deactivate()

  it "displays both functions", ->
    expect(rootView.find('.outline-view')).not.toExist()
    rootView.trigger 'outline-view:toggle'
    expect(rootView.find('.outline-view')).toExist()
    expect(outlineView.list.children('li').length).toBe 2
    expect(outlineView.list.find("li:contains(sort)")).toExist()
    expect(outlineView.list.find("li:contains(noop)")).toExist()
    expect(outlineView.list.children().first()).toHaveClass 'selected'

  it "doesn't display for unsupported languages", ->
    rootView.open(require.resolve('fixtures/sample.txt'))
    expect(rootView.find('.outline-view')).not.toExist()
    rootView.trigger 'outline-view:toggle'
    expect(rootView.find('.outline-view')).not.toExist()

  it "doesn't display when no functions exist", ->
    rootView.open(require.resolve('fixtures/sample-with-tabs.coffee'))
    expect(rootView.find('.outline-view')).not.toExist()
    rootView.trigger 'outline-view:toggle'
    expect(rootView.find('.outline-view')).not.toExist()
