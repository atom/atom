TitleBar = require '../src/title-bar'
TitleBarElement = require '../src/title-bar-element'

describe "TitleBarElement", ->
  beforeEach ->
    atom.views.addViewProvider TitleBar, (model, env) ->
      new TitleBarElement().initialize(model, env)

  it 'updates the title based on document.title', ->
    titleBar = new TitleBar({item: new TitleBarElement})
    element = atom.views.getView(titleBar)

    expect(element.querySelector('.title').textContent).toBe document.title

    document.title = 'new-title'
    element.updateTitle()

    expect(element.querySelector('.title').textContent).toBe 'new-title'
