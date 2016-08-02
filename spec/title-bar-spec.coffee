TitleBar = require '../src/title-bar'

describe "TitleBar", ->
  it 'updates the title based on document.title when the active pane item changes', ->
    titleBar = new TitleBar({
      workspace: atom.workspace,
      themes: atom.themes,
      applicationDelegate: atom.applicationDelegate,
    })

    expect(titleBar.element.querySelector('.title').textContent).toBe document.title
    initialTitle = document.title

    atom.workspace.getActivePane().activateItem({
      getTitle: -> 'Test Title'
    })

    expect(document.title).not.toBe(initialTitle)
    expect(titleBar.element.querySelector('.title').textContent).toBe document.title
