ViewRegistry = require '../src/view-registry'
Panel = require '../src/panel'
PanelElement = require '../src/panel-element'
PanelContainer = require '../src/panel-container'
PanelContainerElement = require '../src/panel-container-element'

describe "PanelContainerElement", ->
  [jasmineContent, element, container, viewRegistry] = []

  class TestPanelItem
    constructior: ->

  class TestPanelItemElement extends HTMLElement
    createdCallback: ->
      @classList.add('test-root')
    setModel: (@model) ->
  TestPanelItemElement = document.registerElement 'atom-test-item-element', prototype: TestPanelItemElement.prototype

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
      modelConstructor: TestPanelItem
      viewConstructor: TestPanelItemElement

    container = new PanelContainer({viewRegistry, orientation: 'left'})
    element = container.getView()
    jasmineContent.appendChild(element)

  it 'has an oritation attribute with value from the model', ->
    expect(element.getAttribute('orientation')).toBe 'left'

  it 'removes the element when the container is destroyed', ->
    expect(element.parentNode).toBe jasmineContent
    container.destroy()
    expect(element.parentNode).not.toBe jasmineContent

  describe "adding and removing panels", ->
    it "adds atom-panel elements when a new panel is added to the container; removes them when the panels are destroyed", ->
      expect(element.childNodes.length).toBe 0

      panel1 = new Panel({viewRegistry, item: new TestPanelItem(), orientation: 'left'})
      container.addPanel(panel1)
      expect(element.childNodes.length).toBe 1

      expect(element.childNodes[0].tagName).toBe 'ATOM-PANEL'

      panel2 = new Panel({viewRegistry, item: new TestPanelItem(), orientation: 'left'})
      container.addPanel(panel2)
      expect(element.childNodes.length).toBe 2

      panel1.destroy()
      expect(element.childNodes.length).toBe 1

      panel2.destroy()
      expect(element.childNodes.length).toBe 0
