PaneContainer = require '../src/pane-container'
PaneAxisElement = require '../src/pane-axis-element'
PaneAxis = require '../src/pane-axis'

params =
  location: 'center'
  config: atom.config
  confirm: atom.confirm.bind(atom)
  viewRegistry: atom.views
  applicationDelegate: atom.applicationDelegate

describe "PaneContainerElement", ->
  describe "when panes are added or removed", ->
    it "inserts or removes resize elements", ->
      childTagNames = ->
        child.nodeName.toLowerCase() for child in paneAxisElement.children

      paneAxis = new PaneAxis({}, atom.views)
      paneAxisElement = paneAxis.getElement()

      expect(childTagNames()).toEqual []

      paneAxis.addChild(new PaneAxis({}, atom.views))
      expect(childTagNames()).toEqual [
        'atom-pane-axis'
      ]

      paneAxis.addChild(new PaneAxis({}, atom.views))
      expect(childTagNames()).toEqual [
        'atom-pane-axis'
        'atom-pane-resize-handle'
        'atom-pane-axis'
      ]

      paneAxis.addChild(new PaneAxis({}, atom.views))
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
      container = new PaneContainer(params)
      containerElement = container.getElement()
      leftPane = container.getActivePane()
      leftPaneElement = leftPane.getElement()
      rightPane = leftPane.splitRight()
      rightPaneElement = rightPane.getElement()

      jasmine.attachToDOM(containerElement)
      rightPaneElement.focus()
      expect(document.activeElement).toBe rightPaneElement

      rightPane.destroy()
      expect(document.activeElement).toBe leftPaneElement

  describe "when a pane is split", ->
    it "builds appropriately-oriented atom-pane-axis elements", ->
      container = new PaneContainer(params)
      containerElement = container.getElement()

      pane1 = container.getActivePane()
      pane2 = pane1.splitRight()
      pane3 = pane2.splitDown()

      horizontalPanes = containerElement.querySelectorAll('atom-pane-container > atom-pane-axis.horizontal > atom-pane')
      expect(horizontalPanes.length).toBe 1
      expect(horizontalPanes[0]).toBe pane1.getElement()

      verticalPanes = containerElement.querySelectorAll('atom-pane-container > atom-pane-axis.horizontal > atom-pane-axis.vertical > atom-pane')
      expect(verticalPanes.length).toBe 2
      expect(verticalPanes[0]).toBe pane2.getElement()
      expect(verticalPanes[1]).toBe pane3.getElement()

      pane1.destroy()
      verticalPanes = containerElement.querySelectorAll('atom-pane-container > atom-pane-axis.vertical > atom-pane')
      expect(verticalPanes.length).toBe 2
      expect(verticalPanes[0]).toBe pane2.getElement()
      expect(verticalPanes[1]).toBe pane3.getElement()

  describe "when the resize element is dragged ", ->
    [container, containerElement] = []

    beforeEach ->
      container = new PaneContainer(params)
      containerElement = container.getElement()
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

      waitsForPromise -> middlePane.close()
      runs -> expectPaneScale [leftPane, 0.44], [rightPane, 1.55]

      waitsForPromise -> leftPane.close()
      runs -> expectPaneScale [rightPane, 1]

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
      waitsForPromise -> lowerPane.close()
      runs -> expectPaneScale [leftPane, 0.5], [rightPane, 1.5]

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
      container = new PaneContainer(params)
      leftPane = container.getActivePane()
      rightPane = leftPane.splitRight()

    describe "when pane:increase-size is triggered", ->
      it "increases the size of the pane", ->
        expect(leftPane.getFlexScale()).toBe 1
        expect(rightPane.getFlexScale()).toBe 1

        atom.commands.dispatch(leftPane.getElement(), 'pane:increase-size')
        expect(leftPane.getFlexScale()).toBe 1.1
        expect(rightPane.getFlexScale()).toBe 1

        atom.commands.dispatch(rightPane.getElement(), 'pane:increase-size')
        expect(leftPane.getFlexScale()).toBe 1.1
        expect(rightPane.getFlexScale()).toBe 1.1

    describe "when pane:decrease-size is triggered", ->
      it "decreases the size of the pane", ->
        expect(leftPane.getFlexScale()).toBe 1
        expect(rightPane.getFlexScale()).toBe 1

        atom.commands.dispatch(leftPane.getElement(), 'pane:decrease-size')
        expect(leftPane.getFlexScale()).toBe 1/1.1
        expect(rightPane.getFlexScale()).toBe 1

        atom.commands.dispatch(rightPane.getElement(), 'pane:decrease-size')
        expect(leftPane.getFlexScale()).toBe 1/1.1
        expect(rightPane.getFlexScale()).toBe 1/1.1

  describe "changing focus, copying and moving items directionally between panes", ->
    [item1, item2, item3, item4, item5, item6, item7, item8, item9,
     pane1, pane2, pane3, pane4, pane5, pane6, pane7, pane8, pane9,
     container, containerElement] = []

    beforeEach ->
      atom.config.set("core.destroyEmptyPanes", false)

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
        element.copy = ->
          element.cloneNode(true)
        element

      container = new PaneContainer(params)

      [item1, item2, item3, item4, item5, item6, item7, item8, item9] =
        [buildElement('1'), buildElement('2'), buildElement('3'),
         buildElement('4'), buildElement('5'), buildElement('6'),
         buildElement('7'), buildElement('8'), buildElement('9')]

      pane1 = container.getActivePane()
      pane1.activateItem(item1)
      pane4 = pane1.splitDown(items: [item4])
      pane7 = pane4.splitDown(items: [item7])

      pane2 = pane1.splitRight(items: [item2])
      pane3 = pane2.splitRight(items: [item3])

      pane5 = pane4.splitRight(items: [item5])
      pane6 = pane5.splitRight(items: [item6])

      pane8 = pane7.splitRight(items: [item8])
      pane9 = pane8.splitRight(items: [item9])

      containerElement = container.getElement()
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

    describe "::moveActiveItemToPaneAbove(keepOriginal)", ->
      describe "when there are multiple rows above the focused pane", ->
        it "moves the active item up to the adjacent row", ->
          pane8.activate()
          containerElement.moveActiveItemToPaneAbove()
          expect(container.paneForItem(item8)).toBe pane5
          expect(pane5.getActiveItem()).toBe item8

      describe "when there are no rows above the focused pane", ->
        it "keeps the active item in the focused pane", ->
          pane2.activate()
          containerElement.moveActiveItemToPaneAbove()
          expect(container.paneForItem(item2)).toBe pane2

      describe "when `keepOriginal: true` is passed in the params", ->
        it "keeps the item and adds a copy of it to the adjacent pane", ->
          pane8.activate()
          containerElement.moveActiveItemToPaneAbove(keepOriginal: true)
          expect(container.paneForItem(item8)).toBe pane8
          expect(pane5.getActiveItem().textContent).toBe '8'

    describe "::moveActiveItemToPaneBelow(keepOriginal)", ->
      describe "when there are multiple rows below the focused pane", ->
        it "moves the active item down to the adjacent row", ->
          pane2.activate()
          containerElement.moveActiveItemToPaneBelow()
          expect(container.paneForItem(item2)).toBe pane5
          expect(pane5.getActiveItem()).toBe item2

      describe "when there are no rows below the focused pane", ->
        it "keeps the active item in the focused pane", ->
          pane8.activate()
          containerElement.moveActiveItemToPaneBelow()
          expect(container.paneForItem(item8)).toBe pane8

      describe "when `keepOriginal: true` is passed in the params", ->
        it "keeps the item and adds a copy of it to the adjacent pane", ->
          pane2.activate()
          containerElement.moveActiveItemToPaneBelow(keepOriginal: true)
          expect(container.paneForItem(item2)).toBe pane2
          expect(pane5.getActiveItem().textContent).toBe '2'

    describe "::moveActiveItemToPaneOnLeft(keepOriginal)", ->
      describe "when there are multiple columns to the left of the focused pane", ->
        it "moves the active item left to the adjacent column", ->
          pane6.activate()
          containerElement.moveActiveItemToPaneOnLeft()
          expect(container.paneForItem(item6)).toBe pane5
          expect(pane5.getActiveItem()).toBe item6

      describe "when there are no columns to the left of the focused pane", ->
        it "keeps the active item in the focused pane", ->
          pane4.activate()
          containerElement.moveActiveItemToPaneOnLeft()
          expect(container.paneForItem(item4)).toBe pane4

      describe "when `keepOriginal: true` is passed in the params", ->
        it "keeps the item and adds a copy of it to the adjacent pane", ->
          pane6.activate()
          containerElement.moveActiveItemToPaneOnLeft(keepOriginal: true)
          expect(container.paneForItem(item6)).toBe pane6
          expect(pane5.getActiveItem().textContent).toBe '6'

    describe "::moveActiveItemToPaneOnRight(keepOriginal)", ->
      describe "when there are multiple columns to the right of the focused pane", ->
        it "moves the active item right to the adjacent column", ->
          pane4.activate()
          containerElement.moveActiveItemToPaneOnRight()
          expect(container.paneForItem(item4)).toBe pane5
          expect(pane5.getActiveItem()).toBe item4

      describe "when there are no columns to the right of the focused pane", ->
        it "keeps the active item in the focused pane", ->
          pane6.activate()
          containerElement.moveActiveItemToPaneOnRight()
          expect(container.paneForItem(item6)).toBe pane6

      describe "when `keepOriginal: true` is passed in the params", ->
        it "keeps the item and adds a copy of it to the adjacent pane", ->
          pane4.activate()
          containerElement.moveActiveItemToPaneOnRight(keepOriginal: true)
          expect(container.paneForItem(item4)).toBe pane4
          expect(pane5.getActiveItem().textContent).toBe '4'
