PaneContainer = require '../src/pane-container'
PaneAxisElement = require '../src/pane-axis-element'
PaneAxis = require '../src/pane-axis'

describe "PaneContainerElement", ->
  describe "when panes are added or removed", ->
    it "inserts or removes resize elements", ->
      childTagNames = ->
        child.nodeName.toLowerCase() for child in paneAxisElement.children

      paneAxis = new PaneAxis
      paneAxisElement = new PaneAxisElement().initialize(paneAxis, atom)

      expect(childTagNames()).toEqual []

      paneAxis.addChild(new PaneAxis)
      expect(childTagNames()).toEqual [
        'atom-pane-axis'
      ]

      paneAxis.addChild(new PaneAxis)
      expect(childTagNames()).toEqual [
        'atom-pane-axis'
        'atom-pane-resize-handle'
        'atom-pane-axis'
      ]

      paneAxis.addChild(new PaneAxis)
      expect(childTagNames()).toEqual [
        'atom-pane-axis'
        'atom-pane-resize-handle'
        'atom-pane-axis'
        'atom-pane-resize-handle'
        'atom-pane-axis'
      ]

      paneAxis.removeChild(paneAxis.getChildren()[2])
      expect(childTagNames()).toEqual [
        'atom-pane-axis'
        'atom-pane-resize-handle'
        'atom-pane-axis'
      ]

    it "transfers focus to the next pane if a focused pane is removed", ->
      container = new PaneContainer(config: atom.config, confirm: atom.confirm.bind(atom))
      containerElement = atom.views.getView(container)
      leftPane = container.getActivePane()
      leftPaneElement = atom.views.getView(leftPane)
      rightPane = leftPane.splitRight()
      rightPaneElement = atom.views.getView(rightPane)

      jasmine.attachToDOM(containerElement)
      rightPaneElement.focus()
      expect(document.activeElement).toBe rightPaneElement

      rightPane.destroy()
      expect(document.activeElement).toBe leftPaneElement

  describe "when a pane is split", ->
    it "builds appropriately-oriented atom-pane-axis elements", ->
      container = new PaneContainer(config: atom.config, confirm: atom.confirm.bind(atom))
      containerElement = atom.views.getView(container)

      pane1 = container.getActivePane()
      pane2 = pane1.splitRight()
      pane3 = pane2.splitDown()

      horizontalPanes = containerElement.querySelectorAll('atom-pane-container > atom-pane-axis.horizontal > atom-pane')
      expect(horizontalPanes.length).toBe 1
      expect(horizontalPanes[0]).toBe atom.views.getView(pane1)

      verticalPanes = containerElement.querySelectorAll('atom-pane-container > atom-pane-axis.horizontal > atom-pane-axis.vertical > atom-pane')
      expect(verticalPanes.length).toBe 2
      expect(verticalPanes[0]).toBe atom.views.getView(pane2)
      expect(verticalPanes[1]).toBe atom.views.getView(pane3)

      pane1.destroy()
      verticalPanes = containerElement.querySelectorAll('atom-pane-container > atom-pane-axis.vertical > atom-pane')
      expect(verticalPanes.length).toBe 2
      expect(verticalPanes[0]).toBe atom.views.getView(pane2)
      expect(verticalPanes[1]).toBe atom.views.getView(pane3)

  describe "when the resize element is dragged ", ->
    [container, containerElement] = []

    beforeEach ->
      container = new PaneContainer(config: atom.config, confirm: atom.confirm.bind(atom))
      containerElement = atom.views.getView(container)
      document.querySelector('#jasmine-content').appendChild(containerElement)

    dragElementToPosition = (element, clientX) ->
      element.dispatchEvent(new MouseEvent('mousedown',
        view: window
        bubbles: true
        button: 0
      ))

      element.dispatchEvent(new MouseEvent 'mousemove',
        view: window
        bubbles: true
        clientX: clientX
      )

      element.dispatchEvent(new MouseEvent 'mouseup',
        iew: window
        bubbles: true
        button: 0
      )

    getElementWidth = (element) ->
      element.getBoundingClientRect().width

    expectPaneScale = (pairs...) ->
      for [pane, expectedFlexScale] in pairs
        expect(pane.getFlexScale()).toBeCloseTo(expectedFlexScale, 0.1)

    getResizeElement = (i) ->
      containerElement.querySelectorAll('atom-pane-resize-handle')[i]

    getPaneElement = (i) ->
      containerElement.querySelectorAll('atom-pane')[i]

    it "adds and removes panes in the direction that the pane is being dragged", ->
      leftPane = container.getActivePane()
      expectPaneScale [leftPane, 1]

      middlePane = leftPane.splitRight()
      expectPaneScale [leftPane, 1], [middlePane, 1]

      dragElementToPosition(
        getResizeElement(0),
        getElementWidth(getPaneElement(0)) / 2
      )
      expectPaneScale [leftPane, 0.5], [middlePane, 1.5]

      rightPane = middlePane.splitRight()
      expectPaneScale [leftPane, 0.5], [middlePane, 1.5], [rightPane, 1]

      dragElementToPosition(
        getResizeElement(1),
        getElementWidth(getPaneElement(0)) + getElementWidth(getPaneElement(1)) / 2
      )
      expectPaneScale [leftPane, 0.5], [middlePane, 0.75], [rightPane, 1.75]

      middlePane.close()
      expectPaneScale [leftPane, 0.44], [rightPane, 1.55]

      leftPane.close()
      expectPaneScale [rightPane, 1]

    it "splits or closes panes in orthogonal direction that the pane is being dragged", ->
      leftPane = container.getActivePane()
      expectPaneScale [leftPane, 1]

      rightPane = leftPane.splitRight()
      expectPaneScale [leftPane, 1], [rightPane, 1]

      dragElementToPosition(
        getResizeElement(0),
        getElementWidth(getPaneElement(0)) / 2
      )
      expectPaneScale [leftPane, 0.5], [rightPane, 1.5]

      # dynamically split pane, pane's flexScale will become to 1
      lowerPane = leftPane.splitDown()
      expectPaneScale [lowerPane, 1], [leftPane, 1], [leftPane.getParent(), 0.5]

      # dynamically close pane, the pane's flexscale will recorver to origin value
      lowerPane.close()
      expectPaneScale [leftPane, 0.5], [rightPane, 1.5]

    it "unsubscribes from mouse events when the pane is detached", ->
      container.getActivePane().splitRight()
      element = getResizeElement(0)
      spyOn(document, 'addEventListener').andCallThrough()
      spyOn(document, 'removeEventListener').andCallThrough()
      spyOn(element, 'resizeStopped').andCallThrough()

      element.dispatchEvent(new MouseEvent('mousedown',
        view: window
        bubbles: true
        button: 0
      ))

      waitsFor ->
        document.addEventListener.callCount is 2

      runs ->
        expect(element.resizeStopped.callCount).toBe 0
        container.destroy()
        expect(element.resizeStopped.callCount).toBe 1
        expect(document.removeEventListener.callCount).toBe 2

    it "does not throw an error when resized to fit content in a detached state", ->
      container.getActivePane().splitRight()
      element = getResizeElement(0)
      element.remove()
      expect(-> element.resizeToFitContent()).not.toThrow()

  describe "pane resizing", ->
    [leftPane, rightPane] = []

    beforeEach ->
      container = new PaneContainer(config: atom.config, confirm: atom.confirm.bind(atom))
      leftPane = container.getActivePane()
      rightPane = leftPane.splitRight()

    describe "when pane:increase-size is triggered", ->
      it "increases the size of the pane", ->
        expect(leftPane.getFlexScale()).toBe 1
        expect(rightPane.getFlexScale()).toBe 1

        atom.commands.dispatch(atom.views.getView(leftPane), 'pane:increase-size')
        expect(leftPane.getFlexScale()).toBe 1.1
        expect(rightPane.getFlexScale()).toBe 1

        atom.commands.dispatch(atom.views.getView(rightPane), 'pane:increase-size')
        expect(leftPane.getFlexScale()).toBe 1.1
        expect(rightPane.getFlexScale()).toBe 1.1

    describe "when pane:decrease-size is triggered", ->
      it "decreases the size of the pane", ->
        expect(leftPane.getFlexScale()).toBe 1
        expect(rightPane.getFlexScale()).toBe 1

        atom.commands.dispatch(atom.views.getView(leftPane), 'pane:decrease-size')
        expect(leftPane.getFlexScale()).toBe 1/1.1
        expect(rightPane.getFlexScale()).toBe 1

        atom.commands.dispatch(atom.views.getView(rightPane), 'pane:decrease-size')
        expect(leftPane.getFlexScale()).toBe 1/1.1
        expect(rightPane.getFlexScale()).toBe 1/1.1

  describe "changing focus directionally between panes", ->
    [containerElement, pane1, pane2, pane3, pane4, pane5, pane6, pane7, pane8, pane9] = []

    beforeEach ->
      # Set up a grid of 9 panes, in the following arrangement, where the
      # numbers correspond to the variable names below.
      #
      # -------
      # |1|2|3|
      # -------
      # |4|5|6|
      # -------
      # |7|8|9|
      # -------

      buildElement = (id) ->
        element = document.createElement('div')
        element.textContent = id
        element.tabIndex = -1
        element

      container = new PaneContainer(config: atom.config, confirm: atom.confirm.bind(atom))
      pane1 = container.getActivePane()
      pane1.activateItem(buildElement('1'))
      pane4 = pane1.splitDown(items: [buildElement('4')])
      pane7 = pane4.splitDown(items: [buildElement('7')])

      pane2 = pane1.splitRight(items: [buildElement('2')])
      pane3 = pane2.splitRight(items: [buildElement('3')])

      pane5 = pane4.splitRight(items: [buildElement('5')])
      pane6 = pane5.splitRight(items: [buildElement('6')])

      pane8 = pane7.splitRight(items: [buildElement('8')])
      pane9 = pane8.splitRight(items: [buildElement('9')])

      containerElement = atom.views.getView(container)
      containerElement.style.height = '400px'
      containerElement.style.width = '400px'
      jasmine.attachToDOM(containerElement)

    describe "::focusPaneViewAbove()", ->
      describe "when there are multiple rows above the focused pane", ->
        it "focuses up to the adjacent row", ->
          pane8.activate()
          containerElement.focusPaneViewAbove()
          expect(document.activeElement).toBe pane5.getActiveItem()

      describe "when there are no rows above the focused pane", ->
        it "keeps the current pane focused", ->
          pane2.activate()
          containerElement.focusPaneViewAbove()
          expect(document.activeElement).toBe pane2.getActiveItem()

    describe "::focusPaneViewBelow()", ->
      describe "when there are multiple rows below the focused pane", ->
        it "focuses down to the adjacent row", ->
          pane2.activate()
          containerElement.focusPaneViewBelow()
          expect(document.activeElement).toBe pane5.getActiveItem()

      describe "when there are no rows below the focused pane", ->
        it "keeps the current pane focused", ->
          pane8.activate()
          containerElement.focusPaneViewBelow()
          expect(document.activeElement).toBe pane8.getActiveItem()

    describe "::focusPaneViewOnLeft()", ->
      describe "when there are multiple columns to the left of the focused pane", ->
        it "focuses left to the adjacent column", ->
          pane6.activate()
          containerElement.focusPaneViewOnLeft()
          expect(document.activeElement).toBe pane5.getActiveItem()

      describe "when there are no columns to the left of the focused pane", ->
        it "keeps the current pane focused", ->
          pane4.activate()
          containerElement.focusPaneViewOnLeft()
          expect(document.activeElement).toBe pane4.getActiveItem()

    describe "::focusPaneViewOnRight()", ->
      describe "when there are multiple columns to the right of the focused pane", ->
        it "focuses right to the adjacent column", ->
          pane4.activate()
          containerElement.focusPaneViewOnRight()
          expect(document.activeElement).toBe pane5.getActiveItem()

      describe "when there are no columns to the right of the focused pane", ->
        it "keeps the current pane focused", ->
          pane6.activate()
          containerElement.focusPaneViewOnRight()
          expect(document.activeElement).toBe pane6.getActiveItem()
