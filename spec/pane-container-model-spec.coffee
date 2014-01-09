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
      [pane1A, pane2A, pane3A] = containerB.getPanes()
      expect(pane3A.focusContext).toBe containerB.focusContext
      expect(pane3A.focused).toBe true
