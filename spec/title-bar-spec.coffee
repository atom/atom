TitleBar = require '../src/title-bar'

describe "TitleBar", ->
  it 'updates the title based on document.title', ->
    titleBar = new TitleBar(atom)

    expect(titleBar.element.querySelector('.title').textContent).toBe document.title

    document.title = 'new-title'
    titleBar.updateTitle()

    expect(titleBar.element.querySelector('.title').textContent).toBe 'new-title'
