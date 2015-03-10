PaneAxisElement = require '../src/pane-axis-element'

describe "PaneResizeHandleElement", ->
  describe "add and remove", ->
    class TestItemElement extends HTMLElement
      createdCallback: ->
        @classList.add('test-root')

    TestItemElement = document.registerElement 'atom-test-item-element', prototype: TestItemElement.prototype

    [paneAxis, model, Model] = []
    beforeEach ->
      # This is a dummy item to prevent panes from being empty on deserialization
      class Model
        @newChild: -> document.createElement('atom-test-item-element')
        add: (child, index) -> @addCallback({child, index})
        remove: (child) -> @removeCallback {child}
        replace: (index, oldChild, newChild) ->
          @replaceCallback {index, oldChild, newChild}
        onDidAddChild: (@addCallback) ->
        onDidRemoveChild: (@removeCallback) ->
        onDidReplaceChild: (@replaceCallback) ->
        getOrientation: -> 'horizontal'
        getChildren: -> []

      paneAxis = document.createElement('atom-pane-axis')
      model = new Model
      paneAxis.initialize(model)
      document.querySelector('#jasmine-content').appendChild(paneAxis)

    it "should insert the correct postion in one pane axis", ->
      expect(paneAxis).toBeTruthy()
      modelChildren = (Model.newChild() for i in [1..5])
      model.add(modelChildren[0])
      model.add(modelChildren[1])

      expect(paneAxis.children[0]).toBe(modelChildren[0])
      expect(paneAxis.children[2]).toBe(modelChildren[1])
      expectTestItemElement = (index) ->
        child = paneAxis.children[index]
        expect(child.nodeName.toLowerCase()).toBe('atom-test-item-element')
      expectResizeElement = (index) ->
        expect(paneAxis.isPaneResizeHandleElement(paneAxis.children[index])).toBe(true)
      expectResizeElement(1)

      model.add(modelChildren[2])
      model.add(modelChildren[3])
      expectTestItemElement(i) for i in [0, 2, 4, 6]
      expectResizeElement(i) for i in [1, 3, 5]

      model.remove(modelChildren[2])
      # modelChildren[3] replace modelChildren[2]
      expect(paneAxis.children[4]).toBe(modelChildren[3])
      expectResizeElement(i) for i in [1, 3]

      model.replace(0, modelChildren[0], modelChildren[4])
      expect(paneAxis.children[0]).toBe(modelChildren[4])
      expectResizeElement(i) for i in [1, 3]
