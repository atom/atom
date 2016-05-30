PaneContainer = require '../src/pane-container'

describe "PaneElement", ->
  [paneElement, container, containerElement, pane] = []

  beforeEach ->
    spyOn(atom.applicationDelegate, "open")

    container = new PaneContainer(config: atom.config, confirm: atom.confirm.bind(atom))
    containerElement = atom.views.getView(container)
    pane = container.getActivePane()
    paneElement = atom.views.getView(pane)

  describe "when the pane's active status changes", ->
    it "adds or removes the .active class as appropriate", ->
      pane2 = pane.splitRight()
      expect(pane2.isActive()).toBe true

      expect(paneElement.className).not.toMatch /active/
      pane.activate()
      expect(paneElement.className).toMatch /active/
      pane2.activate()
      expect(paneElement.className).not.toMatch /active/

  describe "when the active item changes", ->
    it "hides all item elements except the active one", ->
      item1 = document.createElement('div')
      item2 = document.createElement('div')
      item3 = document.createElement('div')
      pane.addItem(item1)
      pane.addItem(item2)
      pane.addItem(item3)

      expect(pane.getActiveItem()).toBe item1
      expect(item1.parentElement).toBeDefined()
      expect(item1.style.display).toBe ''
      expect(item2.parentElement).toBeNull()
      expect(item3.parentElement).toBeNull()

      pane.activateItem(item2)
      expect(item2.parentElement).toBeDefined()
      expect(item1.style.display).toBe 'none'
      expect(item2.style.display).toBe ''
      expect(item3.parentElement).toBeNull()

      pane.activateItem(item3)
      expect(item3.parentElement).toBeDefined()
      expect(item1.style.display).toBe 'none'
      expect(item2.style.display).toBe 'none'
      expect(item3.style.display).toBe ''

    it "transfers focus to the new item if the previous item was focused", ->
      item1 = document.createElement('div')
      item1.tabIndex = -1
      item2 = document.createElement('div')
      item2.tabIndex = -1
      pane.addItem(item1)
      pane.addItem(item2)
      jasmine.attachToDOM(paneElement)
      paneElement.focus()

      expect(document.activeElement).toBe item1
      pane.activateItem(item2)
      expect(document.activeElement).toBe item2

    describe "if the active item is a model object", ->
      it "retrieves the associated view from atom.views and appends it to the itemViews div", ->
        class TestModel

        atom.views.addViewProvider TestModel, (model) ->
          view = document.createElement('div')
          view.model = model
          view

        item1 = new TestModel
        item2 = new TestModel
        pane.addItem(item1)
        pane.addItem(item2)

        expect(paneElement.itemViews.children[0].model).toBe item1
        expect(paneElement.itemViews.children[0].style.display).toBe ''
        pane.activateItem(item2)
        expect(paneElement.itemViews.children[1].model).toBe item2
        expect(paneElement.itemViews.children[0].style.display).toBe 'none'
        expect(paneElement.itemViews.children[1].style.display).toBe ''

    describe "when the new active implements .getPath()", ->
      it "adds the file path and file name as a data attribute on the pane", ->
        item1 = document.createElement('div')
        item1.getPath = -> '/foo/bar.txt'
        item2 = document.createElement('div')
        pane.addItem(item1)
        pane.addItem(item2)

        expect(paneElement.dataset.activeItemPath).toBe '/foo/bar.txt'
        expect(paneElement.dataset.activeItemName).toBe 'bar.txt'

        pane.activateItem(item2)

        expect(paneElement.dataset.activeItemPath).toBeUndefined()
        expect(paneElement.dataset.activeItemName).toBeUndefined()

        pane.activateItem(item1)
        expect(paneElement.dataset.activeItemPath).toBe '/foo/bar.txt'
        expect(paneElement.dataset.activeItemName).toBe 'bar.txt'

        pane.destroyItems()
        expect(paneElement.dataset.activeItemPath).toBeUndefined()
        expect(paneElement.dataset.activeItemName).toBeUndefined()

  describe "when an item is removed from the pane", ->
    describe "when the destroyed item is an element", ->
      it "removes the item from the itemViews div", ->
        item1 = document.createElement('div')
        item2 = document.createElement('div')
        pane.addItem(item1)
        pane.addItem(item2)
        paneElement = atom.views.getView(pane)

        expect(item1.parentElement).toBe paneElement.itemViews
        pane.destroyItem(item1)
        expect(item1.parentElement).toBeNull()
        expect(item2.parentElement).toBe paneElement.itemViews
        pane.destroyItem(item2)
        expect(item2.parentElement).toBeNull()

    describe "when the destroyed item is a model", ->
      it "removes the model's associated view", ->
        class TestModel

        atom.views.addViewProvider TestModel, (model) ->
          view = document.createElement('div')
          model.element = view
          view.model = model
          view

        item1 = new TestModel
        item2 = new TestModel
        pane.addItem(item1)
        pane.addItem(item2)

        expect(item1.element.parentElement).toBe paneElement.itemViews
        pane.destroyItem(item1)
        expect(item1.element.parentElement).toBeNull()
        expect(item2.element.parentElement).toBe paneElement.itemViews
        pane.destroyItem(item2)
        expect(item2.element.parentElement).toBeNull()

  describe "when the pane element is focused", ->
    it "transfers focus to the active view", ->
      item = document.createElement('div')
      item.tabIndex = -1
      pane.activateItem(item)
      jasmine.attachToDOM(paneElement)

      expect(document.activeElement).toBe document.body
      paneElement.focus()
      expect(document.activeElement).toBe item

    it "makes the pane active", ->
      pane.splitRight()
      expect(pane.isActive()).toBe false

      jasmine.attachToDOM(paneElement)
      paneElement.focus()

      expect(pane.isActive()).toBe true

  describe "when the pane element is attached", ->
    it "focuses the pane element if isFocused() returns true on its model", ->
      pane.focus()
      jasmine.attachToDOM(paneElement)
      expect(document.activeElement).toBe paneElement

  describe "drag and drop", ->
    buildDragEvent = (type, files) ->
      dataTransfer =
        files: files
        data: {}
        setData: (key, value) -> @data[key] = value
        getData: (key) -> @data[key]

      event = new CustomEvent("drop")
      event.dataTransfer = dataTransfer
      event

    describe "when a file is dragged to the pane", ->
      it "opens it", ->
        event = buildDragEvent("drop", [{path: "/fake1"}, {path: "/fake2"}])
        paneElement.dispatchEvent(event)
        expect(atom.applicationDelegate.open.callCount).toBe 1
        expect(atom.applicationDelegate.open.argsForCall[0][0]).toEqual pathsToOpen: ['/fake1', '/fake2']

    describe "when a non-file is dragged to the pane", ->
      it "does nothing", ->
        event = buildDragEvent("drop", [])
        paneElement.dispatchEvent(event)
        expect(atom.applicationDelegate.open).not.toHaveBeenCalled()

  describe "resize", ->
    it "shrinks independently of its contents' width", ->
      jasmine.attachToDOM(containerElement)
      item = document.createElement('div')
      item.style.width = "2000px"
      item.style.height = "30px"
      paneElement.insertBefore(item, paneElement.children[0])

      paneElement.style.flexGrow = 0.1
      expect(paneElement.getBoundingClientRect().width).toBeGreaterThan(0)
      expect(paneElement.getBoundingClientRect().width).toBeLessThan(item.getBoundingClientRect().width)

      paneElement.style.flexGrow = 0
      expect(paneElement.getBoundingClientRect().width).toBe(0)
