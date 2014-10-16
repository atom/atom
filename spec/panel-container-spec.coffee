ViewRegistry = require '../src/view-registry'
Panel = require '../src/panel'
PanelContainer = require '../src/panel-container'

describe "PanelContainer", ->
  [container] = []

  class TestPanelItem
    constructior: ->

  beforeEach ->
    viewRegistry = new ViewRegistry
    container = new PanelContainer({viewRegistry})

  describe "::addPanel(panel)", ->
    it 'emits an onDidAddPanel event with the index the panel was inserted at', ->
      container.onDidAddPanel addPanelSpy = jasmine.createSpy()

      panel1 = new Panel(item: new TestPanelItem(), location: 'left')
      container.addPanel(panel1)
      expect(addPanelSpy).toHaveBeenCalledWith({panel: panel1, index: 0})

      panel2 = new Panel(item: new TestPanelItem(), location: 'left')
      container.addPanel(panel2)
      expect(addPanelSpy).toHaveBeenCalledWith({panel: panel2, index: 1})

  describe "when a panel is destroyed", ->
    it 'emits an onDidRemovePanel event with the index of the removed item', ->
      container.onDidRemovePanel removePanelSpy = jasmine.createSpy()

      panel1 = new Panel(item: new TestPanelItem(), location: 'left')
      container.addPanel(panel1)
      panel2 = new Panel(item: new TestPanelItem(), location: 'left')
      container.addPanel(panel2)

      expect(removePanelSpy).not.toHaveBeenCalled()

      panel2.destroy()
      expect(removePanelSpy).toHaveBeenCalledWith({panel: panel2, index: 1})

      panel1.destroy()
      expect(removePanelSpy).toHaveBeenCalledWith({panel: panel1, index: 0})
