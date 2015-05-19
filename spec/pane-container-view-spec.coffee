path = require 'path'
temp = require 'temp'
PaneContainer = require '../src/pane-container'
PaneContainerView = require '../src/pane-container-view'
PaneView = require '../src/pane-view'
{Disposable} = require 'event-kit'
{$, View, $$} = require '../src/space-pen-extensions'

describe "PaneContainerView", ->
  [TestView, container, pane1, pane2, pane3, deserializerDisposable] = []

  beforeEach ->
    class TestView extends View
      deserializerDisposable = atom.deserializers.add(this)
      @deserialize: ({name}) -> new TestView(name)
      @content: -> @div tabindex: -1
      initialize: (@name) -> @text(@name)
      serialize: -> {deserializer: 'TestView', @name}
      getURI: -> path.join(temp.dir, @name)
      save: -> @saved = true
      isEqual: (other) -> @name is other?.name
      onDidChangeTitle: -> new Disposable(->)
      onDidChangeModified: -> new Disposable(->)

    container = atom.views.getView(atom.workspace.paneContainer).__spacePenView
    pane1 = container.getRoot()
    pane1.activateItem(new TestView('1'))
    pane2 = pane1.splitRight(new TestView('2'))
    pane3 = pane2.splitDown(new TestView('3'))

  afterEach ->
    deserializerDisposable.dispose()

  describe ".getActivePaneView()", ->
    it "returns the most-recently focused pane", ->
      focusStealer = $$ -> @div tabindex: -1, "focus stealer"
      focusStealer.attachToDom()
      container.attachToDom()

      pane2.focus()
      expect(container.getFocusedPane()).toBe pane2
      expect(container.getActivePaneView()).toBe pane2

      focusStealer.focus()
      expect(container.getFocusedPane()).toBeUndefined()
      expect(container.getActivePaneView()).toBe pane2

      pane3.focus()
      expect(container.getFocusedPane()).toBe pane3
      expect(container.getActivePaneView()).toBe pane3

  describe ".eachPaneView(callback)", ->
    it "runs the callback with all current and future panes until the subscription is cancelled", ->
      panes = []
      subscription = container.eachPaneView (pane) -> panes.push(pane)
      expect(panes).toEqual [pane1, pane2, pane3]

      panes = []
      pane4 = pane3.splitRight(pane3.copyActiveItem())
      expect(panes).toEqual [pane4]

      panes = []
      subscription.off()
      pane4.splitDown()
      expect(panes).toEqual []

  describe ".saveAll()", ->
    it "saves all open pane items", ->
      pane1.activateItem(new TestView('4'))

      container.saveAll()

      for pane in container.getPaneViews()
        for item in pane.getItems()
          expect(item.saved).toBeTruthy()

  describe "serialization", ->
    it "can be serialized and deserialized, and correctly adjusts dimensions of deserialized panes after attach", ->
      newContainer = atom.views.getView(container.model.testSerialization()).__spacePenView
      expect(newContainer.find('atom-pane-axis.horizontal > :contains(1)')).toExist()
      expect(newContainer.find('atom-pane-axis.horizontal > atom-pane-axis.vertical > :contains(2)')).toExist()
      expect(newContainer.find('atom-pane-axis.horizontal > atom-pane-axis.vertical > :contains(3)')).toExist()

      newContainer.height(200).width(300).attachToDom()
      expect(newContainer.find('atom-pane-axis.horizontal > :contains(1)').width()).toBe 150
      expect(newContainer.find('atom-pane-axis.horizontal > atom-pane-axis.vertical > :contains(2)').height()).toBe 100

    describe "if there are empty panes after deserialization", ->
      beforeEach ->
        # only deserialize pane 1's view successfully
        TestView.deserialize = ({name}) -> new TestView(name) if name is '1'

      describe "if the 'core.destroyEmptyPanes' config option is false (the default)", ->
        it "leaves the empty panes intact", ->
          newContainer = atom.views.getView(container.model.testSerialization()).__spacePenView
          expect(newContainer.find('atom-pane-axis.horizontal > :contains(1)')).toExist()
          expect(newContainer.find('atom-pane-axis.horizontal > atom-pane-axis.vertical > atom-pane').length).toBe 2

      describe "if the 'core.destroyEmptyPanes' config option is true", ->
        it "removes empty panes on deserialization", ->
          atom.config.set('core.destroyEmptyPanes', true)
          newContainer = atom.views.getView(container.model.testSerialization()).__spacePenView
          expect(newContainer.find('atom-pane-axis.horizontal, atom-pane-axis.vertical')).not.toExist()
          expect(newContainer.find('> :contains(1)')).toExist()

  describe "pane-container:active-pane-item-changed", ->
    [pane1, item1a, item1b, item2a, item2b, item3a, container, activeItemChangedHandler] = []
    beforeEach ->
      item1a = new TestView('1a')
      item1b = new TestView('1b')
      item2a = new TestView('2a')
      item2b = new TestView('2b')
      item3a = new TestView('3a')

      container = atom.views.getView(new PaneContainer).__spacePenView
      pane1 = container.getRoot()
      pane1.activateItem(item1a)
      container.attachToDom()

      activeItemChangedHandler = jasmine.createSpy("activeItemChangedHandler")
      container.on 'pane-container:active-pane-item-changed', activeItemChangedHandler

    describe "when there is one pane", ->
      it "is triggered when a new pane item is added", ->
        pane1.activateItem(item1b)
        expect(activeItemChangedHandler.callCount).toBe 1
        expect(activeItemChangedHandler.argsForCall[0][1]).toEqual item1b

      it "is not triggered when the active pane item is shown again", ->
        pane1.activateItem(item1a)
        expect(activeItemChangedHandler).not.toHaveBeenCalled()

      it "is triggered when switching to an existing pane item", ->
        pane1.activateItem(item1b)
        activeItemChangedHandler.reset()

        pane1.activateItem(item1a)
        expect(activeItemChangedHandler.callCount).toBe 1
        expect(activeItemChangedHandler.argsForCall[0][1]).toEqual item1a

      it "is triggered when the active pane item is destroyed", ->
        pane1.activateItem(item1b)
        activeItemChangedHandler.reset()

        pane1.destroyItem(item1b)
        expect(activeItemChangedHandler.callCount).toBe 1
        expect(activeItemChangedHandler.argsForCall[0][1]).toEqual item1a

      it "is not triggered when an inactive pane item is destroyed", ->
        pane1.activateItem(item1b)
        activeItemChangedHandler.reset()

        pane1.destroyItem(item1a)
        expect(activeItemChangedHandler).not.toHaveBeenCalled()

      it "is triggered when all pane items are destroyed", ->
        pane1.destroyItem(item1a)
        expect(activeItemChangedHandler.callCount).toBe 1
        expect(activeItemChangedHandler.argsForCall[0][1]).toBe undefined

    describe "when there are two panes", ->
      [pane2] = []

      beforeEach ->
        pane2 = pane1.splitLeft(item2a)
        activeItemChangedHandler.reset()

      it "is triggered when a new pane item is added to the active pane", ->
        pane2.activateItem(item2b)
        expect(activeItemChangedHandler.callCount).toBe 1
        expect(activeItemChangedHandler.argsForCall[0][1]).toEqual item2b

      it "is not triggered when a new pane item is added to an inactive pane", ->
        pane1.activateItem(item1b)
        expect(activeItemChangedHandler).not.toHaveBeenCalled()

      it "is triggered when the active pane's active item is destroyed", ->
        pane2.activateItem(item2b)
        activeItemChangedHandler.reset()

        pane2.destroyItem(item2b)
        expect(activeItemChangedHandler.callCount).toBe 1
        expect(activeItemChangedHandler.argsForCall[0][1]).toEqual item2a

      it "is not triggered when an inactive pane's active item is destroyed", ->
        pane1.activateItem(item1b)
        activeItemChangedHandler.reset()

        pane1.destroyItem(item1b)
        expect(activeItemChangedHandler).not.toHaveBeenCalled()

      it "is triggered when the active pane is destroyed", ->
        pane2.remove()
        expect(activeItemChangedHandler.callCount).toBe 1
        expect(activeItemChangedHandler.argsForCall[0][1]).toEqual item1a

      it "is not triggered when an inactive pane is destroyed", ->
        pane1.remove()
        expect(activeItemChangedHandler).not.toHaveBeenCalled()

      it "is triggered when the active pane is changed", ->
        pane1.activate()
        expect(activeItemChangedHandler.callCount).toBe 1
        expect(activeItemChangedHandler.argsForCall[0][1]).toEqual item1a

    describe "when there are multiple panes", ->
      beforeEach ->
        pane2 = pane1.splitRight(item2a)
        activeItemChangedHandler.reset()

      it "is triggered when a new pane is added", ->
        pane2.splitDown(item3a)
        expect(activeItemChangedHandler.callCount).toBe 1
        expect(activeItemChangedHandler.argsForCall[0][1]).toEqual item3a

      it "is not triggered when an inactive pane is destroyed", ->
        pane3 = pane2.splitDown(item3a)
        activeItemChangedHandler.reset()

        pane1.remove()
        pane2.remove()
        expect(activeItemChangedHandler).not.toHaveBeenCalled()

  describe ".focusNextPaneView()", ->
    it "focuses the pane following the focused pane or the first pane if no pane has focus", ->
      container.attachToDom()
      container.focusNextPaneView()
      expect(pane1.activeItem).toMatchSelector ':focus'
      container.focusNextPaneView()
      expect(pane2.activeItem).toMatchSelector ':focus'
      container.focusNextPaneView()
      expect(pane3.activeItem).toMatchSelector ':focus'
      container.focusNextPaneView()
      expect(pane1.activeItem).toMatchSelector ':focus'

  describe ".focusPreviousPaneView()", ->
    it "focuses the pane preceding the focused pane or the last pane if no pane has focus", ->
      container.attachToDom()
      container.getPaneViews()[0].focus() # activate first pane

      container.focusPreviousPaneView()
      expect(pane3.activeItem).toMatchSelector ':focus'
      container.focusPreviousPaneView()
      expect(pane2.activeItem).toMatchSelector ':focus'
      container.focusPreviousPaneView()
      expect(pane1.activeItem).toMatchSelector ':focus'
      container.focusPreviousPaneView()
      expect(pane3.activeItem).toMatchSelector ':focus'

  describe "changing focus directionally between panes", ->
    [pane1, pane2, pane3, pane4, pane5, pane6, pane7, pane8, pane9] = []

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

      container = atom.views.getView(new PaneContainer).__spacePenView
      pane1 = container.getRoot()
      pane1.activateItem(new TestView('1'))
      pane4 = pane1.splitDown(new TestView('4'))
      pane7 = pane4.splitDown(new TestView('7'))

      pane2 = pane1.splitRight(new TestView('2'))
      pane3 = pane2.splitRight(new TestView('3'))

      pane5 = pane4.splitRight(new TestView('5'))
      pane6 = pane5.splitRight(new TestView('6'))

      pane8 = pane7.splitRight(new TestView('8'))
      pane9 = pane8.splitRight(new TestView('9'))

      container.height(400)
      container.width(400)
      container.attachToDom()

    describe ".focusPaneViewAbove()", ->
      describe "when there are multiple rows above the focused pane", ->
        it "focuses up to the adjacent row", ->
          pane8.focus()
          container.focusPaneViewAbove()
          expect(pane5.activeItem).toMatchSelector ':focus'

      describe "when there are no rows above the focused pane", ->
        it "keeps the current pane focused", ->
          pane2.focus()
          container.focusPaneViewAbove()
          expect(pane2.activeItem).toMatchSelector ':focus'

    describe ".focusPaneViewBelow()", ->
      describe "when there are multiple rows below the focused pane", ->
        it "focuses down to the adjacent row", ->
          pane2.focus()
          container.focusPaneViewBelow()
          expect(pane5.activeItem).toMatchSelector ':focus'

      describe "when there are no rows below the focused pane", ->
        it "keeps the current pane focused", ->
          pane8.focus()
          container.focusPaneViewBelow()
          expect(pane8.activeItem).toMatchSelector ':focus'

    describe ".focusPaneViewOnLeft()", ->
      describe "when there are multiple columns to the left of the focused pane", ->
        it "focuses left to the adjacent column", ->
          pane6.focus()
          container.focusPaneViewOnLeft()
          expect(pane5.activeItem).toMatchSelector ':focus'

      describe "when there are no columns to the left of the focused pane", ->
        it "keeps the current pane focused", ->
          pane4.focus()
          container.focusPaneViewOnLeft()
          expect(pane4.activeItem).toMatchSelector ':focus'

    describe ".focusPaneViewOnRight()", ->
      describe "when there are multiple columns to the right of the focused pane", ->
        it "focuses right to the adjacent column", ->
          pane4.focus()
          container.focusPaneViewOnRight()
          expect(pane5.activeItem).toMatchSelector ':focus'

      describe "when there are no columns to the right of the focused pane", ->
        it "keeps the current pane focused", ->
          pane6.focus()
          container.focusPaneViewOnRight()
          expect(pane6.activeItem).toMatchSelector ':focus'
