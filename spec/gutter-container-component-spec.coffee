Gutter = require '../src/gutter'
GutterContainerComponent = require '../src/gutter-container-component'
DOMElementPool = require '../src/dom-element-pool'

describe "GutterContainerComponent", ->
  [gutterContainerComponent] = []
  mockGutterContainer = {}

  buildTestState = (gutters) ->
    styles =
      scrollHeight: 100
      scrollTop: 10
      backgroundColor: 'black'

    mockTestState = {gutters: []}
    for gutter in gutters
      if gutter.name is 'line-number'
        content = {maxLineNumberDigits: 10, lineNumbers: {}}
      else
        content = {}
      mockTestState.gutters.push({gutter, styles, content, visible: gutter.visible})

    mockTestState

  beforeEach ->
    domElementPool = new DOMElementPool
    mockEditor = {}
    mockMouseDown = ->
    gutterContainerComponent = new GutterContainerComponent({editor: mockEditor, onMouseDown: mockMouseDown, domElementPool, views: atom.views})

  it "creates a DOM node with no child gutter nodes when it is initialized", ->
    expect(gutterContainerComponent.getDomNode() instanceof HTMLElement).toBe true
    expect(gutterContainerComponent.getDomNode().children.length).toBe 0

  describe "when updated with state that contains a new line-number gutter", ->
    it "adds a LineNumberGutterComponent to its children", ->
      lineNumberGutter = new Gutter(mockGutterContainer, {name: 'line-number'})
      testState = buildTestState([lineNumberGutter])

      expect(gutterContainerComponent.getDomNode().children.length).toBe 0
      gutterContainerComponent.updateSync(testState)
      expect(gutterContainerComponent.getDomNode().children.length).toBe 1
      expectedGutterNode = gutterContainerComponent.getDomNode().children.item(0)
      expect(expectedGutterNode.classList.contains('gutter')).toBe true
      expectedLineNumbersNode = expectedGutterNode.children.item(0)
      expect(expectedLineNumbersNode.classList.contains('line-numbers')).toBe true

      expect(gutterContainerComponent.getLineNumberGutterComponent().getDomNode()).toBe expectedGutterNode

  describe "when updated with state that contains a new custom gutter", ->
    it "adds a CustomGutterComponent to its children", ->
      customGutter = new Gutter(mockGutterContainer, {name: 'custom'})
      testState = buildTestState([customGutter])

      expect(gutterContainerComponent.getDomNode().children.length).toBe 0
      gutterContainerComponent.updateSync(testState)
      expect(gutterContainerComponent.getDomNode().children.length).toBe 1
      expectedGutterNode = gutterContainerComponent.getDomNode().children.item(0)
      expect(expectedGutterNode.classList.contains('gutter')).toBe true
      expectedCustomDecorationsNode = expectedGutterNode.children.item(0)
      expect(expectedCustomDecorationsNode.classList.contains('custom-decorations')).toBe true

  describe "when updated with state that contains a new gutter that is not visible", ->
    it "creates the gutter view but hides it, and unhides it when it is later updated to be visible", ->
      customGutter = new Gutter(mockGutterContainer, {name: 'custom', visible: false})
      testState = buildTestState([customGutter])

      gutterContainerComponent.updateSync(testState)
      expect(gutterContainerComponent.getDomNode().children.length).toBe 1
      expectedCustomGutterNode = gutterContainerComponent.getDomNode().children.item(0)
      expect(expectedCustomGutterNode.style.display).toBe 'none'

      customGutter.show()
      testState = buildTestState([customGutter])
      gutterContainerComponent.updateSync(testState)
      expect(gutterContainerComponent.getDomNode().children.length).toBe 1
      expectedCustomGutterNode = gutterContainerComponent.getDomNode().children.item(0)
      expect(expectedCustomGutterNode.style.display).toBe ''

  describe "when updated with a gutter that already exists", ->
    it "reuses the existing gutter view, instead of recreating it", ->
      customGutter = new Gutter(mockGutterContainer, {name: 'custom'})
      testState = buildTestState([customGutter])

      gutterContainerComponent.updateSync(testState)
      expect(gutterContainerComponent.getDomNode().children.length).toBe 1
      expectedCustomGutterNode = gutterContainerComponent.getDomNode().children.item(0)

      testState = buildTestState([customGutter])
      gutterContainerComponent.updateSync(testState)
      expect(gutterContainerComponent.getDomNode().children.length).toBe 1
      expect(gutterContainerComponent.getDomNode().children.item(0)).toBe expectedCustomGutterNode

  it "removes a gutter from the DOM if it does not appear in the latest state update", ->
    lineNumberGutter = new Gutter(mockGutterContainer, {name: 'line-number'})
    testState = buildTestState([lineNumberGutter])
    gutterContainerComponent.updateSync(testState)

    expect(gutterContainerComponent.getDomNode().children.length).toBe 1
    testState = buildTestState([])
    gutterContainerComponent.updateSync(testState)
    expect(gutterContainerComponent.getDomNode().children.length).toBe 0

  describe "when updated with multiple gutters", ->
    it "positions (and repositions) the gutters to match the order they appear in each state update", ->
      lineNumberGutter = new Gutter(mockGutterContainer, {name: 'line-number'})
      customGutter1 = new Gutter(mockGutterContainer, {name: 'custom', priority: -100})
      testState = buildTestState([customGutter1, lineNumberGutter])

      gutterContainerComponent.updateSync(testState)
      expect(gutterContainerComponent.getDomNode().children.length).toBe 2
      expectedCustomGutterNode = gutterContainerComponent.getDomNode().children.item(0)
      expect(expectedCustomGutterNode).toBe customGutter1.getElement()
      expectedLineNumbersNode = gutterContainerComponent.getDomNode().children.item(1)
      expect(expectedLineNumbersNode).toBe lineNumberGutter.getElement()

      # Add a gutter.
      customGutter2 = new Gutter(mockGutterContainer, {name: 'custom2', priority: -10})
      testState = buildTestState([customGutter1, customGutter2, lineNumberGutter])
      gutterContainerComponent.updateSync(testState)
      expect(gutterContainerComponent.getDomNode().children.length).toBe 3
      expectedCustomGutterNode1 = gutterContainerComponent.getDomNode().children.item(0)
      expect(expectedCustomGutterNode1).toBe customGutter1.getElement()
      expectedCustomGutterNode2 = gutterContainerComponent.getDomNode().children.item(1)
      expect(expectedCustomGutterNode2).toBe customGutter2.getElement()
      expectedLineNumbersNode = gutterContainerComponent.getDomNode().children.item(2)
      expect(expectedLineNumbersNode).toBe lineNumberGutter.getElement()

      # Hide one gutter, reposition one gutter, remove one gutter; and add a new gutter.
      customGutter2.hide()
      customGutter3 = new Gutter(mockGutterContainer, {name: 'custom3', priority: 100})
      testState = buildTestState([customGutter2, customGutter1, customGutter3])
      gutterContainerComponent.updateSync(testState)
      expect(gutterContainerComponent.getDomNode().children.length).toBe 3
      expectedCustomGutterNode2 = gutterContainerComponent.getDomNode().children.item(0)
      expect(expectedCustomGutterNode2).toBe customGutter2.getElement()
      expect(expectedCustomGutterNode2.style.display).toBe 'none'
      expectedCustomGutterNode1 = gutterContainerComponent.getDomNode().children.item(1)
      expect(expectedCustomGutterNode1).toBe customGutter1.getElement()
      expectedCustomGutterNode3 = gutterContainerComponent.getDomNode().children.item(2)
      expect(expectedCustomGutterNode3).toBe customGutter3.getElement()

    it "reorders correctly when prepending multiple gutters at once", ->
      lineNumberGutter = new Gutter(mockGutterContainer, {name: 'line-number'})
      testState = buildTestState([lineNumberGutter])
      gutterContainerComponent.updateSync(testState)
      expect(gutterContainerComponent.getDomNode().children.length).toBe 1
      expectedCustomGutterNode = gutterContainerComponent.getDomNode().children.item(0)
      expect(expectedCustomGutterNode).toBe lineNumberGutter.getElement()

      # Prepend two gutters at once
      customGutter1 = new Gutter(mockGutterContainer, {name: 'first', priority: -200})
      customGutter2 = new Gutter(mockGutterContainer, {name: 'second', priority: -100})
      testState = buildTestState([customGutter1, customGutter2, lineNumberGutter])
      gutterContainerComponent.updateSync(testState)
      expect(gutterContainerComponent.getDomNode().children.length).toBe 3
      expectedCustomGutterNode1 = gutterContainerComponent.getDomNode().children.item(0)
      expect(expectedCustomGutterNode1).toBe customGutter1.getElement()
      expectedCustomGutterNode2 = gutterContainerComponent.getDomNode().children.item(1)
      expect(expectedCustomGutterNode2).toBe customGutter2.getElement()
