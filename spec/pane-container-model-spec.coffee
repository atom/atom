PaneContainerModel = require '../src/pane-container-model'
PaneModel = require '../src/pane-model'

describe "PaneContainerModel", ->
  describe "serialization", ->
    [containerA, pane1A, pane2A, pane3A] = []

    beforeEach ->
      pane1A = new PaneModel
      containerA = new PaneContainerModel(root: pane1A)
      pane2A = pane1A.splitRight()
      pane3A = pane2A.splitDown()

    it "preserves the focused pane across serialization", ->
      expect(pane3A.focused).toBe true

      containerB = containerA.testSerialization()
      [pane1B, pane2B, pane3B] = containerB.getPanes()
      expect(pane3B.focusContext).toBe containerB.focusContext
      expect(pane3B.focused).toBe true

    it "preserves the active pane across serialization, independent of focus", ->
      pane3A.blur()
      expect(containerA.activePane).toBe pane3A

      containerB = containerA.testSerialization()
      [pane1B, pane2B, pane3B] = containerB.getPanes()
      expect(containerB.activePane).toBe pane3B

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

  # TODO: Remove this behavior when we have a proper workspace model we can explicitly focus
  describe "when the last pane is removed", ->
    [container, pane, surrenderedFocusHandler] = []

    beforeEach ->
      pane = new PaneModel
      container = new PaneContainerModel(root: pane)
      container.on 'surrendered-focus', surrenderedFocusHandler = jasmine.createSpy("surrenderedFocusHandler")

    describe "if the pane is focused", ->
      it "emits a 'surrendered-focus' event", ->
        pane.focus()
        pane.destroy()
        expect(surrenderedFocusHandler).toHaveBeenCalled()

    describe "if the pane is not focused", ->
      it "does not emit an event", ->
        expect(pane.focused).toBe false
        expect(surrenderedFocusHandler).not.toHaveBeenCalled()
