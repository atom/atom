ViewRegistry = require '../src/view-registry'
Panel = require '../src/panel'
PanelElement = require '../src/panel-element'
PanelContainer = require '../src/panel-container'
PanelContainerElement = require '../src/panel-container-element'

describe "PanelContainerElement", ->
  [jasmineContent, element, container, viewRegistry] = []

  class TestPanelContainerItem
    constructior: ->

  class TestPanelContainerItemElement extends HTMLElement
    createdCallback: ->
      @classList.add('test-root')
    setModel: (@model) ->
  TestPanelContainerItemElement = document.registerElement 'atom-test-container-item-element', prototype: TestPanelContainerItemElement.prototype

  beforeEach ->
    jasmineContent = document.body.querySelector('#jasmine-content')

    viewRegistry = new ViewRegistry
    viewRegistry.addViewProvider
      modelConstructor: Panel
      viewConstructor: PanelElement
    viewRegistry.addViewProvider
      modelConstructor: PanelContainer
      viewConstructor: PanelContainerElement
    viewRegistry.addViewProvider
      modelConstructor: TestPanelContainerItem
      viewConstructor: TestPanelContainerItemElement

    container = new PanelContainer({viewRegistry, location: 'left'})
    element = container.getView()
    jasmineContent.appendChild(element)

  it 'has a location class with value from the model', ->
    expect(element).toHaveClass 'left'

  it 'removes the element when the container is destroyed', ->
    expect(element.parentNode).toBe jasmineContent
    container.destroy()
    expect(element.parentNode).not.toBe jasmineContent

  describe "adding and removing panels", ->
    it "allows panels to be inserted at any position", ->
      panel1 = new Panel({viewRegistry, item: new TestPanelContainerItem(), priority: 10})
      panel2 = new Panel({viewRegistry, item: new TestPanelContainerItem(), priority: 5})
      panel3 = new Panel({viewRegistry, item: new TestPanelContainerItem(), priority: 8})

      container.addPanel(panel1)
      container.addPanel(panel2)
      container.addPanel(panel3)

      expect(element.childNodes[2].getModel()).toBe(panel1)
      expect(element.childNodes[1].getModel()).toBe(panel3)
      expect(element.childNodes[0].getModel()).toBe(panel2)

    describe "when the container is at the left location", ->
      it "adds atom-panel elements when a new panel is added to the container; removes them when the panels are destroyed", ->
        expect(element.childNodes.length).toBe 0

        panel1 = new Panel({viewRegistry, item: new TestPanelContainerItem()})
        container.addPanel(panel1)
        expect(element.childNodes.length).toBe 1
        expect(element.childNodes[0]).toHaveClass 'left'
        expect(element.childNodes[0]).toHaveClass 'tool-panel' # legacy selector support
        expect(element.childNodes[0]).toHaveClass 'panel-left' # legacy selector support

        expect(element.childNodes[0].tagName).toBe 'ATOM-PANEL'

        panel2 = new Panel({viewRegistry, item: new TestPanelContainerItem()})
        container.addPanel(panel2)
        expect(element.childNodes.length).toBe 2

        expect(panel1.getView().style.display).not.toBe 'none'
        expect(panel2.getView().style.display).not.toBe 'none'

        panel1.destroy()
        expect(element.childNodes.length).toBe 1

        panel2.destroy()
        expect(element.childNodes.length).toBe 0

    describe "when the container is at the bottom location", ->
      beforeEach ->
        container = new PanelContainer({viewRegistry, location: 'bottom'})
        element = container.getView()
        jasmineContent.appendChild(element)

      it "adds atom-panel elements when a new panel is added to the container; removes them when the panels are destroyed", ->
        expect(element.childNodes.length).toBe 0

        panel1 = new Panel({viewRegistry, item: new TestPanelContainerItem(), className: 'one'})
        container.addPanel(panel1)
        expect(element.childNodes.length).toBe 1
        expect(element.childNodes[0]).toHaveClass 'bottom'
        expect(element.childNodes[0]).toHaveClass 'tool-panel' # legacy selector support
        expect(element.childNodes[0]).toHaveClass 'panel-bottom' # legacy selector support
        expect(element.childNodes[0].tagName).toBe 'ATOM-PANEL'
        expect(panel1.getView()).toHaveClass 'one'

        panel2 = new Panel({viewRegistry, item: new TestPanelContainerItem(), className: 'two'})
        container.addPanel(panel2)
        expect(element.childNodes.length).toBe 2
        expect(panel2.getView()).toHaveClass 'two'

        panel1.destroy()
        expect(element.childNodes.length).toBe 1

        panel2.destroy()
        expect(element.childNodes.length).toBe 0

  describe "when the container is modal", ->
    beforeEach ->
      container = new PanelContainer({viewRegistry, location: 'modal'})
      element = container.getView()
      jasmineContent.appendChild(element)

    it "allows only one panel to be visible at a time", ->
      panel1 = new Panel({viewRegistry, item: new TestPanelContainerItem()})
      container.addPanel(panel1)

      expect(panel1.getView().style.display).not.toBe 'none'

      panel2 = new Panel({viewRegistry, item: new TestPanelContainerItem()})
      container.addPanel(panel2)

      expect(panel1.getView().style.display).toBe 'none'
      expect(panel2.getView().style.display).not.toBe 'none'

      panel1.show()

      expect(panel1.getView().style.display).not.toBe 'none'
      expect(panel2.getView().style.display).toBe 'none'

    it "adds the 'modal' class to panels", ->
      panel1 = new Panel({viewRegistry, item: new TestPanelContainerItem()})
      container.addPanel(panel1)

      expect(panel1.getView()).toHaveClass 'modal'

      # legacy selector support
      expect(panel1.getView()).not.toHaveClass 'tool-panel'
      expect(panel1.getView()).toHaveClass 'overlay'
      expect(panel1.getView()).toHaveClass 'from-top'
