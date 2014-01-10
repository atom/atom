PaneContainerModel = require '../src/pane-container-model'
PaneModel = require '../src/pane-model'

describe "PaneContainerModel", ->
  describe "serialization", ->
    it "preserves the focused pane across serialization", ->
      pane1A = new PaneModel
      containerA = new PaneContainerModel(root: pane1A)
      pane2A = pane1A.splitRight()
      pane3A = pane2A.splitDown()
      expect(pane3A.focused).toBe true

      containerB = containerA.testSerialization()
      [pane1B, pane2B, pane3B] = containerB.getPanes()
      expect(pane3B.focusContext).toBe containerB.focusContext
      expect(pane3B.focused).toBe true

  describe "::activePane", ->
    [container, pane1, pane2] = []

    beforeEach ->
      pane1 = new PaneModel
      container = new PaneContainerModel(root: pane1)

    it "references the first pane if no pane has been focused", ->
      expect(container.activePane).toBe pane1
      expect(pane1.active).toBe true

    it "references the most recently focused pane", ->
      pane2 = pane1.splitRight()
      expect(container.activePane).toBe pane2
      expect(pane1.active).toBe false
      expect(pane2.active).toBe true
      pane1.focus()
      expect(container.activePane).toBe pane1
      expect(pane1.active).toBe true
      expect(pane2.active).toBe false

    it "is reassigned to the next pane if the current active pane is unfocused and destroyed", ->
      pane2 = pane1.splitRight()
      pane2.blur()
      pane2.destroy()
      expect(container.activePane).toBe pane1
      expect(pane1.active).toBe true
      pane1.destroy()
      expect(container.activePane).toBe null
