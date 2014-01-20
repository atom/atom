{Model} = require 'theorist'
Pane = require '../src/pane'
PaneAxis = require '../src/pane-axis'
PaneContainer = require '../src/pane-container'

describe "Pane", ->
  class Item extends Model
    @deserialize: ({name, uri}) -> new this(name, uri)
    constructor: (@name, @uri) ->
    getUri: -> @uri
    getPath: -> @path
    serialize: -> {deserializer: 'Item', @name, @uri}
    isEqual: (other) -> @name is other?.name

  beforeEach ->
    atom.deserializers.add(Item)

  afterEach ->
    atom.deserializers.remove(Item)

  describe "construction", ->
    it "sets the active item to the first item", ->
      pane = new Pane(items: [new Item("A"), new Item("B")])
      expect(pane.activeItem).toBe pane.items[0]

    it "compacts the items array", ->
      pane = new Pane(items: [undefined, new Item("A"), null, new Item("B")])
      expect(pane.items.length).toBe 2
      expect(pane.activeItem).toBe pane.items[0]

  describe "::addItem(item, index)", ->
    it "adds the item at the given index", ->
      pane = new Pane(items: [new Item("A"), new Item("B")])
      [item1, item2] = pane.items
      item3 = new Item("C")
      pane.addItem(item3, 1)
      expect(pane.items).toEqual [item1, item3, item2]

    it "adds the item after the active item ", ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      [item1, item2, item3] = pane.items
      pane.activateItem(item2)
      item4 = new Item("D")
      pane.addItem(item4)
      expect(pane.items).toEqual [item1, item2, item4, item3]

    it "sets the active item after adding the first item", ->
      pane = new Pane
      item = new Item("A")
      events = []
      pane.on 'item-added', -> events.push('item-added')
      pane.$activeItem.changes.onValue -> events.push('active-item-changed')

      pane.addItem(item)
      expect(pane.activeItem).toBe item
      expect(events).toEqual ['item-added', 'active-item-changed']

  describe "::activateItem(item)", ->
    pane = null

    beforeEach ->
      pane = new Pane(items: [new Item("A"), new Item("B")])

    it "changes the active item to the current item", ->
      expect(pane.activeItem).toBe pane.items[0]
      pane.activateItem(pane.items[1])
      expect(pane.activeItem).toBe pane.items[1]

    it "adds the given item if it isn't present in ::items", ->
      item = new Item("C")
      pane.activateItem(item)
      expect(item in pane.items).toBe true
      expect(pane.activeItem).toBe item

  describe "::activateNextItem() and ::activatePreviousItem()", ->
    it "sets the active item to the next/previous item, looping around at either end", ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      [item1, item2, item3] = pane.items

      expect(pane.activeItem).toBe item1
      pane.activatePreviousItem()
      expect(pane.activeItem).toBe item3
      pane.activatePreviousItem()
      expect(pane.activeItem).toBe item2
      pane.activateNextItem()
      expect(pane.activeItem).toBe item3
      pane.activateNextItem()
      expect(pane.activeItem).toBe item1

  describe "::activateItemAtIndex(index)", ->
    it "activates the item at the given index", ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      [item1, item2, item3] = pane.items
      pane.activateItemAtIndex(2)
      expect(pane.activeItem).toBe item3
      pane.activateItemAtIndex(1)
      expect(pane.activeItem).toBe item2
      pane.activateItemAtIndex(0)
      expect(pane.activeItem).toBe item1

      # Doesn't fail with out-of-bounds indices
      pane.activateItemAtIndex(100)
      expect(pane.activeItem).toBe item1
      pane.activateItemAtIndex(-1)
      expect(pane.activeItem).toBe item1

  describe "::destroyItem(item)", ->
    [pane, item1, item2, item3] = []

    beforeEach ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      [item1, item2, item3] = pane.items

    it "removes the item from the items list", ->
      expect(pane.activeItem).toBe item1
      pane.destroyItem(item2)
      expect(item2 in pane.items).toBe false
      expect(pane.activeItem).toBe item1

      pane.destroyItem(item1)
      expect(item1 in pane.items).toBe false

    describe "when the destroyed item is the active item and is the first item", ->
      it "activates the next item", ->
        expect(pane.activeItem).toBe item1
        pane.destroyItem(item1)
        expect(pane.activeItem).toBe item2

    describe "when the destroyed item is the active item and is not the first item", ->
      beforeEach ->
        pane.activateItem(item2)

      it "activates the previous item", ->
        expect(pane.activeItem).toBe item2
        pane.destroyItem(item2)
        expect(pane.activeItem).toBe item1

    it "emits 'item-removed' with the item, its index, and true indicating the item is being destroyed", ->
      pane.on 'item-removed', itemRemovedHandler = jasmine.createSpy("itemRemovedHandler")
      pane.destroyItem(item2)
      expect(itemRemovedHandler).toHaveBeenCalledWith(item2, 1, true)

    describe "if the item is modified", ->
      itemUri = null

      beforeEach ->
        item1.shouldPromptToSave = -> true
        item1.save = jasmine.createSpy("save")
        item1.saveAs = jasmine.createSpy("saveAs")
        item1.getUri = -> itemUri

      describe "if the [Save] option is selected", ->
        describe "when the item has a uri", ->
          it "saves the item before destroying it", ->
            itemUri = "test"
            spyOn(atom, 'confirm').andReturn(0)
            pane.destroyItem(item1)

            expect(item1.save).toHaveBeenCalled()
            expect(item1 in pane.items).toBe false
            expect(item1.isDestroyed()).toBe true

        describe "when the item has no uri", ->
          it "presents a save-as dialog, then saves the item with the given uri before removing and destroying it", ->
            itemUri = null

            spyOn(atom, 'showSaveDialogSync').andReturn("/selected/path")
            spyOn(atom, 'confirm').andReturn(0)
            pane.destroyItem(item1)

            expect(atom.showSaveDialogSync).toHaveBeenCalled()
            expect(item1.saveAs).toHaveBeenCalledWith("/selected/path")
            expect(item1 in pane.items).toBe false
            expect(item1.isDestroyed()).toBe true

      describe "if the [Don't Save] option is selected", ->
        it "removes and destroys the item without saving it", ->
          spyOn(atom, 'confirm').andReturn(2)
          pane.destroyItem(item1)

          expect(item1.save).not.toHaveBeenCalled()
          expect(item1 in pane.items).toBe false
          expect(item1.isDestroyed()).toBe true

      describe "if the [Cancel] option is selected", ->
        it "does not save, remove, or destroy the item", ->
          spyOn(atom, 'confirm').andReturn(1)
          pane.destroyItem(item1)

          expect(item1.save).not.toHaveBeenCalled()
          expect(item1 in pane.items).toBe true
          expect(item1.isDestroyed()).toBe false

    describe "when the last item is destroyed", ->
      describe "when the 'core.destroyEmptyPanes' config option is false (the default)", ->
        it "does not destroy the pane, but leaves it in place with empty items", ->
          expect(atom.config.get('core.destroyEmptyPanes')).toBe false
          pane.destroyItem(item) for item in pane.getItems()
          expect(pane.isDestroyed()).toBe false
          expect(pane.activeItem).toBeUndefined()
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
      activeItem = pane.activeItem
      pane.destroyActiveItem()
      expect(activeItem.isDestroyed()).toBe true
      expect(activeItem in pane.items).toBe false

    it "does not throw an exception if there are no more items", ->
      pane = new Pane
      pane.destroyActiveItem()

  describe "::destroyItems()", ->
    it "destroys all items", ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      [item1, item2, item3] = pane.items
      pane.destroyItems()
      expect(item1.isDestroyed()).toBe true
      expect(item2.isDestroyed()).toBe true
      expect(item3.isDestroyed()).toBe true
      expect(pane.items).toEqual []

  describe "when an item emits a destroyed event", ->
    it "removes it from the list of items", ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      [item1, item2, item3] = pane.items
      pane.items[1].destroy()
      expect(pane.items).toEqual [item1, item3]

  describe "::destroyInactiveItems()", ->
    it "destroys all items but the active item", ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      [item1, item2, item3] = pane.items
      pane.activateItem(item2)
      pane.destroyInactiveItems()
      expect(pane.items).toEqual [item2]

  describe "::saveActiveItem()", ->
    pane = null

    beforeEach ->
      pane = new Pane(items: [new Item("A")])
      spyOn(atom, 'showSaveDialogSync').andReturn('/selected/path')

    describe "when the active item has a uri", ->
      beforeEach ->
        pane.activeItem.uri = "test"

      describe "when the active item has a save method", ->
        it "saves the current item", ->
          pane.activeItem.save = jasmine.createSpy("save")
          pane.saveActiveItem()
          expect(pane.activeItem.save).toHaveBeenCalled()

      describe "when the current item has no save method", ->
        it "does nothing", ->
          expect(pane.activeItem.save).toBeUndefined()
          pane.saveActiveItem()

    describe "when the current item has no uri", ->
      describe "when the current item has a saveAs method", ->
        it "opens a save dialog and saves the current item as the selected path", ->
          pane.activeItem.saveAs = jasmine.createSpy("saveAs")
          pane.saveActiveItem()
          expect(atom.showSaveDialogSync).toHaveBeenCalled()
          expect(pane.activeItem.saveAs).toHaveBeenCalledWith('/selected/path')

      describe "when the current item has no saveAs method", ->
        it "does nothing", ->
          expect(pane.activeItem.saveAs).toBeUndefined()
          pane.saveActiveItem()
          expect(atom.showSaveDialogSync).not.toHaveBeenCalled()

  describe "::saveActiveItemAs()", ->
    pane = null

    beforeEach ->
      pane = new Pane(items: [new Item("A")])
      spyOn(atom, 'showSaveDialogSync').andReturn('/selected/path')

    describe "when the current item has a saveAs method", ->
      it "opens the save dialog and calls saveAs on the item with the selected path", ->
        pane.activeItem.path = __filename
        pane.activeItem.saveAs = jasmine.createSpy("saveAs")
        pane.saveActiveItemAs()
        expect(atom.showSaveDialogSync).toHaveBeenCalledWith(__dirname)
        expect(pane.activeItem.saveAs).toHaveBeenCalledWith('/selected/path')

    describe "when the current item does not have a saveAs method", ->
      it "does nothing", ->
        expect(pane.activeItem.saveAs).toBeUndefined()
        pane.saveActiveItemAs()
        expect(atom.showSaveDialogSync).not.toHaveBeenCalled()

  describe "::itemForUri(uri)", ->
    it "returns the item for which a call to .getUri() returns the given uri", ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C"), new Item("D")])
      [item1, item2, item3] = pane.items
      item1.uri = "a"
      item2.uri = "b"
      expect(pane.itemForUri("a")).toBe item1
      expect(pane.itemForUri("b")).toBe item2
      expect(pane.itemForUri("bogus")).toBeUndefined()

  describe "::moveItem(item, index)", ->
    it "moves the item to the given index and emits an 'item-moved' event with the item and its new index", ->
      pane = new Pane(items: [new Item("A"), new Item("B"), new Item("C"), new Item("D")])
      [item1, item2, item3, item4] = pane.items
      pane.on 'item-moved', itemMovedHandler = jasmine.createSpy("itemMovedHandler")

      pane.moveItem(item1, 2)
      expect(pane.getItems()).toEqual [item2, item3, item1, item4]
      expect(itemMovedHandler).toHaveBeenCalledWith(item1, 2)
      itemMovedHandler.reset()

      pane.moveItem(item2, 3)
      expect(pane.getItems()).toEqual [item3, item1, item4, item2]
      expect(itemMovedHandler).toHaveBeenCalledWith(item2, 3)
      itemMovedHandler.reset()

      pane.moveItem(item2, 1)
      expect(pane.getItems()).toEqual [item3, item2, item1, item4]
      expect(itemMovedHandler).toHaveBeenCalledWith(item2, 1)

  describe "::moveItemToPane(item, pane, index)", ->
    [container, pane1, pane2] = []
    [item1, item2, item3, item4, item5] = []

    beforeEach ->
      pane1 = new Pane(items: [new Item("A"), new Item("B"), new Item("C")])
      container = new PaneContainer(root: pane1)
      pane2 = pane1.splitRight(items: [new Item("D"), new Item("E")])
      [item1, item2, item3] = pane1.items
      [item4, item5] = pane2.items

    it "moves the item to the given pane at the given index", ->
      pane1.moveItemToPane(item2, pane2, 1)
      expect(pane1.items).toEqual [item1, item3]
      expect(pane2.items).toEqual [item4, item2, item5]

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
      pane1 = new Pane(items: ["A"])
      container = new PaneContainer(root: pane1)

    describe "::splitLeft(params)", ->
      describe "when the parent is the container root", ->
        it "replaces itself with a row and inserts a new pane to the left of itself", ->
          pane2 = pane1.splitLeft(items: ["B"])
          pane3 = pane1.splitLeft(items: ["C"])
          expect(container.root.orientation).toBe 'horizontal'
          expect(container.root.children).toEqual [pane2, pane3, pane1]

      describe "when the parent is a column", ->
        it "replaces itself with a row and inserts a new pane to the left of itself", ->
          pane1.splitDown()
          pane2 = pane1.splitLeft(items: ["B"])
          pane3 = pane1.splitLeft(items: ["C"])
          row = container.root.children[0]
          expect(row.orientation).toBe 'horizontal'
          expect(row.children).toEqual [pane2, pane3, pane1]

    describe "::splitRight(params)", ->
      describe "when the parent is the container root", ->
        it "replaces itself with a row and inserts a new pane to the right of itself", ->
          pane2 = pane1.splitRight(items: ["B"])
          pane3 = pane1.splitRight(items: ["C"])
          expect(container.root.orientation).toBe 'horizontal'
          expect(container.root.children).toEqual [pane1, pane3, pane2]

      describe "when the parent is a column", ->
        it "replaces itself with a row and inserts a new pane to the right of itself", ->
          pane1.splitDown()
          pane2 = pane1.splitRight(items: ["B"])
          pane3 = pane1.splitRight(items: ["C"])
          row = container.root.children[0]
          expect(row.orientation).toBe 'horizontal'
          expect(row.children).toEqual [pane1, pane3, pane2]

    describe "::splitUp(params)", ->
      describe "when the parent is the container root", ->
        it "replaces itself with a column and inserts a new pane above itself", ->
          pane2 = pane1.splitUp(items: ["B"])
          pane3 = pane1.splitUp(items: ["C"])
          expect(container.root.orientation).toBe 'vertical'
          expect(container.root.children).toEqual [pane2, pane3, pane1]

      describe "when the parent is a row", ->
        it "replaces itself with a column and inserts a new pane above itself", ->
          pane1.splitRight()
          pane2 = pane1.splitUp(items: ["B"])
          pane3 = pane1.splitUp(items: ["C"])
          column = container.root.children[0]
          expect(column.orientation).toBe 'vertical'
          expect(column.children).toEqual [pane2, pane3, pane1]

    describe "::splitDown(params)", ->
      describe "when the parent is the container root", ->
        it "replaces itself with a column and inserts a new pane below itself", ->
          pane2 = pane1.splitDown(items: ["B"])
          pane3 = pane1.splitDown(items: ["C"])
          expect(container.root.orientation).toBe 'vertical'
          expect(container.root.children).toEqual [pane1, pane3, pane2]

      describe "when the parent is a row", ->
        it "replaces itself with a column and inserts a new pane below itself", ->
          pane1.splitRight()
          pane2 = pane1.splitDown(items: ["B"])
          pane3 = pane1.splitDown(items: ["C"])
          column = container.root.children[0]
          expect(column.orientation).toBe 'vertical'
          expect(column.children).toEqual [pane1, pane3, pane2]

    it "sets up the new pane to be focused", ->
      expect(pane1.focused).toBe false
      pane2 = pane1.splitRight()
      expect(pane2.focused).toBe true

  describe "::destroy()", ->
    [container, pane1, pane2] = []

    beforeEach ->
      container = new PaneContainer
      pane1 = container.root
      pane1.addItems([new Item("A"), new Item("B")])
      pane2 = pane1.splitRight()

    it "destroys the pane's destroyable items", ->
      [item1, item2] = pane1.items
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
      expect(newPane.items).toEqual pane.items

    it "restores the active item on deserialization", ->
      pane.activateItemAtIndex(1)
      newPane = pane.testSerialization()
      expect(newPane.activeItem).toEqual newPane.items[1]

    it "does not include items that cannot be deserialized", ->
      spyOn(console, 'warn')
      unserializable = {}
      pane.activateItem(unserializable)

      newPane = pane.testSerialization()
      expect(newPane.activeItem).toEqual pane.items[0]
      expect(newPane.items.length).toBe pane.items.length - 1

    it "includes the pane's focus state in the serialized state", ->
      pane.focus()
      newPane = pane.testSerialization()
      expect(newPane.focused).toBe true
