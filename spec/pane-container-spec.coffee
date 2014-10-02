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
        getUri: -> 'test'

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
