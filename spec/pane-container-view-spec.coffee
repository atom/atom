PaneContainerView = require '../src/pane-container-view'
PaneContainer = require '../src/pane-container'

describe "PaneContainerView", ->
  [container, view, element] = []

  beforeEach ->
    container = PaneContainer.createAsRoot()
    view = new PaneContainerView(container)
    {element} = view

  it "evenly divides the container into horizontal and vertical grid units", ->
    expect(element.children.length).toBe 1
    paneView = element.firstChild
    expect(paneView.classList.contains("pane")).toBe true
    expect(paneView.style.width).toBe "100%"
    expect(paneView.style.height).toBe "100%"

    container.root.splitRight()
    expect(element.children.length).toBe 1
    rowView = element.firstChild
    expect(rowView.classList.contains("row")).toBe true
    expect(rowView.children.length).toBe 2
    expect(rowView.children[0].classList.contains("pane")).toBe true
    expect(rowView.children[1].classList.contains("pane")).toBe true
