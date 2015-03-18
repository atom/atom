PaneAxisElement = require '../src/pane-axis-element'
PaneAxis = require '../src/pane-axis.coffee'

fdescribe "PaneResizeHandleElement", ->
  describe "add and remove", ->
    [paneAxisElement, paneAxis] = []

    beforeEach ->
      paneAxisElement = document.createElement('atom-pane-axis')
      paneAxis = new PaneAxis({})
      paneAxisElement.initialize(paneAxis)
      document.querySelector('#jasmine-content').appendChild(paneAxisElement)

    it "inserts draggable resize elements between pane axis children", ->
      expect(paneAxisElement).toBeTruthy()
      modelChildren = (new PaneAxis({}) for i in [1..5])
      paneAxis.addChild(modelChildren[0])
      paneAxis.addChild(modelChildren[1])

      expectPaneAxisElement = (index) ->
        child = paneAxisElement.children[index]
        expect(child.nodeName.toLowerCase()).toBe('atom-pane-axis')

      expectResizeElement = (index) ->
        child = paneAxisElement.children[index]
        expect(paneAxisElement.isPaneResizeHandleElement(child)).toBe(true)

      expect(paneAxisElement.children[0].model).toBe(modelChildren[0])
      expectResizeElement(1)
      expect(paneAxisElement.children[2].model).toBe(modelChildren[1])

      paneAxis.addChild(modelChildren[2])
      paneAxis.addChild(modelChildren[3])
      expectPaneAxisElement(i) for i in [0, 2, 4, 6]
      expectResizeElement(i) for i in [1, 3, 5]

      # test removeChild
      paneAxis.removeChild(modelChildren[2])
      # modelChildren[3] replace modelChildren[2]
      expect(paneAxisElement.children[4].model).toBe(modelChildren[3])
      expectResizeElement(i) for i in [1, 3]

      # test replaceChild
      paneAxis.replaceChild(modelChildren[0], modelChildren[4])
      expect(paneAxisElement.children[0].model).toBe(modelChildren[4])
      expectResizeElement(i) for i in [1, 3]
