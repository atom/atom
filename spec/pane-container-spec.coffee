PaneContainer = require '../src/pane-container'

describe "PaneContainer", ->
  container = null

  beforeEach ->
    container = PaneContainer.createAsRoot()

  describe "::createPane()", ->
    describe "when there are no panes", ->
      fit "creates a single pane as the root", ->
        pane = container.createPane(project.open('sample.js'))
        expect(container.panes).toEqual [pane]
        expect(container.root).toBe pane
