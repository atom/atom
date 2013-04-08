$ = require 'jquery'
_ = require 'underscore'
RootView = require 'root-view'
Pane = require 'pane'
PaneContainer = require 'pane-container'
TabBarView = require 'tabs/lib/tab-bar-view'
{View} = require 'space-pen'

describe "Tabs package main", ->
  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    atom.activatePackage("tabs")

  describe ".activate()", ->
    it "appends a tab bar all existing and new panes", ->
      expect(rootView.panes.find('.pane').length).toBe 1
      expect(rootView.panes.find('.pane > .tabs').length).toBe 1
      rootView.getActivePane().splitRight()
      expect(rootView.find('.pane').length).toBe 2
      expect(rootView.panes.find('.pane > .tabs').length).toBe 2

describe "TabBarView", ->
  [item1, item2, editSession1, pane, tabBar] = []

  class TestView extends View
    @deserialize: ({title, longTitle}) -> new TestView(title, longTitle)
    @content: (title) -> @div title
    initialize: (@title, @longTitle) ->
    getTitle: -> @title
    getLongTitle: -> @longTitle
    serialize: -> { deserializer: 'TestView', @title, @longTitle }

  beforeEach ->
    registerDeserializer(TestView)
    item1 = new TestView('Item 1')
    item2 = new TestView('Item 2')
    editSession1 = project.buildEditSession('sample.js')
    paneContainer = new PaneContainer
    pane = new Pane(item1, editSession1, item2)
    pane.showItem(item2)
    paneContainer.append(pane)
    tabBar = new TabBarView(pane)

  afterEach ->
    unregisterDeserializer(TestView)

  describe ".initialize(pane)", ->
    it "creates a tab for each item on the tab bar's parent pane", ->
      expect(pane.getItems().length).toBe 3
      expect(tabBar.find('.tab').length).toBe 3

      expect(tabBar.find('.tab:eq(0) .title').text()).toBe item1.getTitle()
      expect(tabBar.find('.tab:eq(1) .title').text()).toBe editSession1.getTitle()
      expect(tabBar.find('.tab:eq(2) .title').text()).toBe item2.getTitle()

    it "highlights the tab for the active pane item", ->
      expect(tabBar.find('.tab:eq(2)')).toHaveClass 'active'

  describe "when the active pane item changes", ->
    it "highlights the tab for the new active pane item", ->
      pane.showItem(item1)
      expect(tabBar.find('.active').length).toBe 1
      expect(tabBar.find('.tab:eq(0)')).toHaveClass 'active'

      pane.showItem(item2)
      expect(tabBar.find('.active').length).toBe 1
      expect(tabBar.find('.tab:eq(2)')).toHaveClass 'active'

  describe "when a new item is added to the pane", ->
    it "adds a tab for the new item at the same index as the item in the pane", ->
      pane.showItem(item1)
      item3 = new TestView('Item 3')
      pane.showItem(item3)
      expect(tabBar.find('.tab').length).toBe 4
      expect(tabBar.tabAtIndex(1).find('.title')).toHaveText 'Item 3'

    it "adds the 'modified' class to the new tab if the item is initially modified", ->
      editSession2 = project.buildEditSession('sample.txt')
      editSession2.insertText('x')
      pane.showItem(editSession2)
      expect(tabBar.tabForItem(editSession2)).toHaveClass 'modified'

  describe "when an item is removed from the pane", ->
    it "removes the item's tab from the tab bar", ->
      pane.removeItem(item2)
      expect(tabBar.getTabs().length).toBe 2
      expect(tabBar.find('.tab:contains(Item 2)')).not.toExist()

    it "updates the titles of the remaining tabs", ->
      expect(tabBar.tabForItem(item2)).toHaveText 'Item 2'
      item2.longTitle = '2'
      item2a = new TestView('Item 2')
      item2a.longTitle = '2a'
      pane.showItem(item2a)
      expect(tabBar.tabForItem(item2)).toHaveText '2'
      expect(tabBar.tabForItem(item2a)).toHaveText '2a'
      pane.removeItem(item2a)
      expect(tabBar.tabForItem(item2)).toHaveText 'Item 2'

  describe "when a tab is clicked", ->
    it "shows the associated item on the pane and focuses the pane", ->
      spyOn(pane, 'focus')

      tabBar.tabAtIndex(0).click()
      expect(pane.activeItem).toBe pane.getItems()[0]

      tabBar.tabAtIndex(2).click()
      expect(pane.activeItem).toBe pane.getItems()[2]

      expect(pane.focus.callCount).toBe 2

  describe "when a tab's close icon is clicked", ->
    it "destroys the tab's item on the pane", ->
      tabBar.tabForItem(editSession1).find('.close-icon').click()
      expect(pane.getItems().length).toBe 2
      expect(pane.getItems().indexOf(editSession1)).toBe -1
      expect(editSession1.destroyed).toBeTruthy()
      expect(tabBar.getTabs().length).toBe 2
      expect(tabBar.find('.tab:contains(sample.js)')).not.toExist()

  describe "when a tab item's title changes", ->
    it "updates the title of the item's tab", ->
      editSession1.buffer.setPath('/this/is-a/test.txt')
      expect(tabBar.tabForItem(editSession1)).toHaveText 'test.txt'

  describe "when two tabs have the same title", ->
    it "displays the long title on the tab if it's available from the item", ->
      item1.title = "Old Man"
      item1.longTitle = "Grumpy Old Man"
      item1.trigger 'title-changed'
      item2.title = "Old Man"
      item2.longTitle = "Jolly Old Man"
      item2.trigger 'title-changed'

      expect(tabBar.tabForItem(item1)).toHaveText "Grumpy Old Man"
      expect(tabBar.tabForItem(item2)).toHaveText "Jolly Old Man"

      item2.longTitle = undefined
      item2.trigger 'title-changed'

      expect(tabBar.tabForItem(item1)).toHaveText "Grumpy Old Man"
      expect(tabBar.tabForItem(item2)).toHaveText "Old Man"

  describe "when a tab item's modified status changes", ->
    it "adds or removes the 'modified' class to the tab based on the status", ->
      tab = tabBar.tabForItem(editSession1)
      expect(editSession1.isModified()).toBeFalsy()
      expect(tab).not.toHaveClass 'modified'

      editSession1.insertText('x')
      advanceClock(editSession1.buffer.stoppedChangingDelay)
      expect(editSession1.isModified()).toBeTruthy()
      expect(tab).toHaveClass 'modified'

      editSession1.undo()
      advanceClock(editSession1.buffer.stoppedChangingDelay)
      expect(editSession1.isModified()).toBeFalsy()
      expect(tab).not.toHaveClass 'modified'

  describe "when a pane item moves to a new index", ->
    it "updates the order of the tabs to match the new item order", ->
      expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
      pane.moveItem(item2, 1)
      expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "Item 2", "sample.js"]
      pane.moveItem(editSession1, 0)
      expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["sample.js", "Item 1", "Item 2"]
      pane.moveItem(item1, 2)
      expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["sample.js", "Item 2", "Item 1"]

  describe "dragging and dropping tabs", ->
    buildDragEvents = (dragged, dropTarget) ->
      dataTransfer =
        data: {}
        setData: (key, value) -> @data[key] = value
        getData: (key) -> @data[key]

      dragStartEvent = $.Event()
      dragStartEvent.target = dragged[0]
      dragStartEvent.originalEvent = { dataTransfer }

      dropEvent = $.Event()
      dropEvent.target = dropTarget[0]
      dropEvent.originalEvent = { dataTransfer }

      [dragStartEvent, dropEvent]

    describe "when a tab is dragged within the same pane", ->
      describe "when it is dropped on tab that's later in the list", ->
        it "moves the tab and its item, shows the tab's item, and focuses the pane", ->
          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editSession1, item2]
          expect(pane.activeItem).toBe item2
          spyOn(pane, 'focus')

          [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(0), tabBar.tabAtIndex(1))
          tabBar.onDragStart(dragStartEvent)
          tabBar.onDrop(dropEvent)

          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["sample.js", "Item 1", "Item 2"]
          expect(pane.getItems()).toEqual [editSession1, item1, item2]
          expect(pane.activeItem).toBe item1
          expect(pane.focus).toHaveBeenCalled()

      describe "when it is dropped on a tab that's earlier in the list", ->
        it "moves the tab and its item, shows the tab's item, and focuses the pane", ->
          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editSession1, item2]
          expect(pane.activeItem).toBe item2
          spyOn(pane, 'focus')

          [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(2), tabBar.tabAtIndex(0))
          tabBar.onDragStart(dragStartEvent)
          tabBar.onDrop(dropEvent)

          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "Item 2", "sample.js"]
          expect(pane.getItems()).toEqual [item1, item2, editSession1]
          expect(pane.activeItem).toBe item2
          expect(pane.focus).toHaveBeenCalled()

      describe "when it is dropped on itself", ->
        it "doesn't move the tab or item, but does make it the active item and focuses the pane", ->
          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editSession1, item2]
          expect(pane.activeItem).toBe item2
          spyOn(pane, 'focus')

          [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(0), tabBar.tabAtIndex(0))
          tabBar.onDragStart(dragStartEvent)
          tabBar.onDrop(dropEvent)

          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editSession1, item2]
          expect(pane.activeItem).toBe item1
          expect(pane.focus).toHaveBeenCalled()

      describe "when it is dropped on the tab bar", ->
        it "moves the tab and its item to the end", ->
          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editSession1, item2]
          expect(pane.activeItem).toBe item2
          spyOn(pane, 'focus')

          [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(0), tabBar)
          tabBar.onDragStart(dragStartEvent)
          tabBar.onDrop(dropEvent)

          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["sample.js", "Item 2", "Item 1"]
          expect(pane.getItems()).toEqual [editSession1, item2, item1]

    describe "when a tab is dragged to a different pane", ->
      [pane2, tabBar2, item2b] = []

      beforeEach ->
        pane2 = pane.splitRight()
        [item2b] = pane2.getItems()
        tabBar2 = new TabBarView(pane2)

      it "removes the tab and item from their original pane and moves them to the target pane", ->
        expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
        expect(pane.getItems()).toEqual [item1, editSession1, item2]
        expect(pane.activeItem).toBe item2

        expect(tabBar2.getTabs().map (tab) -> tab.text()).toEqual ["Item 2"]
        expect(pane2.getItems()).toEqual [item2b]
        expect(pane2.activeItem).toBe item2b
        spyOn(pane2, 'focus')

        [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(0), tabBar2.tabAtIndex(0))
        tabBar.onDragStart(dragStartEvent)
        tabBar.onDrop(dropEvent)

        expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["sample.js", "Item 2"]
        expect(pane.getItems()).toEqual [editSession1, item2]
        expect(pane.activeItem).toBe item2

        expect(tabBar2.getTabs().map (tab) -> tab.text()).toEqual ["Item 2", "Item 1"]
        expect(pane2.getItems()).toEqual [item2b, item1]
        expect(pane2.activeItem).toBe item1
        expect(pane2.focus).toHaveBeenCalled()

    describe 'when a non-tab is dragged to pane', ->
      it 'has no effect', ->
        expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
        expect(pane.getItems()).toEqual [item1, editSession1, item2]
        expect(pane.activeItem).toBe item2
        spyOn(pane, 'focus')

        [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(0), tabBar.tabAtIndex(0))
        tabBar.onDrop(dropEvent)

        expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
        expect(pane.getItems()).toEqual [item1, editSession1, item2]
        expect(pane.activeItem).toBe item2
        expect(pane.focus).not.toHaveBeenCalled()

