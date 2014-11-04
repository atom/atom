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

  it 'has a location attribute with value from the model', ->
    expect(element.getAttribute('location')).toBe 'left'

  it 'removes the element when the container is destroyed', ->
    expect(element.parentNode).toBe jasmineContent
    container.destroy()
    expect(element.parentNode).not.toBe jasmineContent

  describe "adding and removing panels", ->
    it "adds atom-panel elements when a new panel is added to the container; removes them when the panels are destroyed", ->
      expect(element.childNodes.length).toBe 0

      panel1 = new Panel({viewRegistry, item: new TestPanelContainerItem(), location: 'left'})
      container.addPanel(panel1)
      expect(element.childNodes.length).toBe 1
      expect(element.childNodes[0].getAttribute('location')).toBe 'left'

      expect(element.childNodes[0].tagName).toBe 'ATOM-PANEL'

      panel2 = new Panel({viewRegistry, item: new TestPanelContainerItem(), location: 'left'})
      container.addPanel(panel2)
      expect(element.childNodes.length).toBe 2

      expect(panel1.getView().style.display).not.toBe 'none'
      expect(panel2.getView().style.display).not.toBe 'none'

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
