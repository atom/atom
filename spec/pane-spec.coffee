{Model} = require 'telepath'
Pane = require '../src/pane'
PaneContainer = require '../src/pane-container'
Focusable = require '../src/focusable'

describe "Pane", ->
  [container, pane, item1, item2, item3] = []

  class Item extends Model
    Focusable.includeInto(this)

  beforeEach ->
    container = PaneContainer.createAsRoot()
    pane = container.root
    item1 = new Item
    item2 = new Item
    item3 = new Item
    pane.addItems([item1, item2, item3])

  describe "construction", ->
    it "assigns the given items and sets the first item as the active item", ->
      expect(pane.items).toEqual [item1, item2, item3]
      expect(pane.activeItem).toBe item1

    it "does not assign an active item if no items are provided", ->
      pane = Pane.createAsRoot()
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
        item4 = pane.setActiveItem(new Item)
        expect(pane.activeItem).toBe item4
        expect(pane.items).toEqual [item1, item2, item4, item3]

    describe "if the pane has focus before making the item active and the item is focusable", ->
      it "focuses the item after adding it", ->
        expect(pane.hasFocus()).toBe false
        item4 = pane.setActiveItem(new Item)
        expect(item4.hasFocus()).toBe false

        pane.focused = true
        item5 = pane.setActiveItem(new Item)
        expect(item5.hasFocus()).toBe true
        expect(pane.hasFocus()).toBe true

  describe "::addItem(item)", ->
    describe "when the pane has no items", ->
      it "adds the item and makes it the active item", ->
        pane.removeItems()
        item4 = pane.addItem(new Item)
        expect(pane.items).toEqual [item4]
        expect(pane.activeItem).toBe item4

    describe "when the pane has items", ->
      it "adds the item after the active item", ->
        item4 = pane.addItem(new Item)
        expect(pane.activeItem).toBe pane.items.getFirst()
        expect(pane.items).toEqual [item1, item4, item2, item3]

  describe "::removeItem(item)", ->
    it "removes the specified item", ->
      expect(pane.activeItem).toBe item1
      pane.removeItem(item2)
      expect(pane.items).toEqual [item1, item3]
      expect(pane.activeItem).toBe item1

    describe "when the removed item is active", ->
      describe "when the removed item is the last item", ->
        it "sets the previous item as the new active item", ->
          pane.setActiveItem(item3)
          pane.removeItem(item3)
          expect(pane.activeItem).toBe item2

      describe "when the removed item is not the last item", ->
        it "sets the next item as the new active item", ->
          pane.setActiveItem(item2)
          pane.removeItem(item2)
          expect(pane.activeItem).toBe item3

      describe "when the removed item is the only item", ->
        it "sets the active item to undefined", ->
          pane.removeItem(item1)
          pane.removeItem(item2)
          pane.removeItem(item3)
          expect(pane.activeItem).toBeUndefined()

  describe "::moveItem(item, index)", ->
    it "moves the item to the given index", ->
      pane.moveItem(item1, 3)
      expect(pane.items).toEqual [item2, item3, item1]
      pane.moveItem(item2, 2)
      expect(pane.items).toEqual [item3, item2, item1]

  describe "split methods", ->
    pane1 = null

    beforeEach ->
      pane1 = pane

    describe "::splitLeft(items...)", ->
      it "inserts a new pane to the left, introducing a horizontal pane axis as a shared parent if needed", ->
        pane2 = pane1.splitLeft()
        expect(container.root.orientation).toBe 'horizontal'
        expect(container.root.children).toEqual [pane2, pane1]
        pane3 = pane1.splitLeft()
        expect(container.root.children).toEqual [pane2, pane3, pane1]

      it "creates the new pane with items if they are provided", ->
        pane2 = pane1.splitLeft({title: "Item 4"}, {title: "Item 5"})
        expect(pane2.items).toEqual [{title: "Item 4"}, {title: "Item 5"}]

    describe "::splitRight(items...)", ->
      it "inserts a new pane to the right, introducing a horizontal pane axis as a shared parent if needed", ->
        pane2 = pane1.splitRight()
        expect(container.root.orientation).toBe 'horizontal'
        expect(container.root.children).toEqual [pane1, pane2]
        pane3 = pane1.splitRight()
        expect(container.root.children).toEqual [pane1, pane3, pane2]

      it "creates the new pane with items if they are provided", ->
        pane2 = pane1.splitRight({title: "Item 4"}, {title: "Item 5"})
        expect(pane2.items).toEqual [{title: "Item 4"}, {title: "Item 5"}]

    describe "::splitUp(items...)", ->
      it "inserts a new pane to the right, introducing a horizontal pane axis as a shared parent if needed", ->
        pane2 = pane1.splitUp()
        expect(container.root.orientation).toBe 'vertical'
        expect(container.root.children).toEqual [pane2 ,pane1]
        pane3 = pane1.splitUp()
        expect(container.root.children).toEqual [pane2, pane3, pane1]

      it "creates the new pane with items if they are provided", ->
        pane2 = pane1.splitUp({title: "Item 4"}, {title: "Item 5"})
        expect(pane2.items).toEqual [{title: "Item 4"}, {title: "Item 5"}]

    describe "::splitDown(items...)", ->
      it "inserts a new pane to the right, introducing a horizontal pane axis as a shared parent if needed", ->
        pane2 = pane1.splitDown()
        expect(container.root.orientation).toBe 'vertical'
        expect(container.root.children).toEqual [pane1, pane2]
        pane3 = pane1.splitDown()
        expect(container.root.children).toEqual [pane1, pane3, pane2]

      it "creates the new pane with items if they are provided", ->
        pane2 = pane1.splitRight({title: "Item 4"}, {title: "Item 5"})
        expect(pane2.items).toEqual [{title: "Item 4"}, {title: "Item 5"}]
