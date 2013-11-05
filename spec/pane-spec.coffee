PaneContainer = require '../src/pane-container'

describe "Pane", ->
  [container, pane] = []

  beforeEach ->
    container = PaneContainer.createAsRoot()
    pane = container.createPane({title: "Item 1"}, {title: "Item 2"})

  describe "construction", ->
    it "assigns the given items and sets the first item as the active item", ->
      expect(pane.items.map('title')).toEqual ["Item 1", "Item 2"]
      expect(pane.activeItem).toBe pane.items.getFirst()
