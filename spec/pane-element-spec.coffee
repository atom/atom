PaneContainer = require '../src/pane-container'

describe "PaneElement", ->
  describe "when the active item changes", ->
    it "hides all item elements except the active one", ->
      container = new PaneContainer
      pane = container.getRoot()
      item1 = document.createElement('div')
      item2 = document.createElement('div')
      item3 = document.createElement('div')
      pane.addItem(item1)
      pane.addItem(item2)
      pane.addItem(item3)
      paneElement = atom.views.getView(pane)

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
      container = new PaneContainer
      pane = container.getRoot()
      item1 = document.createElement('div')
      item1.tabIndex = -1
      item2 = document.createElement('div')
      item2.tabIndex = -1
      pane.addItem(item1)
      pane.addItem(item2)
      paneElement = atom.views.getView(pane)
      jasmine.attachToDOM(paneElement)
      paneElement.focus()

      expect(document.activeElement).toBe item1
      pane.activateItem(item2)
      expect(document.activeElement).toBe item2

    describe "if the active item is a model object", ->
      it "retrieves the associated view from atom.views and appends it", ->
        class TestModel

        atom.views.addViewProvider TestModel, (model) ->
          view = document.createElement('div')
          view.model = model
          view

        item1 = new TestModel
        item2 = new TestModel

        container = new PaneContainer
        pane = container.getRoot()
        pane.addItem(item1)
        pane.addItem(item2)
        paneElement = atom.views.getView(pane)

        expect(paneElement.itemViews.children[0].model).toBe item1
        expect(paneElement.itemViews.children[0].style.display).toBe ''
        pane.activateItem(item2)
        expect(paneElement.itemViews.children[1].model).toBe item2
        expect(paneElement.itemViews.children[0].style.display).toBe 'none'
        expect(paneElement.itemViews.children[1].style.display).toBe ''

    describe "when the new active implements .getPath()", ->
      it "adds the file path and file name as a data attribute on the pane", ->
        container = new PaneContainer
        pane = container.getRoot()
        item1 = document.createElement('div')
        item1.getPath = -> '/foo/bar.txt'
        item2 = document.createElement('div')
        pane.addItem(item1)
        pane.addItem(item2)
        paneElement = atom.views.getView(pane)

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



