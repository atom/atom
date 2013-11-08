PaneContainer = require '../src/pane-container'

describe "Pane", ->
  [container, pane, item1, item2, item3] = []

  beforeEach ->
    container = PaneContainer.createAsRoot()
    pane = container.createPane({title: "Item 1"}, {title: "Item 2"}, {title: "Item 3"})
    [item1, item2, item3] = pane.items.getValues()

  describe "construction", ->
    it "assigns the given items and sets the first item as the active item", ->
      expect(pane.items.map('title')).toEqual ["Item 1", "Item 2"]
      expect(pane.activeItem).toBe item1

    it "does not assign an active item if no items are provided", ->
      pane = container.createPane()
      expect(pane.items).toEqual []
      expect(pane.activeItem).toBeUndefined()

  describe "::setActiveItem(item)", ->
    it "changes the active item", ->
      expect(pane.activeItem).toBe item1
      pane.setActiveItem(item3)
      expect(pane.activeItem).toBe item3
