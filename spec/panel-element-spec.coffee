ViewRegistry = require '../src/view-registry'
Panel = require '../src/panel'
PanelElement = require '../src/panel-element'

describe "PanelElement", ->
  [jasmineContent, element, panel, viewRegistry] = []

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
      modelConstructor: TestPanelItem
      viewConstructor: TestPanelItemElement

  it 'removes the element when the panel is destroyed', ->
    panel = new Panel({viewRegistry, item: new TestPanelItem})
    element = panel.getView()
    jasmineContent.appendChild(element)

    expect(element.parentNode).toBe jasmineContent
    panel.destroy()
    expect(element.parentNode).not.toBe jasmineContent

  describe "changing panel visibility", ->
    it 'initially renders panel created with visibile: false', ->
      panel = new Panel({viewRegistry, visible: false, item: new TestPanelItem})
      element = panel.getView()
      jasmineContent.appendChild(element)

      expect(element.style.display).toBe 'none'

    it 'hides and shows the panel element when Panel::hide() and Panel::show() are called', ->
      panel = new Panel({viewRegistry, item: new TestPanelItem})
      element = panel.getView()
      jasmineContent.appendChild(element)

      expect(element.style.display).not.toBe 'none'

      panel.hide()
      expect(element.style.display).toBe 'none'

      panel.show()
      expect(element.style.display).not.toBe 'none'

  describe "when a class name is specified", ->
    it 'initially renders panel created with visibile: false', ->
      panel = new Panel({viewRegistry, className: 'some classes', item: new TestPanelItem})
      element = panel.getView()
      jasmineContent.appendChild(element)

      expect(element).toHaveClass 'some'
      expect(element).toHaveClass 'classes'
