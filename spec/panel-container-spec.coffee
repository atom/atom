Panel = require '../src/panel'
PanelContainer = require '../src/panel-container'

describe "PanelContainer", ->
  [container] = []

  class TestPanelItem
    constructior: ->

  beforeEach ->
    container = new PanelContainer

  describe "::addPanel(panel)", ->
    it 'emits an onDidAddPanel event with the index the panel was inserted at', ->
      container.onDidAddPanel addPanelSpy = jasmine.createSpy()

      panel1 = new Panel(item: new TestPanelItem())
      container.addPanel(panel1)
      expect(addPanelSpy).toHaveBeenCalledWith({panel: panel1, index: 0})

      panel2 = new Panel(item: new TestPanelItem())
      container.addPanel(panel2)
      expect(addPanelSpy).toHaveBeenCalledWith({panel: panel2, index: 1})

  describe "when a panel is destroyed", ->
    it 'emits an onDidRemovePanel event with the index of the removed item', ->
      container.onDidRemovePanel removePanelSpy = jasmine.createSpy()

      panel1 = new Panel(item: new TestPanelItem())
      container.addPanel(panel1)
      panel2 = new Panel(item: new TestPanelItem())
      container.addPanel(panel2)

      expect(removePanelSpy).not.toHaveBeenCalled()

      panel2.destroy()
      expect(removePanelSpy).toHaveBeenCalledWith({panel: panel2, index: 1})

      panel1.destroy()
      expect(removePanelSpy).toHaveBeenCalledWith({panel: panel1, index: 0})

  describe "panel priority", ->
    describe 'left / top panel container', ->
      [initialPanel] = []
      beforeEach ->
        # 'left' logic is the same as 'top'
        container = new PanelContainer({location: 'left'})
        initialPanel = new Panel(item: new TestPanelItem())
        container.addPanel(initialPanel)

      describe 'when a panel with low priority is added', ->
        it 'is inserted at the beginning of the list', ->
          container.onDidAddPanel addPanelSpy = jasmine.createSpy()
          panel = new Panel(item: new TestPanelItem(), priority: 0)
          container.addPanel(panel)

          expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})
          expect(container.getPanels()[0]).toBe panel

      describe 'when a panel with priority between two other panels is added', ->
        it 'is inserted at the between the two panels', ->
          panel = new Panel(item: new TestPanelItem(), priority: 1000)
          container.addPanel(panel)

          container.onDidAddPanel addPanelSpy = jasmine.createSpy()
          panel = new Panel(item: new TestPanelItem(), priority: 101)
          container.addPanel(panel)

          expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 1})
          expect(container.getPanels()[1]).toBe panel

    describe 'right / bottom panel container', ->
      [initialPanel] = []
      beforeEach ->
        # 'bottom' logic is the same as 'right'
        container = new PanelContainer({location: 'right'})
        initialPanel = new Panel(item: new TestPanelItem())
        container.addPanel(initialPanel)

      describe 'when a panel with high priority is added', ->
        it 'is inserted at the beginning of the list', ->
          container.onDidAddPanel addPanelSpy = jasmine.createSpy()
          panel = new Panel(item: new TestPanelItem(), priority: 1000)
          container.addPanel(panel)

          expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 0})
          expect(container.getPanels()[0]).toBe panel

      describe 'when a panel with low priority is added', ->
        it 'is inserted at the end of the list', ->
          container.onDidAddPanel addPanelSpy = jasmine.createSpy()
          panel = new Panel(item: new TestPanelItem(), priority: 0)
          container.addPanel(panel)

          expect(addPanelSpy).toHaveBeenCalledWith({panel, index: 1})
          expect(container.getPanels()[1]).toBe panel
