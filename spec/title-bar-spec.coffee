TitleBar = require '../src/title-bar'

describe "TitleBar", ->
  it "updates the title based on document.title when the active pane item changes", ->
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

  it "can update the sheet offset for the current window based on its height", ->
    titleBar = new TitleBar({
      workspace: atom.workspace,
      themes: atom.themes,
      applicationDelegate: atom.applicationDelegate,
    })
    expect(->
      titleBar.updateWindowSheetOffset()
    ).not.toThrow()
