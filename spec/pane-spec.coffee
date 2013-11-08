PaneContainer = require '../src/pane-container'

describe "Pane", ->
  [container, pane, item1, item2, item3] = []

  beforeEach ->
    container = PaneContainer.createAsRoot()
    pane = container.createPane({title: "Item 1"}, {title: "Item 2"}, {title: "Item 3"})
    [item1, item2, item3] = pane.items.getValues()

  describe "construction", ->
    it "assigns the given items and sets the first item as the active item", ->
      expect(pane.items.map('title')).toEqual ["Item 1", "Item 2", "Item 3"]
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

    describe "if the item isn't present in the items list", ->
      it "adds it after the current active item", ->
        pane.setActiveItem(item2)
        pane.setActiveItem({title: "Item 4"})
        expect(pane.activeItem).toEqual {title: "Item 4"}
        expect(pane.items).toEqual [item1, item2, {title: "Item 4"}, item3]
