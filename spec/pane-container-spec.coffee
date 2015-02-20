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
      pane3A.focus()

    it "preserves the focused pane across serialization", ->
      expect(pane3A.focused).toBe true

      containerB = containerA.testSerialization()
      [pane1B, pane2B, pane3B] = containerB.getPanes()
      expect(pane3B.focused).toBe true

    it "preserves the active pane across serialization, independent of focus", ->
      pane3A.activate()
      expect(containerA.getActivePane()).toBe pane3A

      containerB = containerA.testSerialization()
      [pane1B, pane2B, pane3B] = containerB.getPanes()
      expect(containerB.getActivePane()).toBe pane3B

    it "makes the first pane active if no pane exists for the activePaneId", ->
      pane3A.activate()
      state = containerA.serialize()
      state.activePaneId = -22
      containerB = atom.deserializers.deserialize(state)
      expect(containerB.getActivePane()).toBe containerB.getPanes()[0]

  it "does not allow the root pane to be destroyed", ->
    container = new PaneContainer
    container.getRoot().destroy()
    expect(container.getRoot()).toBeDefined()
    expect(container.getRoot().isDestroyed()).toBe false

  describe "::getActivePane()", ->
    [container, pane1, pane2] = []

    beforeEach ->
      container = new PaneContainer
      pane1 = container.getRoot()

    it "returns the first pane if no pane has been made active", ->
      expect(container.getActivePane()).toBe pane1
      expect(pane1.isActive()).toBe true

    it "returns the most pane on which ::activate() was most recently called", ->
      pane2 = pane1.splitRight()
      pane2.activate()
      expect(container.getActivePane()).toBe pane2
      expect(pane1.isActive()).toBe false
      expect(pane2.isActive()).toBe true
      pane1.activate()
      expect(container.getActivePane()).toBe pane1
      expect(pane1.isActive()).toBe true
      expect(pane2.isActive()).toBe false

    it "returns the next pane if the current active pane is destroyed", ->
      pane2 = pane1.splitRight()
      pane2.activate()
      pane2.destroy()
      expect(container.getActivePane()).toBe pane1
      expect(pane1.isActive()).toBe true

  describe "::onDidChangeActivePaneItem()", ->
    [container, pane1, pane2, observed] = []

    beforeEach ->
      container = new PaneContainer(root: new Pane(items: [new Object, new Object]))
      container.getRoot().splitRight(items: [new Object, new Object])
      [pane1, pane2] = container.getPanes()

      observed = []
      container.onDidChangeActivePaneItem (item) -> observed.push(item)

    it "invokes observers when the active item of the active pane changes", ->
      pane2.activateNextItem()
      pane2.activateNextItem()
      expect(observed).toEqual [pane2.itemAtIndex(1), pane2.itemAtIndex(0)]

    it "invokes observers when the active pane changes", ->
      pane1.activate()
      pane2.activate()
      expect(observed).toEqual [pane1.itemAtIndex(0), pane2.itemAtIndex(0)]

  describe "::observePanes()", ->
    it "invokes observers with all current and future panes", ->
      container = new PaneContainer
      container.getRoot().splitRight()
      [pane1, pane2] = container.getPanes()

      observed = []
      container.observePanes (pane) -> observed.push(pane)

      pane3 = pane2.splitDown()
      pane4 = pane2.splitRight()

      expect(observed).toEqual [pane1, pane2, pane3, pane4]

  describe "::observePaneItems()", ->
    it "invokes observers with all current and future pane items", ->
      container = new PaneContainer(root: new Pane(items: [new Object, new Object]))
      container.getRoot().splitRight(items: [new Object])
      [pane1, pane2] = container.getPanes()
      observed = []
      container.observePaneItems (pane) -> observed.push(pane)

      pane3 = pane2.splitDown(items: [new Object])
      pane3.addItems([new Object, new Object])

      expect(observed).toEqual container.getPaneItems()

  describe "::confirmClose()", ->
    [container, pane1, pane2] = []

    beforeEach ->
      class TestItem
        shouldPromptToSave: -> true
        getURI: -> 'test'

      container = new PaneContainer
      container.getRoot().splitRight()
      [pane1, pane2] = container.getPanes()
      pane1.addItem(new TestItem)
      pane2.addItem(new TestItem)

    it "returns true if the user saves all modified files when prompted", ->
      spyOn(atom, "confirm").andReturn(0)
      saved = container.confirmClose()
      expect(saved).toBeTruthy()
      expect(atom.confirm).toHaveBeenCalled()

    it "returns false if the user cancels saving any modified file", ->
      spyOn(atom, "confirm").andReturn(1)
      saved = container.confirmClose()
      expect(saved).toBeFalsy()
      expect(atom.confirm).toHaveBeenCalled()

  describe "::onDidAddPane(callback)", ->
    it "invokes the given callback when panes are added", ->
      container = new PaneContainer
      events = []
      container.onDidAddPane (event) -> events.push(event)

      pane1 = container.getActivePane()
      pane2 = pane1.splitRight()
      pane3 = pane2.splitDown()

      expect(events).toEqual [{pane: pane2}, {pane: pane3}]

  describe "::onDidDestroyPane(callback)", ->
    it "invokes the given callback when panes are destroyed", ->
      container = new PaneContainer
      events = []
      container.onDidDestroyPane (event) -> events.push(event)

      pane1 = container.getActivePane()
      pane2 = pane1.splitRight()
      pane3 = pane2.splitDown()

      pane2.destroy()
      pane3.destroy()

      expect(events).toEqual [{pane: pane2}, {pane: pane3}]

  describe "::onWillDestroyPaneItem() and ::onDidDestroyPaneItem", ->
    it "invokes the given callbacks when an item will be destroyed on any pane", ->
      container = new PaneContainer
      pane1 = container.getRoot()
      item1 = new Object
      item2 = new Object
      item3 = new Object

      pane1.addItem(item1)
      events = []
      container.onWillDestroyPaneItem (event) -> events.push(['will', event])
      container.onDidDestroyPaneItem (event) -> events.push(['did', event])
      pane2 = pane1.splitRight(items: [item2, item3])

      pane1.destroyItem(item1)
      pane2.destroyItem(item3)
      pane2.destroyItem(item2)

      expect(events).toEqual [
        ['will', {item: item1, pane: pane1, index: 0}]
        ['did', {item: item1, pane: pane1, index: 0}]
        ['will', {item: item3, pane: pane2, index: 1}]
        ['did', {item: item3, pane: pane2, index: 1}]
        ['will', {item: item2, pane: pane2, index: 0}]
        ['did', {item: item2, pane: pane2, index: 0}]
      ]
