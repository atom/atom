TitleBar = require '../src/title-bar'
temp = require 'temp'

describe "TitleBar", ->
  it "updates its title when document.title changes", ->
    titleBar = new TitleBar({
      workspace: atom.workspace,
      themes: atom.themes,
      applicationDelegate: atom.applicationDelegate,
    })
    expect(titleBar.element.querySelector('.title').textContent).toBe(document.title)

    paneItem = new FakePaneItem('Title 1')
    atom.workspace.getActivePane().activateItem(paneItem)
    expect(document.title).toMatch('Title 1')
    expect(titleBar.element.querySelector('.title').textContent).toBe(document.title)

    paneItem.setTitle('Title 2')
    expect(document.title).toMatch('Title 2')
    expect(titleBar.element.querySelector('.title').textContent).toBe(document.title)

    atom.project.setPaths([temp.mkdirSync('project-1')])
    expect(document.title).toMatch('project-1')
    expect(titleBar.element.querySelector('.title').textContent).toBe(document.title)

  it "can update the sheet offset for the current window based on its height", ->
    titleBar = new TitleBar({
      workspace: atom.workspace,
      themes: atom.themes,
      applicationDelegate: atom.applicationDelegate,
    })
    expect(-> titleBar.updateWindowSheetOffset()).not.toThrow()

class FakePaneItem
  constructor: (title) ->
    @title = title

  getTitle: ->
    @title

  onDidChangeTitle: (callback) ->
    @didChangeTitleCallback = callback
    {dispose: => @didChangeTitleCallback = null}

  setTitle: (title) ->
    @title = title
    @didChangeTitleCallback?(title)
