{Model} = require 'theorist'
Pane = require '../src/pane'
PaneAxis = require '../src/pane-axis'
PaneContainer = require '../src/pane-container'

describe "Pane", ->
  deserializerDisposable = null

  class Item extends Model
    @deserialize: ({name, uri}) -> new this(name, uri)
    constructor: (@name, @uri) ->
    getURI: -> @uri
    getPath: -> @path
    serialize: -> {deserializer: 'Item', @name, @uri}
    isEqual: (other) -> @name is other?.name

  beforeEach ->
    deserializerDisposable = atom.deserializers.add(Item)

  afterEach ->
    deserializerDisposable.dispose()

  describe "construction", ->
    it "sets the active item to the first item", ->
      pane = new Pane(items: [new Item("A"), new Item("B")])
      expect(pane.getActiveItem()).toBe pane.itemAtIndex(0)

    it "compacts the items array", ->
      pane = new Pane(items: [undefined, new Item("A"), null, new Item("B")])
      expect(pane.getItems().length).toBe 2
      expect(pane.getActiveItem()).toBe pane.itemAtIndex(0)

  describe "::activate()", ->
    [container, pane1, pane2] = []

    beforeEach ->
      container = new PaneContainer(root: new Pane)
      container.getRoot().splitRight()
      [pane1, pane2] = container.getPanes()

    it "changes the active pane on the container", ->
      expect(container.getActivePane()).toBe pane2
      pane1.activate()
      expect(container.getActivePane()).toBe pane1
      pane2.activate()
      expect(container.getActivePane()).toBe pane2

    it "invokes ::onDidChangeActivePane observers on the container", ->
      observed = []
      container.onDidChangeActivePane (activePane) -> observed.push(activePane)

      pane1.activate()
      pane1.activate()
      pane2.activate()
      pane1.activate()
      expect(observed).toEqual [pane1, pane2, pane1]

    it "invokes ::onDidChangeActive observers on the relevant panes", ->
      observed = []
      pane1.onDidChangeActive (active) -> observed.push(active)
      pane1.activate()
      pane2.activate()
      expect(observed).toEqual [true, false]

    it "invokes ::onDidActivate() observers", ->
      eventCount = 0
      pane1.onDidActivate -> eventCount++
      pane1.activate()
      pane1.activate()
      pane2.activate()
      expect(eventCount).toBe 2

  describe "::addItem(item, index)", ->
    it "adds the item at the given index", ->
      pane = new Pane(items: [new Item("A"), new Item("B")])
      [item1, item2] = pane.getItems()
      item3 = new Item("C")
      pane.addItem(item3, 1)
      expect(pane.getItems()).toEqual [item1, item3, item2]

    it "adds the item after the active item if no index is provided", ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      [item1, item2, item3] = pane.getItems()
      pane.activateItem(item2)
      item4 = new Item("D")
      pane.addItem(item4)
      expect(pane.getItems()).toEqual [item1, item2, item4, item3]

    it "sets the active item after adding the first item", ->
      pane = new Pane
      item = new Item("A")
      pane.addItem(item)
      expect(pane.getActiveItem()).toBe item

    it "invokes ::onDidAddItem() observers", ->
      pane = new Pane(items: [new Item("A"), new Item("B")])
      events = []
      pane.onDidAddItem (event) -> events.push(event)

      item = new Item("C")
      pane.addItem(item, 1)
      expect(events).toEqual [{item, index: 1}]

    it "throws an exception if the item is already present on a pane", ->
      item = new Item("A")
      pane1 = new Pane(items: [item])
      container = new PaneContainer(root: pane1)
      pane2 = pane1.splitRight()
      expect(-> pane2.addItem(item)).toThrow()

  describe "::activateItem(item)", ->
    pane = null

    beforeEach ->
      pane = new Pane(items: [new Item("A"), new Item("B")])

    it "changes the active item to the current item", ->
      expect(pane.getActiveItem()).toBe pane.itemAtIndex(0)
      pane.activateItem(pane.itemAtIndex(1))
      expect(pane.getActiveItem()).toBe pane.itemAtIndex(1)

    it "adds the given item if it isn't present in ::items", ->
      item = new Item("C")
      pane.activateItem(item)
      expect(item in pane.getItems()).toBe true
      expect(pane.getActiveItem()).toBe item

    it "invokes ::onDidChangeActiveItem() observers", ->
      observed = []
      pane.onDidChangeActiveItem (item) -> observed.push(item)
      pane.activateItem(pane.itemAtIndex(1))
      expect(observed).toEqual [pane.itemAtIndex(1)]

  describe "::activateNextItem() and ::activatePreviousItem()", ->
    it "sets the active item to the next/previous item, looping around at either end", ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      [item1, item2, item3] = pane.getItems()

      expect(pane.getActiveItem()).toBe item1
      pane.activatePreviousItem()
      expect(pane.getActiveItem()).toBe item3
      pane.activatePreviousItem()
      expect(pane.getActiveItem()).toBe item2
      pane.activateNextItem()
      expect(pane.getActiveItem()).toBe item3
      pane.activateNextItem()
      expect(pane.getActiveItem()).toBe item1

  describe "::moveItemRight() and ::moveItemLeft()", ->
    it "moves the active item to the right and left, without looping around at either end", ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      [item1, item2, item3] = pane.getItems()

      pane.activateItemAtIndex(0)
      expect(pane.getActiveItem()).toBe item1
      pane.moveItemLeft()
      expect(pane.getItems()).toEqual [item1, item2, item3]
      pane.moveItemRight()
      expect(pane.getItems()).toEqual [item2, item1, item3]
      pane.moveItemLeft()
      expect(pane.getItems()).toEqual [item1, item2, item3]
      pane.activateItemAtIndex(2)
      expect(pane.getActiveItem()).toBe item3
      pane.moveItemRight()
      expect(pane.getItems()).toEqual [item1, item2, item3]

  describe "::activateItemAtIndex(index)", ->
    it "activates the item at the given index", ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      [item1, item2, item3] = pane.getItems()
      pane.activateItemAtIndex(2)
      expect(pane.getActiveItem()).toBe item3
      pane.activateItemAtIndex(1)
      expect(pane.getActiveItem()).toBe item2
      pane.activateItemAtIndex(0)
      expect(pane.getActiveItem()).toBe item1

      # Doesn't fail with out-of-bounds indices
      pane.activateItemAtIndex(100)
      expect(pane.getActiveItem()).toBe item1
      pane.activateItemAtIndex(-1)
      expect(pane.getActiveItem()).toBe item1

  describe "::destroyItem(item)", ->
    [pane, item1, item2, item3] = []

    beforeEach ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      [item1, item2, item3] = pane.getItems()

    it "removes the item from the items list and destroyes it", ->
      expect(pane.getActiveItem()).toBe item1
      pane.destroyItem(item2)
      expect(item2 in pane.getItems()).toBe false
      expect(item2.isDestroyed()).toBe true
      expect(pane.getActiveItem()).toBe item1

      pane.destroyItem(item1)
      expect(item1 in pane.getItems()).toBe false
      expect(item1.isDestroyed()).toBe true

    it "invokes ::onWillDestroyItem() observers before destroying the item", ->
      events = []
      pane.onWillDestroyItem (event) ->
        expect(item2.isDestroyed()).toBe false
        events.push(event)

      pane.destroyItem(item2)
      expect(item2.isDestroyed()).toBe true
      expect(events).toEqual [{item: item2, index: 1}]

    it "invokes ::onDidRemoveItem() observers", ->
      events = []
      pane.onDidRemoveItem (event) -> events.push(event)
      pane.destroyItem(item2)
      expect(events).toEqual [{item: item2, index: 1, destroyed: true}]

    describe "when the destroyed item is the active item and is the first item", ->
      it "activates the next item", ->
        expect(pane.getActiveItem()).toBe item1
        pane.destroyItem(item1)
        expect(pane.getActiveItem()).toBe item2

    describe "when the destroyed item is the active item and is not the first item", ->
      beforeEach ->
        pane.activateItem(item2)

      it "activates the previous item", ->
        expect(pane.getActiveItem()).toBe item2
        pane.destroyItem(item2)
        expect(pane.getActiveItem()).toBe item1

    describe "if the item is modified", ->
      itemURI = null

      beforeEach ->
        item1.shouldPromptToSave = -> true
        item1.save = jasmine.createSpy("save")
        item1.saveAs = jasmine.createSpy("saveAs")
        item1.getURI = -> itemURI

      describe "if the [Save] option is selected", ->
        describe "when the item has a uri", ->
          it "saves the item before destroying it", ->
            itemURI = "test"
            spyOn(atom, 'confirm').andReturn(0)
            pane.destroyItem(item1)

            expect(item1.save).toHaveBeenCalled()
            expect(item1 in pane.getItems()).toBe false
            expect(item1.isDestroyed()).toBe true

        describe "when the item has no uri", ->
          it "presents a save-as dialog, then saves the item with the given uri before removing and destroying it", ->
            itemURI = null

            spyOn(atom, 'showSaveDialogSync').andReturn("/selected/path")
            spyOn(atom, 'confirm').andReturn(0)
            pane.destroyItem(item1)

            expect(atom.showSaveDialogSync).toHaveBeenCalled()
            expect(item1.saveAs).toHaveBeenCalledWith("/selected/path")
            expect(item1 in pane.getItems()).toBe false
            expect(item1.isDestroyed()).toBe true

      describe "if the [Don't Save] option is selected", ->
        it "removes and destroys the item without saving it", ->
          spyOn(atom, 'confirm').andReturn(2)
          pane.destroyItem(item1)

          expect(item1.save).not.toHaveBeenCalled()
          expect(item1 in pane.getItems()).toBe false
          expect(item1.isDestroyed()).toBe true

      describe "if the [Cancel] option is selected", ->
        it "does not save, remove, or destroy the item", ->
          spyOn(atom, 'confirm').andReturn(1)
          pane.destroyItem(item1)

          expect(item1.save).not.toHaveBeenCalled()
          expect(item1 in pane.getItems()).toBe true
          expect(item1.isDestroyed()).toBe false

    describe "when the last item is destroyed", ->
      describe "when the 'core.destroyEmptyPanes' config option is false (the default)", ->
        it "does not destroy the pane, but leaves it in place with empty items", ->
          expect(atom.config.get('core.destroyEmptyPanes')).toBe false
          pane.destroyItem(item) for item in pane.getItems()
          expect(pane.isDestroyed()).toBe false
          expect(pane.getActiveItem()).toBeUndefined()
          expect(-> pane.saveActiveItem()).not.toThrow()
          expect(-> pane.saveActiveItemAs()).not.toThrow()

      describe "when the 'core.destroyEmptyPanes' config option is true", ->
        it "destroys the pane", ->
          atom.config.set('core.destroyEmptyPanes', true)
          pane.destroyItem(item) for item in pane.getItems()
          expect(pane.isDestroyed()).toBe true

  describe "::destroyActiveItem()", ->
    it "destroys the active item", ->
      pane = new Pane(items: [new Item("A"), new Item("B")])
      activeItem = pane.getActiveItem()
      pane.destroyActiveItem()
      expect(activeItem.isDestroyed()).toBe true
      expect(activeItem in pane.getItems()).toBe false

    it "does not throw an exception if there are no more items", ->
      pane = new Pane
      pane.destroyActiveItem()

  describe "::destroyItems()", ->
    it "destroys all items", ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      [item1, item2, item3] = pane.getItems()
      pane.destroyItems()
      expect(item1.isDestroyed()).toBe true
      expect(item2.isDestroyed()).toBe true
      expect(item3.isDestroyed()).toBe true
      expect(pane.getItems()).toEqual []

  describe "::observeItems()", ->
    it "invokes the observer with all current and future items", ->
      pane = new Pane(items: [new Item, new Item])
      [item1, item2] = pane.getItems()

      observed = []
      pane.observeItems (item) -> observed.push(item)

      item3 = new Item
      pane.addItem(item3)

      expect(observed).toEqual [item1, item2, item3]

  describe "when an item emits a destroyed event", ->
    it "removes it from the list of items", ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      [item1, item2, item3] = pane.getItems()
      pane.itemAtIndex(1).destroy()
      expect(pane.getItems()).toEqual [item1, item3]

  describe "::destroyInactiveItems()", ->
    it "destroys all items but the active item", ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      [item1, item2, item3] = pane.getItems()
      pane.activateItem(item2)
      pane.destroyInactiveItems()
      expect(pane.getItems()).toEqual [item2]

  describe "::saveActiveItem()", ->
    pane = null

    beforeEach ->
      pane = new Pane(items: [new Item("A")])
      spyOn(atom, 'showSaveDialogSync').andReturn('/selected/path')

    describe "when the active item has a uri", ->
      beforeEach ->
        pane.getActiveItem().uri = "test"

      describe "when the active item has a save method", ->
        it "saves the current item", ->
          pane.getActiveItem().save = jasmine.createSpy("save")
          pane.saveActiveItem()
          expect(pane.getActiveItem().save).toHaveBeenCalled()

      describe "when the current item has no save method", ->
        it "does nothing", ->
          expect(pane.getActiveItem().save).toBeUndefined()
          pane.saveActiveItem()

    describe "when the current item has no uri", ->
      describe "when the current item has a saveAs method", ->
        it "opens a save dialog and saves the current item as the selected path", ->
          pane.getActiveItem().saveAs = jasmine.createSpy("saveAs")
          pane.saveActiveItem()
          expect(atom.showSaveDialogSync).toHaveBeenCalled()
          expect(pane.getActiveItem().saveAs).toHaveBeenCalledWith('/selected/path')

      describe "when the current item has no saveAs method", ->
        it "does nothing", ->
          expect(pane.getActiveItem().saveAs).toBeUndefined()
          pane.saveActiveItem()
          expect(atom.showSaveDialogSync).not.toHaveBeenCalled()

    describe "when the item's saveAs method throws a well-known IO error", ->
      notificationSpy = null
      beforeEach ->
        atom.notifications.onDidAddNotification notificationSpy = jasmine.createSpy()

      it "creates a notification", ->
        pane.getActiveItem().saveAs = ->
          error = new Error("EACCES, permission denied '/foo'")
          error.path = '/foo'
          error.code = 'EACCES'
          throw error

        pane.saveActiveItem()
        expect(notificationSpy).toHaveBeenCalled()
        notification = notificationSpy.mostRecentCall.args[0]
        expect(notification.getType()).toBe 'warning'
        expect(notification.getMessage()).toContain 'Permission denied'
        expect(notification.getMessage()).toContain '/foo'

  describe "::saveActiveItemAs()", ->
    pane = null

    beforeEach ->
      pane = new Pane(items: [new Item("A")])
      spyOn(atom, 'showSaveDialogSync').andReturn('/selected/path')

    describe "when the current item has a saveAs method", ->
      it "opens the save dialog and calls saveAs on the item with the selected path", ->
        pane.getActiveItem().path = __filename
        pane.getActiveItem().saveAs = jasmine.createSpy("saveAs")
        pane.saveActiveItemAs()
        expect(atom.showSaveDialogSync).toHaveBeenCalledWith(__filename)
        expect(pane.getActiveItem().saveAs).toHaveBeenCalledWith('/selected/path')

    describe "when the current item does not have a saveAs method", ->
      it "does nothing", ->
        expect(pane.getActiveItem().saveAs).toBeUndefined()
        pane.saveActiveItemAs()
        expect(atom.showSaveDialogSync).not.toHaveBeenCalled()

    describe "when the item's saveAs method throws a well-known IO error", ->
      notificationSpy = null
      beforeEach ->
        atom.notifications.onDidAddNotification notificationSpy = jasmine.createSpy()

      it "creates a notification", ->
        pane.getActiveItem().saveAs = ->
          error = new Error("EACCES, permission denied '/foo'")
          error.path = '/foo'
          error.code = 'EACCES'
          throw error

        pane.saveActiveItemAs()
        expect(notificationSpy).toHaveBeenCalled()
        notification = notificationSpy.mostRecentCall.args[0]
        expect(notification.getType()).toBe 'warning'
        expect(notification.getMessage()).toContain 'Permission denied'
        expect(notification.getMessage()).toContain '/foo'

  describe "::itemForURI(uri)", ->
    it "returns the item for which a call to .getURI() returns the given uri", ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C"), new Item("D")])
      [item1, item2, item3] = pane.getItems()
      item1.uri = "a"
      item2.uri = "b"
      expect(pane.itemForURI("a")).toBe item1
      expect(pane.itemForURI("b")).toBe item2
      expect(pane.itemForURI("bogus")).toBeUndefined()

  describe "::moveItem(item, index)", ->
    [pane, item1, item2, item3, item4] = []

    beforeEach ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C"), new Item("D")])
      [item1, item2, item3, item4] = pane.getItems()

    it "moves the item to the given index and invokes ::onDidMoveItem observers", ->
      pane.moveItem(item1, 2)
      expect(pane.getItems()).toEqual [item2, item3, item1, item4]

      pane.moveItem(item2, 3)
      expect(pane.getItems()).toEqual [item3, item1, item4, item2]

      pane.moveItem(item2, 1)
      expect(pane.getItems()).toEqual [item3, item2, item1, item4]

    it "invokes ::onDidMoveItem() observers", ->
      events = []
      pane.onDidMoveItem (event) -> events.push(event)

      pane.moveItem(item1, 2)
      pane.moveItem(item2, 3)
      expect(events).toEqual [
        {item: item1, oldIndex: 0, newIndex: 2}
        {item: item2, oldIndex: 0, newIndex: 3}
      ]

  describe "::moveItemToPane(item, pane, index)", ->
    [container, pane1, pane2] = []
    [item1, item2, item3, item4, item5] = []

    beforeEach ->
      pane1 = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      container = new PaneContainer(root: pane1)
      pane2 = pane1.splitRight(items: [new Item("D"), new Item("E")])
      [item1, item2, item3] = pane1.getItems()
      [item4, item5] = pane2.getItems()

    it "moves the item to the given pane at the given index", ->
      pane1.moveItemToPane(item2, pane2, 1)
      expect(pane1.getItems()).toEqual [item1, item3]
      expect(pane2.getItems()).toEqual [item4, item2, item5]

    it "invokes ::onDidRemoveItem() observers", ->
      events = []
      pane1.onDidRemoveItem (event) -> events.push(event)
      pane1.moveItemToPane(item2, pane2, 1)

      expect(events).toEqual [{item: item2, index: 1, destroyed: false}]

    describe "when the moved item the last item in the source pane", ->
      beforeEach ->
        item5.destroy()

      describe "when the 'core.destroyEmptyPanes' config option is false (the default)", ->
        it "does not destroy the pane or the item", ->
          pane2.moveItemToPane(item4, pane1, 0)
          expect(pane2.isDestroyed()).toBe false
          expect(item4.isDestroyed()).toBe false

      describe "when the 'core.destroyEmptyPanes' config option is true", ->
        it "destroys the pane, but not the item", ->
          atom.config.set('core.destroyEmptyPanes', true)
          pane2.moveItemToPane(item4, pane1, 0)
          expect(pane2.isDestroyed()).toBe true
          expect(item4.isDestroyed()).toBe false

  describe "split methods", ->
    [pane1, container] = []

    beforeEach ->
      pane1 = new Pane(items: [new Item("A")])
      container = new PaneContainer(root: pane1)

    describe "::splitLeft(params)", ->
      describe "when the parent is the container root", ->
        it "replaces itself with a row and inserts a new pane to the left of itself", ->
          pane2 = pane1.splitLeft(items: [new Item("B")])
          pane3 = pane1.splitLeft(items: [new Item("C")])
          expect(container.root.orientation).toBe 'horizontal'
          expect(container.root.children).toEqual [pane2, pane3, pane1]

      describe "when `copyActiveItem: true` is passed in the params", ->
        it "duplicates the active item", ->
          pane2 = pane1.splitLeft(copyActiveItem: true)
          expect(pane2.getActiveItem()).toEqual pane1.getActiveItem()

      describe "when the parent is a column", ->
        it "replaces itself with a row and inserts a new pane to the left of itself", ->
          pane1.splitDown()
          pane2 = pane1.splitLeft(items: [new Item("B")])
          pane3 = pane1.splitLeft(items: [new Item("C")])
          row = container.root.children[0]
          expect(row.orientation).toBe 'horizontal'
          expect(row.children).toEqual [pane2, pane3, pane1]

    describe "::splitRight(params)", ->
      describe "when the parent is the container root", ->
        it "replaces itself with a row and inserts a new pane to the right of itself", ->
          pane2 = pane1.splitRight(items: [new Item("B")])
          pane3 = pane1.splitRight(items: [new Item("C")])
          expect(container.root.orientation).toBe 'horizontal'
          expect(container.root.children).toEqual [pane1, pane3, pane2]

      describe "when `copyActiveItem: true` is passed in the params", ->
        it "duplicates the active item", ->
          pane2 = pane1.splitRight(copyActiveItem: true)
          expect(pane2.getActiveItem()).toEqual pane1.getActiveItem()

      describe "when the parent is a column", ->
        it "replaces itself with a row and inserts a new pane to the right of itself", ->
          pane1.splitDown()
          pane2 = pane1.splitRight(items: [new Item("B")])
          pane3 = pane1.splitRight(items: [new Item("C")])
          row = container.root.children[0]
          expect(row.orientation).toBe 'horizontal'
          expect(row.children).toEqual [pane1, pane3, pane2]

    describe "::splitUp(params)", ->
      describe "when the parent is the container root", ->
        it "replaces itself with a column and inserts a new pane above itself", ->
          pane2 = pane1.splitUp(items: [new Item("B")])
          pane3 = pane1.splitUp(items: [new Item("C")])
          expect(container.root.orientation).toBe 'vertical'
          expect(container.root.children).toEqual [pane2, pane3, pane1]

      describe "when `copyActiveItem: true` is passed in the params", ->
        it "duplicates the active item", ->
          pane2 = pane1.splitUp(copyActiveItem: true)
          expect(pane2.getActiveItem()).toEqual pane1.getActiveItem()

      describe "when the parent is a row", ->
        it "replaces itself with a column and inserts a new pane above itself", ->
          pane1.splitRight()
          pane2 = pane1.splitUp(items: [new Item("B")])
          pane3 = pane1.splitUp(items: [new Item("C")])
          column = container.root.children[0]
          expect(column.orientation).toBe 'vertical'
          expect(column.children).toEqual [pane2, pane3, pane1]

    describe "::splitDown(params)", ->
      describe "when the parent is the container root", ->
        it "replaces itself with a column and inserts a new pane below itself", ->
          pane2 = pane1.splitDown(items: [new Item("B")])
          pane3 = pane1.splitDown(items: [new Item("C")])
          expect(container.root.orientation).toBe 'vertical'
          expect(container.root.children).toEqual [pane1, pane3, pane2]

      describe "when `copyActiveItem: true` is passed in the params", ->
        it "duplicates the active item", ->
          pane2 = pane1.splitDown(copyActiveItem: true)
          expect(pane2.getActiveItem()).toEqual pane1.getActiveItem()

      describe "when the parent is a row", ->
        it "replaces itself with a column and inserts a new pane below itself", ->
          pane1.splitRight()
          pane2 = pane1.splitDown(items: [new Item("B")])
          pane3 = pane1.splitDown(items: [new Item("C")])
          column = container.root.children[0]
          expect(column.orientation).toBe 'vertical'
          expect(column.children).toEqual [pane1, pane3, pane2]

    it "activates the new pane", ->
      expect(pane1.isActive()).toBe true
      pane2 = pane1.splitRight()
      expect(pane1.isActive()).toBe false
      expect(pane2.isActive()).toBe true

  describe "::close()", ->
    it "prompts to save unsaved items before destroying the pane", ->
      pane = new Pane(items: [new Item("A"), new Item("B")])
      [item1, item2] = pane.getItems()

      item1.shouldPromptToSave = -> true
      item1.getURI = -> "/test/path"
      item1.save = jasmine.createSpy("save")

      spyOn(atom, 'confirm').andReturn(0)
      pane.close()

      expect(atom.confirm).toHaveBeenCalled()
      expect(item1.save).toHaveBeenCalled()
      expect(pane.isDestroyed()).toBe true

    it "does not destroy the pane if cancel is called", ->
      pane = new Pane(items: [new Item("A"), new Item("B")])
      [item1, item2] = pane.getItems()

      item1.shouldPromptToSave = -> true
      item1.getURI = -> "/test/path"
      item1.save = jasmine.createSpy("save")

      spyOn(atom, 'confirm').andReturn(1)
      pane.close()

      expect(atom.confirm).toHaveBeenCalled()
      expect(item1.save).not.toHaveBeenCalled()
      expect(pane.isDestroyed()).toBe false

  describe "::destroy()", ->
    [container, pane1, pane2] = []

    beforeEach ->
      container = new PaneContainer
      pane1 = container.root
      pane1.addItems([new Item("A"), new Item("B")])
      pane2 = pane1.splitRight()

    it "destroys the pane's destroyable items", ->
      [item1, item2] = pane1.getItems()
      pane1.destroy()
      expect(item1.isDestroyed()).toBe true
      expect(item2.isDestroyed()).toBe true

    describe "if the pane is active", ->
      it "makes the next pane active", ->
        expect(pane2.isActive()).toBe true
        pane2.destroy()
        expect(pane1.isActive()).to

    describe "if the pane's parent has more than two children", ->
      it "removes the pane from its parent", ->
        pane3 = pane2.splitRight()

        expect(container.root.children).toEqual [pane1, pane2, pane3]
        pane2.destroy()
        expect(container.root.children).toEqual [pane1, pane3]

    describe "if the pane's parent has two children", ->
      it "replaces the parent with its last remaining child", ->
        pane3 = pane2.splitDown()

        expect(container.root.children[0]).toBe pane1
        expect(container.root.children[1].children).toEqual [pane2, pane3]
        pane3.destroy()
        expect(container.root.children).toEqual [pane1, pane2]
        pane2.destroy()
        expect(container.root).toBe pane1

  describe "serialization", ->
    pane = null

    beforeEach ->
      pane = new Pane(items: [new Item("A", "a"), new Item("B", "b"), new Item("C", "c")])

    it "can serialize and deserialize the pane and all its items", ->
      newPane = pane.testSerialization()
      expect(newPane.getItems()).toEqual pane.getItems()

    it "restores the active item on deserialization", ->
      pane.activateItemAtIndex(1)
      newPane = pane.testSerialization()
      expect(newPane.getActiveItem()).toEqual newPane.itemAtIndex(1)

    it "does not include items that cannot be deserialized", ->
      spyOn(console, 'warn')
      unserializable = {}
      pane.activateItem(unserializable)

      newPane = pane.testSerialization()
      expect(newPane.getActiveItem()).toEqual pane.itemAtIndex(0)
      expect(newPane.getItems().length).toBe pane.getItems().length - 1

    it "includes the pane's focus state in the serialized state", ->
      pane.focus()
      newPane = pane.testSerialization()
      expect(newPane.focused).toBe true
