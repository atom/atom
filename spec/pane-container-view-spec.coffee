PaneContainerView = require '../src/pane-container-view'
PaneContainer = require '../src/pane-container'

describe "PaneContainerView", ->
  [container, view] = []

  beforeEach ->
    container = PaneContainer.createAsRoot()
    # view = new PaneContainerView(container)

  fit "evenly divides the container into horizontal and vertical grid units", ->
    console.log container.$root
