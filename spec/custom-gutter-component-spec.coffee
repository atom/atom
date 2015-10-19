CustomGutterComponent = require '../src/custom-gutter-component'
Gutter = require '../src/gutter'

describe "CustomGutterComponent", ->
  [gutterComponent, gutter] = []

  beforeEach ->
    mockGutterContainer = {}
    gutter = new Gutter(mockGutterContainer, {name: 'test-gutter'})
    gutterComponent = new CustomGutterComponent({gutter, views: atom.views})

  it "creates a gutter DOM node with only an empty 'custom-decorations' child node when it is initialized", ->
    expect(gutterComponent.getDomNode().classList.contains('gutter')).toBe true
    expect(gutterComponent.getDomNode().getAttribute('gutter-name')).toBe 'test-gutter'
    expect(gutterComponent.getDomNode().children.length).toBe 1
    decorationsWrapperNode = gutterComponent.getDomNode().children.item(0)
    expect(decorationsWrapperNode.classList.contains('custom-decorations')).toBe true

  it "makes its view accessible from the view registry", ->
    expect(gutterComponent.getDomNode()).toBe atom.views.getView(gutter)

  it "hides its DOM node when ::hideNode is called, and shows its DOM node when ::showNode is called", ->
    gutterComponent.hideNode()
    expect(gutterComponent.getDomNode().style.display).toBe 'none'
    gutterComponent.showNode()
    expect(gutterComponent.getDomNode().style.display).toBe ''

  describe "::updateSync", ->
    decorationItem1 = document.createElement('div')

    buildTestState = (customDecorations) ->
      mockTestState =
        content: if customDecorations then customDecorations else {}
        styles:
          scrollHeight: 100
          scrollTop: 10
          backgroundColor: 'black'

      mockTestState

    it "sets the custom-decoration wrapper's scrollHeight, scrollTop, and background color", ->
      decorationsWrapperNode = gutterComponent.getDomNode().children.item(0)
      expect(decorationsWrapperNode.style.height).toBe ''
      expect(decorationsWrapperNode.style['-webkit-transform']).toBe ''
      expect(decorationsWrapperNode.style.backgroundColor).toBe ''

      gutterComponent.updateSync(buildTestState({}))
      expect(decorationsWrapperNode.style.height).not.toBe ''
      expect(decorationsWrapperNode.style['-webkit-transform']).not.toBe ''
      expect(decorationsWrapperNode.style.backgroundColor).not.toBe ''

    it "creates a new DOM node for a new decoration and adds it to the gutter at the right place", ->
      customDecorations =
        'decoration-id-1':
          top: 0
          height: 10
          item: decorationItem1
          class: 'test-class-1'

      gutterComponent.updateSync(buildTestState(customDecorations))
      decorationsWrapperNode = gutterComponent.getDomNode().children.item(0)
      expect(decorationsWrapperNode.children.length).toBe 1

      decorationNode = decorationsWrapperNode.children.item(0)
      expect(decorationNode.style.top).toBe '0px'
      expect(decorationNode.style.height).toBe '10px'
      expect(decorationNode.classList.contains('test-class-1')).toBe true
      expect(decorationNode.classList.contains('decoration')).toBe true
      expect(decorationNode.children.length).toBe 1

      decorationItem = decorationNode.children.item(0)
      expect(decorationItem).toBe decorationItem1

    it "updates the existing DOM node for a decoration that existed but has new properties", ->
      initialCustomDecorations =
        'decoration-id-1':
          top: 0
          height: 10
          item: decorationItem1
          class: 'test-class-1'
      gutterComponent.updateSync(buildTestState(initialCustomDecorations))
      initialDecorationNode = gutterComponent.getDomNode().children.item(0).children.item(0)

      # Change the dimensions and item, remove the class.
      decorationItem2 = document.createElement('div')
      changedCustomDecorations =
        'decoration-id-1':
          top: 10
          height: 20
          item: decorationItem2
      gutterComponent.updateSync(buildTestState(changedCustomDecorations))
      changedDecorationNode = gutterComponent.getDomNode().children.item(0).children.item(0)
      expect(changedDecorationNode).toBe initialDecorationNode
      expect(changedDecorationNode.style.top).toBe '10px'
      expect(changedDecorationNode.style.height).toBe '20px'
      expect(changedDecorationNode.classList.contains('test-class-1')).toBe false
      expect(changedDecorationNode.classList.contains('decoration')).toBe true
      expect(changedDecorationNode.children.length).toBe 1
      decorationItem = changedDecorationNode.children.item(0)
      expect(decorationItem).toBe decorationItem2

      # Remove the item, add a class.
      changedCustomDecorations =
        'decoration-id-1':
          top: 10
          height: 20
          class: 'test-class-2'
      gutterComponent.updateSync(buildTestState(changedCustomDecorations))
      changedDecorationNode = gutterComponent.getDomNode().children.item(0).children.item(0)
      expect(changedDecorationNode).toBe initialDecorationNode
      expect(changedDecorationNode.style.top).toBe '10px'
      expect(changedDecorationNode.style.height).toBe '20px'
      expect(changedDecorationNode.classList.contains('test-class-2')).toBe true
      expect(changedDecorationNode.classList.contains('decoration')).toBe true
      expect(changedDecorationNode.children.length).toBe 0

    it "removes any decorations that existed previously but aren't in the latest update", ->
      customDecorations =
        'decoration-id-1':
          top: 0
          height: 10
          class: 'test-class-1'
      gutterComponent.updateSync(buildTestState(customDecorations))
      decorationsWrapperNode = gutterComponent.getDomNode().children.item(0)
      expect(decorationsWrapperNode.children.length).toBe 1

      emptyCustomDecorations = {}
      gutterComponent.updateSync(buildTestState(emptyCustomDecorations))
      expect(decorationsWrapperNode.children.length).toBe 0
