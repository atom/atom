PaneAxis = require '../src/pane-axis'
PaneContainer = require '../src/pane-container'
Pane = require '../src/pane'

buildPane = ->
  new Pane({
    applicationDelegate: atom.applicationDelegate,
    config: atom.config,
    deserializerManager: atom.deserializers,
    notificationManager: atom.notifications
  })

describe "PaneAxisElement", ->
  it "correctly subscribes and unsubscribes to the underlying model events on attach/detach", ->
    container = new PaneContainer(config: atom.config, applicationDelegate: atom.applicationDelegate)
    axis = new PaneAxis
    axis.setContainer(container)
    axisElement = atom.views.getView(axis)

    panes = [buildPane(), buildPane(), buildPane()]

    jasmine.attachToDOM(axisElement)
    axis.addChild(panes[0])
    expect(axisElement.children[0]).toBe(atom.views.getView(panes[0]))

    axisElement.remove()
    axis.addChild(panes[1])
    expect(axisElement.children[2]).toBeUndefined()

    jasmine.attachToDOM(axisElement)
    expect(axisElement.children[2]).toBe(atom.views.getView(panes[1]))

    axis.addChild(panes[2])
    expect(axisElement.children[4]).toBe(atom.views.getView(panes[2]))
