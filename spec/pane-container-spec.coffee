PaneContainer = require '../src/pane-container'
Pane = require '../src/pane'

describe "PaneContainer", ->
  describe "serialization", ->
    [containerA, pane1A, pane2A, pane3A] = []

    beforeEach ->
      # This is a dummy item to prevent panes from being empty on deserialization
      class Item
        atom.deserializers.add(this)
        @deserialize: -> new this
        serialize: -> deserializer: 'Item'

      pane1A = new Pane(items: [new Item])
      containerA = new PaneContainer(root: pane1A)
      pane2A = pane1A.splitRight(items: [new Item])
      pane3A = pane2A.splitDown(items: [new Item])

    it "preserves the focused pane across serialization", ->
      expect(pane3A.focused).toBe true

      containerB = containerA.testSerialization()
      [pane1B, pane2B, pane3B] = containerB.getPanes()
      expect(pane3B.focused).toBe true

    it "preserves the active pane across serialization, independent of focus", ->
      pane3A.activate()
      expect(containerA.activePane).toBe pane3A

      containerB = containerA.testSerialization()
      [pane1B, pane2B, pane3B] = containerB.getPanes()
      expect(containerB.activePane).toBe pane3B

  describe "::activePane", ->
    [container, pane1, pane2] = []

    beforeEach ->
      container = new PaneContainer
      pane1 = container.root

    it "references the first pane if no pane has been made active", ->
      expect(container.activePane).toBe pane1
      expect(pane1.active).toBe true

    it "references the most pane on which ::activate was most recently called", ->
      pane2 = pane1.splitRight()
      pane2.activate()
      expect(container.activePane).toBe pane2
      expect(pane1.active).toBe false
      expect(pane2.active).toBe true
      pane1.activate()
      expect(container.activePane).toBe pane1
      expect(pane1.active).toBe true
      expect(pane2.active).toBe false

    it "is reassigned to the next pane if the current active pane is destroyed", ->
      pane2 = pane1.splitRight()
      pane2.activate()
      pane2.destroy()
      expect(container.activePane).toBe pane1
      expect(pane1.active).toBe true

    it "does not allow the root pane to be destroyed", ->
      pane1.destroy()
      expect(container.root).toBe pane1
      expect(pane1.isDestroyed()).toBe false
