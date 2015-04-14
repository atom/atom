PaneContainer = require '../src/pane-container'
PaneAxisElement = require '../src/pane-axis-element'
PaneAxis = require '../src/pane-axis'

fdescribe "PaneResizeHandleElement", ->
  describe "as children of PaneAxisElement", ->
    [paneAxisElement, paneAxis] = []

    beforeEach ->
      paneAxisElement = document.createElement('atom-pane-axis')
      paneAxis = new PaneAxis({})
      paneAxisElement.initialize(paneAxis)
      document.querySelector('#jasmine-content').appendChild(paneAxisElement)

    it "inserts or remove resize elements when pane axis added or removed", ->
      modelChildren = (new PaneAxis({}) for i in [1..5])
      paneAxis.addChild(modelChildren[0])
      paneAxis.addChild(modelChildren[1])

      expectPaneAxisElement = (index) ->
        child = paneAxisElement.children[index]
        expect(child.nodeName.toLowerCase()).toBe('atom-pane-axis')

      expectResizeElement = (index) ->
        child = paneAxisElement.children[index]
        expect(paneAxisElement.isPaneResizeHandleElement(child)).toBe(true)
      expectResizeElement(1)

      paneAxis.addChild(modelChildren[2])
      paneAxis.addChild(modelChildren[3])
      expectPaneAxisElement(i) for i in [0, 2, 4, 6]
      expectResizeElement(i) for i in [1, 3, 5]

      # test removeChild
      paneAxis.removeChild(modelChildren[2])
      expectResizeElement(i) for i in [1, 3]

      # test replaceChild
      paneAxis.replaceChild(modelChildren[0], modelChildren[4])
      expectResizeElement(i) for i in [1, 3]

  describe "when mouse drag the resize element", ->
    [container, containerElement, resizeElementMove, getElementWidth] = []

    beforeEach ->
      container = new PaneContainer
      containerElement = atom.views.getView(container);
      document.querySelector('#jasmine-content').appendChild(containerElement)

      resizeElementMove = (resizeElement, clientX, clientY) ->
        mouseDownEvent = new MouseEvent 'mousedown',
          { view: window, bubbles: true, button: 0 }
        resizeElement.dispatchEvent(mouseDownEvent)

        mouseMoveEvent = new MouseEvent 'mousemove',
          { view: window, bubbles: true, clientX: clientX, clientY: clientY}
        resizeElement.dispatchEvent(mouseMoveEvent)

        mouseUpEvent = new MouseEvent 'mouseup',
          {view: window, bubbles: true, button: 0}
        resizeElement.dispatchEvent(mouseUpEvent)

      getElementWidth = (element) ->
        element.getBoundingClientRect().width

    it "drag the pane resize handle element, then the panes around it will resize", ->
      activePane = container.getActivePane()
      rightPane = activePane.splitRight()

      resizeElement = containerElement.querySelector('atom-pane-resize-handle')
      expect(resizeElement).toBeTruthy()

      leftWidth = getElementWidth(resizeElement.previousSibling)
      resizeElementMove(resizeElement, leftWidth/2, 0)
      expect(activePane.getFlexScale()).toBeCloseTo(0.5, 0.1)
      expect(rightPane.getFlexScale()).toBeCloseTo(1.5, 0.1)

    it "drag the resize element, the size of other panes in the same direction will not change", ->
      leftPane = container.getActivePane()
      middlePane = leftPane.splitRight()
      rightPane = middlePane.splitRight()

      resizeElements = containerElement.querySelectorAll('atom-pane-resize-handle')
      paneElements = containerElement.querySelectorAll('atom-pane')
      expect(resizeElements.length).toBe(2)

      expectPaneScale = (leftScale, middleScale, rightScale) ->
        expect(leftPane.getFlexScale()).toBeCloseTo(leftScale, 0.1)
        expect(middlePane.getFlexScale()).toBeCloseTo(middleScale, 0.1)
        expect(rightPane.getFlexScale()).toBeCloseTo(rightScale, 0.1)

      resizeElementMove(resizeElements[0], getElementWidth(paneElements[0]) / 2)
      expectPaneScale(0.5, 1.5, 1)

      clientX = getElementWidth(paneElements[0]) + getElementWidth(paneElements[1]) / 2
      resizeElementMove(resizeElements[1], clientX)
      expectPaneScale(0.5, 0.75, 1.75)

    it "drag the horizontal element, the size of other vertical pane will not change", ->
      upperPane = container.getActivePane()
      downPane = upperPane.splitDown()

      [upperRightPane, upperLeftPane] = [upperPane.splitRight(), upperPane]
      upperPane = upperLeftPane.getParent()

      [downRightPane, downLeftPane] = [downPane.splitRight(), downPane]
      downPane = downLeftPane.getParent()

      horizontalResizeElements = containerElement.querySelectorAll('atom-pane-resize-handle.horizontal')
      expect(horizontalResizeElements.length).toBe(2)

      expectCloseTo = (element, scale) ->
        expect(element.getFlexScale()).toBeCloseTo(scale, 0.1)

      expectPaneScale = (upper, down, upperLeft, upperRight, downLeft, downRight) ->
        paneScales = [
          [upperPane, upper], [downPane, down], [upperLeftPane, upperLeft],
          [upperRightPane, upperRight], [downLeftPane, downLeft],
          [downRightPane, downRight]
        ]
        expectCloseTo(e[0], e[1]) for e in paneScales

      newWidth = getElementWidth(horizontalResizeElements[0].previousSibling) / 2
      resizeElementMove(horizontalResizeElements[0], newWidth)
      expectPaneScale(1, 1, 0.5, 1.5, 1, 1)

      newWidth = getElementWidth(horizontalResizeElements[1].previousSibling) / 2
      resizeElementMove(horizontalResizeElements[1], newWidth)
      expectPaneScale(1, 1, 0.5, 1.5, 0.5, 1.5)

    it "transform the flex scale when dynamically split or close panes in the same direction", ->
      leftPane = container.getActivePane()
      middlePane = leftPane.splitRight()
      rightPane = middlePane.splitRight()

      expectPaneScale = (leftScale, middleScale, rightScale) ->
        paneScales = [[leftPane, leftScale], [middlePane, middleScale], [rightPane, rightScale]];
        expect(e[0].getFlexScale()).toBeCloseTo(e[1], 0.1) for e in paneScales

      resizeElement = containerElement.querySelector('atom-pane-resize-handle')
      resizeElementMove(resizeElement, getElementWidth(atom.views.getView(leftPane)) / 2)
      expectPaneScale(0.5, 1.5, 1)

      leftPane.close()
      expect(middlePane.getFlexScale()).toBeCloseTo(1.2, 0.1)
      expect(rightPane.getFlexScale()).toBeCloseTo(0.8, 0.1)

      rightPane.close() # when close the same direction pane, the flexScale will recorver
      expect(middlePane.getFlexScale()).toBeCloseTo(1, 0.1)

    it "retain the flex scale when dynamically split or close panes in orthogonal direction", ->
      leftPane = container.getActivePane()
      rightPane = leftPane.splitRight()

      resizeElement = containerElement.querySelector('atom-pane-resize-handle')
      resizeElementMove(resizeElement, getElementWidth(resizeElement.previousSibling) / 2)
      expect(leftPane.getFlexScale()).toBeCloseTo(0.5, 0.1)

      downPane = leftPane.splitDown()   # dynamically split pane, pane's flexScale will become to 1
      expect(leftPane.getFlexScale()).toBeCloseTo(1, 0.1)
      expect(leftPane.getParent().getFlexScale()).toBeCloseTo(0.5, 0.1)

      downPane.close() # dynamically close pane, the pane's flexscale will recorver to origin value
      expect(leftPane.getFlexScale()).toBeCloseTo(0.5, 0.1)


