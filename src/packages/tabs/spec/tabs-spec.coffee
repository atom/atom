$ = require 'jquery'
_ = require 'underscore'
RootView = require 'root-view'
Pane = require 'pane'
PaneContainer = require 'pane-container'
TabBarView = require 'tabs/lib/tab-bar-view'
fs = require 'fs'
{View} = require 'space-pen'

describe "Tabs package main", ->
  beforeEach ->
    window.rootView = new RootView
    rootView.open('sample.js')
    window.loadPackage("tabs")

  describe ".activate()", ->
    it "appends a tab bar all existing and new panes", ->
      expect(rootView.panes.find('.pane').length).toBe 1
      expect(rootView.panes.find('.pane > .tabs').length).toBe 1
      rootView.getActivePane().splitRight()
      expect(rootView.find('.pane').length).toBe 2
      expect(rootView.panes.find('.pane > .tabs').length).toBe 2

fdescribe "TabBarView", ->
  [item1, item2, editSession1, pane, tabBar] = []

  class TestView extends View
    @content: (title) -> @div title
    initialize: (@title) ->
    getTitle: -> @title
    getLongTitle: -> @longTitle

  beforeEach ->
    item1 = new TestView('Item 1')
    item2 = new TestView('Item 2')
    editSession1 = project.buildEditSession('sample.js')
    paneContainer = new PaneContainer
    pane = new Pane(item1, editSession1, item2)
    pane.showItem(item2)
    paneContainer.append(pane)
    tabBar = new TabBarView(pane)

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

  describe "when an item is removed from the pane", ->
    it "removes the item's tab from the tab bar", ->
      pane.removeItem(item2)
      expect(tabBar.getTabs().length).toBe 2
      expect(tabBar.find('.tab:contains(Item 2)')).not.toExist()

  describe "when a tab is clicked", ->
    it "shows the associated item on the pane and focuses the pane", ->
      spyOn(pane, 'focus')

      tabBar.tabAtIndex(0).click()
      expect(pane.activeItem).toBe pane.getItems()[0]

      tabBar.tabAtIndex(2).click()
      expect(pane.activeItem).toBe pane.getItems()[2]

      expect(pane.focus.callCount).toBe 2

  describe "when a tab's close icon is clicked", ->
    it "removes the tab's item from the pane", ->
      tabBar.tabForItem(item1).find('.close-icon').click()
      expect(pane.getItems().length).toBe 2
      expect(pane.getItems().indexOf(item1)).toBe -1
      expect(tabBar.getTabs().length).toBe 2
      expect(tabBar.find('.tab:contains(Item 1)')).not.toExist()

  describe "when a tab item's title changes", ->
    it "updates the title of the item's tab", ->
      editSession1.buffer.setPath('/this/is-a/test.txt')
      expect(tabBar.tabForItem(editSession1)).toHaveText 'test.txt'

  describe "when two tabs have the same file name", ->
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
    describe "when the tab is dropped onto itself", ->
      it "doesn't move the edit session and focuses the editor", ->
        expect(tabs.find('.tab:eq(1) .file-name').text()).toBe "sample.txt"

        sortableElement = [tabs.find('.tab:eq(0)')]
        spyOn(tabs, 'getSortableElement').andCallFake -> sortableElement[0]
        event = $.Event()
        event.target = tabs[0]
        event.originalEvent =
          dataTransfer:
            data: {}
            setData: (key, value) -> @data[key] = value
            getData: (key) -> @data[key]

        editor.hiddenInput.focusout()
        tabs.onDragStart(event)
        tabs.onDrop(event)

        expect(tabs.find('.tab:eq(0) .file-name').text()).toBe "sample.js"
        expect(tabs.find('.tab:eq(1) .file-name').text()).toBe "sample.txt"
        expect(editor.isFocused).toBeTruthy()

    describe "when a tab is dragged from and dropped onto the same editor", ->
      it "moves the edit session, updates the order of the tabs, and focuses the editor", ->
        expect(tabs.find('.tab:eq(0) .file-name').text()).toBe "sample.js"
        expect(tabs.find('.tab:eq(1) .file-name').text()).toBe "sample.txt"

        sortableElement = [tabs.find('.tab:eq(0)')]
        spyOn(tabs, 'getSortableElement').andCallFake -> sortableElement[0]
        event = $.Event()
        event.target = tabs[0]
        event.originalEvent =
          dataTransfer:
            data: {}
            setData: (key, value) -> @data[key] = value
            getData: (key) -> @data[key]

        editor.hiddenInput.focusout()
        tabs.onDragStart(event)
        sortableElement = [tabs.find('.tab:eq(1)')]
        tabs.onDrop(event)

        expect(tabs.find('.tab:eq(0) .file-name').text()).toBe "sample.txt"
        expect(tabs.find('.tab:eq(1) .file-name').text()).toBe "sample.js"
        expect(editor.isFocused).toBeTruthy()

    describe "when a tab is dragged from one editor and dropped onto another editor", ->
      it "moves the edit session, updates the order of the tabs, and focuses the destination editor", ->
        leftTabs = tabs
        rightEditor = editor.splitRight()
        rightTabs = rootView.find('.tabs:last').view()

        sortableElement = [leftTabs.find('.tab:eq(0)')]
        spyOn(tabs, 'getSortableElement').andCallFake -> sortableElement[0]
        event = $.Event()
        event.target = leftTabs
        event.originalEvent =
          dataTransfer:
            data: {}
            setData: (key, value) -> @data[key] = value
            getData: (key) -> @data[key]

        rightEditor.hiddenInput.focusout()
        tabs.onDragStart(event)

        event.target = rightTabs
        sortableElement = [rightTabs.find('.tab:eq(0)')]
        tabs.onDrop(event)

        expect(rightTabs.find('.tab:eq(0) .file-name').text()).toBe "sample.txt"
        expect(rightTabs.find('.tab:eq(1) .file-name').text()).toBe "sample.js"
        expect(rightEditor.isFocused).toBeTruthy()
