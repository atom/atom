PaneContainer = require '../src/pane-container'

describe "PaneContainer", ->
  container = null

  beforeEach ->
    container = PaneContainer.createAsRoot()

  describe "::createPane(items...)", ->
    describe "when there are no panes", ->
      it "creates a single pane as the root", ->
        pane = container.createPane(project.open('sample.js'))
        expect(container.panes).toEqual [pane]
        expect(container.root).toBe pane

  fdescribe "when a pane is split", ->
    pane1 = null

    beforeEach ->
      pane1 = container.createPane({})

    describe "when the pane is not contained by a PaneAxis of the desired split orientation", ->
      it "replaces the pane with a correctly-oriented PaneAxis containing two panes", ->
        pane2 = pane1.splitRight()
        expect(container.root.orientation).toBe 'horizontal'
        expect(container.root.children).toEqual [pane1, pane2]
