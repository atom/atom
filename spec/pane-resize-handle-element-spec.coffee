PaneContainer = require '../src/pane-container'

describe "PaneResizeHandleElement", ->
  describe "resize", ->
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

      leftWidth = resizeElement.previousSibling.getBoundingClientRect().width
      resizeElementMove(resizeElement, leftWidth/2, 0)
      expect(activePane.getFlexScale()).toBeCloseTo(0.5, 0.1)
      expect(rightPane.getFlexScale()).toBeCloseTo(1.5, 0.1)

      downPane = activePane.splitDown()
      # after split down, the horizontal panes retain
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
      upPane = container.getActivePane()
      downPane = upPane.splitDown()

      [upRightPane, upLeftPane] = [upPane.splitRight(), upPane]
      upPane = upLeftPane.getParent()

      [downRightPane, downLeftPane] = [downPane.splitRight(), downPane]
      downPane = downLeftPane.getParent()

      horizontalResizeElements = containerElement.querySelectorAll('atom-pane-resize-handle.horizontal')
      expect(horizontalResizeElements.length).toBe(2)

      expectCloseTo = (element, scale) ->
        expect(element.getFlexScale()).toBeCloseTo(scale, 0.1)

      expectPaneScale = (up, down, upLeft, upRight, downLeft, downRight) ->
        paneScales = [
          [upPane, up], [downPane, down], [upLeftPane, upLeft],
          [upRightPane, upRight], [downLeftPane, downLeft], [downRightPane, downRight]
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

    it "change the flex scale when dynamically split or close panes in orthogonal direction", ->
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


