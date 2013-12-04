{Model} = require 'telepath'
Pane = require '../src/pane'
PaneContainer = require '../src/pane-container'
Focusable = require '../src/focusable'

describe "Pane", ->
  [Item, container, pane, item1, item2, item3] = []

  beforeEach ->
    class Item extends Model
      Focusable.includeInto(this)
      created: -> @manageFocus()

    container = PaneContainer.createAsRoot()
    pane = container.root
    item1 = new Item
    item2 = new Item
    item3 = new Item
    pane.addItems([item1, item2, item3])

  describe "construction", ->
    it "assigns the given items and sets the first item as the active item", ->
      expect(pane.items).toEqual [item1, item2, item3]
      expect(pane.activeItem).toBe item1

    it "does not assign an active item if no items are provided", ->
      pane = Pane.createAsRoot()
      expect(pane.items).toEqual []
      expect(pane.activeItem).toBeUndefined()

  describe "::activateItem(item)", ->
    it "changes the active item", ->
      expect(pane.activeItem).toBe item1
      pane.activateItem(item3)
      expect(pane.activeItem).toBe item3

    describe "if the item isn't present in the items list", ->
      it "adds it after the current active item", ->
        pane.activateItem(item2)
        item4 = pane.activateItem(new Item)
        expect(pane.activeItem).toBe item4
        expect(pane.items).toEqual [item1, item2, item4, item3]

    describe "if the new active item does not implement .setFocused ", ->
      it "focuses the pane if it was focused before activating the new item", ->
        item4 = new Item
        item5 = new Item
        item4.setFocused = undefined
        item5.setFocused = undefined

        expect(pane.hasFocus).toBe false
        pane.activateItem(item4)
        expect(pane.hasFocus).toBe false

        item6 = pane.activateItem(new Item)
        pane.setFocused(true)
        expect(item6.hasFocus).toBe true

        pane.activateItem(item5)
        expect(pane.hasFocus).toBe true
        expect(item5.hasFocus).toBe false

    describe "if the new active item implements .setFocused", ->
      it "focuses the item after making it active", ->
        expect(pane.hasFocus).toBe false
        item4 = pane.activateItem(new Item)
        expect(item4.hasFocus).toBe false

        pane.focused = true
        item5 = pane.activateItem(new Item)
        expect(item5.hasFocus).toBe true
        expect(pane.hasFocus).toBe true

  describe "::addItem(item)", ->
    describe "when the pane has no items", ->
      it "adds the item and makes it the active item", ->
        pane.removeItems()
        item4 = pane.addItem(new Item)
        expect(pane.items).toEqual [item4]
        expect(pane.activeItem).toBe item4

    describe "when the pane has items", ->
      it "adds the item after the active item", ->
        item4 = pane.addItem(new Item)
        expect(pane.activeItem).toBe pane.items.getFirst()
        expect(pane.items).toEqual [item1, item4, item2, item3]

  describe "::removeItem(item)", ->
    it "removes the specified item", ->
      expect(pane.activeItem).toBe item1
      pane.removeItem(item2)
      expect(pane.items).toEqual [item1, item3]
      expect(pane.activeItem).toBe item1

    describe "when the removed item is active", ->
      describe "when the removed item is the last item", ->
        it "sets the previous item as the new active item", ->
          pane.activateItem(item3)
          pane.removeItem(item3)
          expect(pane.activeItem).toBe item2

      describe "when the removed item is not the last item", ->
        it "sets the next item as the new active item", ->
          pane.activateItem(item2)
          pane.removeItem(item2)
          expect(pane.activeItem).toBe item3

      describe "when the removed item is the only item", ->
        it "sets the active item to undefined", ->
          pane.removeItem(item1)
          pane.removeItem(item2)
          pane.removeItem(item3)
          expect(pane.activeItem).toBeUndefined()

  describe "::moveItem(item, index)", ->
    it "moves the item to the given index", ->
      pane.moveItem(item1, 3)
      expect(pane.items).toEqual [item2, item3, item1]
      pane.moveItem(item2, 2)
      expect(pane.items).toEqual [item3, item2, item1]

  describe "::activateNextItem()", ->
    it "activates the next item, wrapping from the end to the beginning", ->
      expect(pane.activeItem).toBe item1
      expect(pane.activeItem.hasFocus).toBe false

      pane.activateNextItem()
      expect(pane.activeItem).toBe item2
      expect(pane.activeItem.hasFocus).toBe false

      pane.focused = true
      pane.activateNextItem()
      expect(pane.activeItem).toBe item3
      expect(pane.activeItem.hasFocus).toBe true

      pane.activateNextItem()
      expect(pane.activeItem).toBe item1
      expect(pane.activeItem.hasFocus).toBe true

  describe "::activatePreviousItem()", ->
    it "activates the previous item, wrapping from the beginning to the end", ->
      expect(pane.activeItem).toBe item1
      expect(pane.activeItem.hasFocus).toBe false

      pane.activatePreviousItem()
      expect(pane.activeItem).toBe item3
      expect(pane.activeItem.hasFocus).toBe false

      pane.focused = true
      pane.activatePreviousItem()
      expect(pane.activeItem).toBe item2
      expect(pane.activeItem.hasFocus).toBe true

      pane.activatePreviousItem()
      expect(pane.activeItem).toBe item1
      expect(pane.activeItem.hasFocus).toBe true

  describe "split methods", ->
    pane1 = null

    beforeEach ->
      pane1 = pane

    describe "::splitLeft(params)", ->
      it "inserts a new pane to the left, introducing a horizontal pane axis as a shared parent if needed", ->
        pane2 = pane1.splitLeft()
        expect(container.root.orientation).toBe 'horizontal'
        expect(container.root.children).toEqual [pane2, pane1]
        pane3 = pane1.splitLeft()
        expect(container.root.children).toEqual [pane2, pane3, pane1]

    describe "::splitRight(params)", ->
      it "inserts a new pane to the right, introducing a horizontal pane axis as a shared parent if needed", ->
        pane2 = pane1.splitRight()
        expect(container.root.orientation).toBe 'horizontal'
        expect(container.root.children).toEqual [pane1, pane2]
        pane3 = pane1.splitRight()
        expect(container.root.children).toEqual [pane1, pane3, pane2]

    describe "::splitUp(params)", ->
      it "inserts a new pane to the right, introducing a horizontal pane axis as a shared parent if needed", ->
        pane2 = pane1.splitUp()
        expect(container.root.orientation).toBe 'vertical'
        expect(container.root.children).toEqual [pane2 ,pane1]
        pane3 = pane1.splitUp()
        expect(container.root.children).toEqual [pane2, pane3, pane1]

    describe "::splitDown(params)", ->
      it "inserts a new pane to the right, introducing a horizontal pane axis as a shared parent if needed", ->
        pane2 = pane1.splitDown()
        expect(container.root.orientation).toBe 'vertical'
        expect(container.root.children).toEqual [pane1, pane2]
        pane3 = pane1.splitDown()
        expect(container.root.children).toEqual [pane1, pane3, pane2]

    describe "if called with items", ->
      it "creates the new pane with the given items", ->
        pane2 = pane1.splitRight(items: [{title: "Item 4"}, {title: "Item 5"}])
        expect(pane2.items).toEqual [{title: "Item 4"}, {title: "Item 5"}]

    describe "if called with copyActiveItem: true", ->
      describe "if the active item implements .copy", ->
        it "copies the active item to the new pane", ->
          Item.property 'title'
          Item::copy = -> @clone()
          item4 = new Item(title: "Alpha")
          pane1.activateItem(item4)
          pane2 = pane1.splitRight(copyActiveItem: true)

          expect(pane1.items).toEqual [item1, item4, item2, item3]
          expect(pane2.items).toEqual [item4]
          expect(pane2.items.getFirst()).not.toBe item4

      describe "if the active item does not implement .copy", ->
        it "moves the active item to the new pane", ->
          pane2 = pane1.splitRight(copyActiveItem: true)
          expect(pane1.items).toEqual [item2, item3]
          expect(pane2.items).toEqual [item1]

    it "focuses the new pane if the original pane has focus", ->
      expect(pane1.hasFocus).toBe false
      pane2 = pane1.splitLeft()
      expect(pane2.hasFocus).toBe false
      pane2.focused = true
      pane3 = pane2.splitLeft()
      expect(pane3.hasFocus).toBe true

  describe "::remove()", ->
    describe "if the pane is the root of its container", ->
      it "removes all pane items but does not remove the pane", ->
        expect(container.root).toBe pane
        expect(pane.items.isEmpty()).toBe false
        pane.remove()
        expect(container.root).toBe pane
        expect(pane.items.isEmpty()).toBe true

    describe "if the pane's parent has more than two children", ->
      it "removes the pane", ->
        pane1 = pane
        pane2 = pane1.splitRight()
        pane3 = pane2.splitRight()

        pane2.remove()
        expect(container.root.children).toEqual [pane1, pane3]

    describe "if the pane's parent has two children", ->
      it "removes the pane and replaces its parent with its sibling", ->
        pane1 = pane
        pane2 = pane1.splitRight()
        pane3 = pane2.splitDown()

        pane3.remove()
        expect(container.root.children).toEqual [pane1, pane2]
        pane2.remove()
        expect(container.root).toBe pane1

  describe "when a pane is focused", ->
    [pane1, pane2] = []

    beforeEach ->
      pane1 = pane
      item4 = new Item
      pane2 = pane1.splitRight(items: [item4])

    it "focuses the active item if it is focusable", ->
      expect(pane1.hasFocus).toBe false
      expect(pane1.activeItem.hasFocus).toBe false

      pane1.focused = true
      expect(pane1.hasFocus).toBe true
      expect(pane1.activeItem.hasFocus).toBe true

      pane2.focused = true
      expect(pane1.hasFocus).toBe false
      expect(pane2.hasFocus).toBe true
      expect(pane2.activeItem.hasFocus).toBe true

    it "retains focus for itself if the active item isn't focusable", ->
      pane1.removeItems()
      pane1.focused = true
      expect(pane1.hasFocus).toBe true

    it "sets the activePane to itself on its container", ->
      expect(container.activePane).toBe pane1
      pane2.focused = true
      expect(container.activePane).toBe pane2
      pane1.focused = true
      expect(container.activePane).toBe pane1

  describe "when a pane's active item becomes focused", ->
    it "sets itself as the the active pane on the pane container", ->
      pane1 = pane
      item4 = new Item
      pane2 = pane1.splitRight(items: [item4])

      expect(container.activePane).toBe pane1
      pane2.activeItem.focused = true
      expect(container.activePane).toBe pane2

  describe "::itemForUri(uri)", ->
    it "returns the first pane item with a matching uri property if one exists", ->
      item1.set('uri', '/foo/bar')
      item3.set('uri', '/baz/quux')

      expect(pane.itemForUri('/foo/bar')).toBe item1
      expect(pane.itemForUri('/baz/quux')).toBe item3
      expect(pane.itemForUri('/bogus')).toBeUndefined()

  describe "::saveItem(item, nextAction)", ->
    describe "if the item has a uri", ->
      it "calls save on the item and runs the next action", ->
        item1.uri = "/test"
        item1.save = jasmine.createSpy("item1.save")
        nextAction = jasmine.createSpy("nextAction").andCallFake -> expect(item1.save.callCount).toBe 1
        pane.saveItem(item1, nextAction)
        expect(nextAction.callCount).toBe 1

    describe "if the item does not have a uri", ->
      it "calls ::saveItemAs with the item and the next action", ->
        spyOn(pane, 'saveItemAs')
        expect(item1.getUri).toBeUndefined()
        expect(item1.uri).toBeUndefined()
        pane.saveItem(item1, nextAction = ->)
        expect(pane.saveItemAs).toHaveBeenCalledWith(item1, nextAction)

  describe "::saveItemAs(item, nextAction)", ->
    describe "if the item implements .saveAs", ->
      it "prompts for a path, then calls .saveAs with it and runs the next action", ->
        item1.saveAs = jasmine.createSpy("item1.saveAs")
        item1.path = "/foo/bar/baz.txt"
        spyOn(atom, 'showSaveDialogSync').andReturn "/test"
        nextAction = jasmine.createSpy("nextAction").andCallFake ->
          expect(item1.saveAs).toHaveBeenCalledWith("/test")
        pane.saveItemAs(item1, nextAction)
        expect(atom.showSaveDialogSync).toHaveBeenCalledWith("/foo/bar")
        expect(nextAction.callCount).toBe 1

    describe "if the item does not implement .saveAs", ->
      it "returns immediately without prompting, saving, or running the next action", ->
        expect(item1.saveAs).toBeUndefined()
        spyOn(atom, 'showSaveDialogSync')
        pane.saveItemAs(item1, nextAction = jasmine.createSpy("nextAction"))
        expect(atom.showSaveDialogSync).not.toHaveBeenCalled()
        expect(nextAction).not.toHaveBeenCalled()

  describe "::promptToSaveItem(item)", ->
    confirmChoice = null

    beforeEach ->
      item1.uri = "/test"
      spyOn(atom, 'confirm').andCallFake ({buttons}) -> buttons.indexOf(confirmChoice)
      spyOn(pane, 'saveItem').andCallFake (item, nextAction) -> nextAction()

    describe "if the item implements .shouldPromptToSave()", ->
      describe "if item.shouldPromptToSave() is true", ->
        beforeEach ->
          item1.shouldPromptToSave = -> true

        describe "if the user chooses to save the item", ->
          it "saves the item and returns true", ->
            confirmChoice = "Save"
            expect(pane.promptToSaveItem(item1)).toBe true
            expect(pane.saveItem.callCount).toBe 1
            expect(pane.saveItem.argsForCall[0][0]).toBe item1

        describe "if the user chooses not to save the item", ->
          it "does not save the item and returns true", ->
            confirmChoice = "Don't Save"
            expect(pane.promptToSaveItem(item1)).toBe true
            expect(pane.saveItem).not.toHaveBeenCalled()

        describe "if the user cancels", ->
          it "does not save the item and returns false", ->
            confirmChoice = "Cancel"
            expect(pane.promptToSaveItem(item1)).toBe false
            expect(pane.saveItem).not.toHaveBeenCalled()

      describe "if item.shouldPromptToSave() is false", ->
        it "does not prompt or save the item and returns true", ->
          item1.shouldPromptToSave = -> false
          expect(pane.promptToSaveItem(item1)).toBe true
          expect(atom.confirm).not.toHaveBeenCalled()
          expect(pane.saveItem).not.toHaveBeenCalled()

    describe "if the item does not implement .shouldPromptToSave()", ->
      it "does not prompt or save the item and returns true", ->
        expect(item1.shouldPromptToSave).toBeUndefined()
        expect(pane.promptToSaveItem(item1)).toBe true
        expect(atom.confirm).not.toHaveBeenCalled()
        expect(pane.saveItem).not.toHaveBeenCalled()

  describe "::promptToSaveItems()", ->
    it "prompts to save every item, returning true if the user cancels any prompting", ->
      cancelledItem = null
      spyOn(pane, 'promptToSaveItem').andCallFake (item) -> item isnt cancelledItem
      expect(pane.promptToSaveItems()).toBe true
      cancelledItem = item2
      expect(pane.promptToSaveItems()).toBe false
