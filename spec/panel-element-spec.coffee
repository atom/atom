Panel = require '../src/panel'
PanelElement = require '../src/panel-element'
ViewRegistry = require '../src/view-registry'

describe "PanelElement", ->
  [jasmineContent, element, panel, viewRegistry] = []

  class TestPanelItem
    constructior: ->

  class TestPanelItemElement extends HTMLElement
    createdCallback: ->
      @classList.add('test-root')
    initialize: ({@model}) ->
  TestPanelItemElement = document.registerElement 'atom-test-item-element', prototype: TestPanelItemElement.prototype

  beforeEach ->
    jasmineContent = document.body.querySelector('#jasmine-content')

    atom.views.addViewProvider
      modelConstructor: Panel
      viewConstructor: PanelElement
    atom.views.addViewProvider
      modelConstructor: TestPanelItem
      viewConstructor: TestPanelItemElement

    viewRegistry = new ViewRegistry(atom.views)

  it "renders a view for the panel's item", ->
    panel = new Panel({item: new TestPanelItem})
    element = atom.views.createView(panel, {viewRegistry})
    jasmineContent.appendChild(element)
    expect(element.firstChild).toBe viewRegistry.getView(panel.getItem())

  it 'removes the element when the panel is destroyed', ->
    panel = new Panel({item: new TestPanelItem})
    element = atom.views.createView(panel, {viewRegistry})
    jasmineContent.appendChild(element)

    expect(element.parentNode).toBe jasmineContent
    panel.destroy()
    expect(element.parentNode).not.toBe jasmineContent

  describe "changing panel visibility", ->
    it 'initially renders panel created with visibile: false', ->
      panel = new Panel({visible: false, item: new TestPanelItem})
      element = atom.views.createView(panel, {viewRegistry})
      jasmineContent.appendChild(element)

      expect(element.style.display).toBe 'none'

    it 'hides and shows the panel element when Panel::hide() and Panel::show() are called', ->
      panel = new Panel({item: new TestPanelItem})
      element = atom.views.createView(panel, {viewRegistry})
      jasmineContent.appendChild(element)

      expect(element.style.display).not.toBe 'none'

      panel.hide()
      expect(element.style.display).toBe 'none'

      panel.show()
      expect(element.style.display).not.toBe 'none'

  describe "when a class name is specified", ->
    it 'initially renders panel created with visibile: false', ->
      panel = new Panel({className: 'some classes', item: new TestPanelItem})
      element = atom.views.createView(panel, {viewRegistry})
      jasmineContent.appendChild(element)

      expect(element).toHaveClass 'some'
      expect(element).toHaveClass 'classes'
