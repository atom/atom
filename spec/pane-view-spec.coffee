PaneContainerView = require '../src/pane-container-view'
PaneView = require '../src/pane-view'
{fs, $, View} = require 'atom'
path = require 'path'
temp = require 'temp'

describe "PaneView", ->
  [container, view1, view2, editor1, editor2, pane, paneModel] = []

  class TestView extends View
    @deserialize: ({id, text}) -> new TestView({id, text})
    @content: ({id, text}) -> @div class: 'test-view', id: id, tabindex: -1, text
    initialize: ({@id, @text}) ->
    serialize: -> { deserializer: 'TestView', @id, @text }
    getUri: -> @id
    isEqual: (other) -> other? and @id == other.id and @text == other.text

  beforeEach ->
    atom.deserializers.add(TestView)
    container = new PaneContainerView
    view1 = new TestView(id: 'view-1', text: 'View 1')
    view2 = new TestView(id: 'view-2', text: 'View 2')
    editor1 = atom.project.openSync('sample.js')
    editor2 = atom.project.openSync('sample.txt')
    pane = new PaneView(view1, editor1, view2, editor2)
    paneModel = pane.model
    container.setRoot(pane)

  afterEach ->
    atom.deserializers.remove(TestView)

  describe "when the active pane item changes", ->
    it "hides all item views except the one being shown and sets the activeItem", ->
      expect(pane.activeItem).toBe view1
      expect(view1.css('display')).not.toBe 'none'

      pane.activateItem(view2)
      expect(view1.css('display')).toBe 'none'
      expect(view2.css('display')).not.toBe 'none'

    it "triggers 'pane:active-item-changed'", ->
      itemChangedHandler = jasmine.createSpy("itemChangedHandler")
      container.on 'pane:active-item-changed', itemChangedHandler

      expect(pane.activeItem).toBe view1
      paneModel.activateItem(view2)
      paneModel.activateItem(view2)

      expect(itemChangedHandler.callCount).toBe 1
      expect(itemChangedHandler.argsForCall[0][1]).toBe view2
      itemChangedHandler.reset()

      paneModel.activateItem(editor1)
      expect(itemChangedHandler).toHaveBeenCalled()
      expect(itemChangedHandler.argsForCall[0][1]).toBe editor1
      itemChangedHandler.reset()

    it "transfers focus to the new active view if the previous view was focused", ->
      container.attachToDom()
      pane.focus()
      expect(pane.activeView).not.toBe view2
      expect(pane.activeView).toMatchSelector ':focus'
      paneModel.activateItem(view2)
      expect(view2).toMatchSelector ':focus'

    describe "when the new activeItem is a model", ->
      it "shows the item's view or creates and shows a new view for the item if none exists", ->
        initialViewCount = pane.itemViews.find('.test-view').length

        model1 =
          id: 'test-model-1'
          text: 'Test Model 1'
          serialize: -> {@id, @text}
          getViewClass: -> TestView

        model2 =
          id: 'test-model-2'
          text: 'Test Model 2'
          serialize: -> {@id, @text}
          getViewClass: -> TestView

        paneModel.activateItem(model1)
        paneModel.activateItem(model2)
        expect(pane.itemViews.find('.test-view').length).toBe initialViewCount + 2

        paneModel.activatePreviousItem()
        expect(pane.itemViews.find('.test-view').length).toBe initialViewCount + 2

        paneModel.destroyItem(model2)
        expect(pane.itemViews.find('.test-view').length).toBe initialViewCount + 1

        paneModel.destroyItem(model1)
        expect(pane.itemViews.find('.test-view').length).toBe initialViewCount

    describe "when the new activeItem is a view", ->
      it "appends it to the itemViews div if it hasn't already been appended and shows it", ->
        expect(pane.itemViews.find('#view-2')).not.toExist()
        paneModel.activateItem(view2)
        expect(pane.itemViews.find('#view-2')).toExist()
        paneModel.activateItem(view1)
        paneModel.activateItem(view2)
        expect(pane.itemViews.find('#view-2').length).toBe 1

  describe "when an item is destroyed", ->
    it "triggers the 'pane:item-removed' event with the item and its former index", ->
      itemRemovedHandler = jasmine.createSpy("itemRemovedHandler")
      pane.on 'pane:item-removed', itemRemovedHandler
      paneModel.destroyItem(editor1)
      expect(itemRemovedHandler).toHaveBeenCalled()
      expect(itemRemovedHandler.argsForCall[0][1..2]).toEqual [editor1, 1]

    describe "when the destroyed item is a view", ->
      it "removes the item from the 'item-views' div", ->
        expect(view1.parent()).toMatchSelector pane.itemViews
        paneModel.destroyItem(view1)
        expect(view1.parent()).not.toMatchSelector pane.itemViews

    describe "when the destroyed item is a model", ->
      it "removes the associated view", ->
        paneModel.activateItem(editor1)
        expect(pane.itemViews.find('.editor').length).toBe 1
        pane.destroyItem(editor1)
        expect(pane.itemViews.find('.editor').length).toBe 0

  describe "::moveItem(item, index)", ->
    it "moves the item to the given index and emits a 'pane:item-moved' event with the item and the new index", ->
      itemMovedHandler = jasmine.createSpy("itemMovedHandler")
      pane.on 'pane:item-moved', itemMovedHandler

      pane.moveItem(view1, 2)
      expect(pane.getItems()).toEqual [editor1, view2, view1, editor2]
      expect(itemMovedHandler).toHaveBeenCalled()
      expect(itemMovedHandler.argsForCall[0][1..2]).toEqual [view1, 2]
      itemMovedHandler.reset()

      pane.moveItem(editor1, 3)
      expect(pane.getItems()).toEqual [view2, view1, editor2, editor1]
      expect(itemMovedHandler).toHaveBeenCalled()
      expect(itemMovedHandler.argsForCall[0][1..2]).toEqual [editor1, 3]
      itemMovedHandler.reset()

      pane.moveItem(editor1, 1)
      expect(pane.getItems()).toEqual [view2, editor1, view1, editor2]
      expect(itemMovedHandler).toHaveBeenCalled()
      expect(itemMovedHandler.argsForCall[0][1..2]).toEqual [editor1, 1]
      itemMovedHandler.reset()

  describe "::moveItemToPane(item, pane, index)", ->
    [pane2, view3] = []

    beforeEach ->
      view3 = new TestView(id: 'view-3', text: "View 3")
      pane2 = pane.splitRight(view3)

    it "moves the item to the given pane at the given index", ->
      pane.moveItemToPane(view1, pane2, 1)
      expect(pane.getItems()).toEqual [editor1, view2, editor2]
      expect(pane2.getItems()).toEqual [view3, view1]

    describe "when it is the last item on the source pane", ->
      it "removes the source pane, but does not destroy the item", ->
        pane.destroyItem(view1)
        pane.destroyItem(view2)
        pane.destroyItem(editor2)

        expect(pane.getItems()).toEqual [editor1]
        pane.moveItemToPane(editor1, pane2, 1)

        expect(pane.hasParent()).toBeFalsy()
        expect(pane2.getItems()).toEqual [view3, editor1]
        expect(editor1.isDestroyed()).toBe false

    describe "when the item is a jQuery object", ->
      it "preserves data by detaching instead of removing", ->
        view1.data('preservative', 1234)
        pane.moveItemToPane(view1, pane2, 1)
        pane2.activateItemAtIndex(1)
        expect(pane2.activeView.data('preservative')).toBe 1234

  describe "pane:close", ->
    it "destroys all items and removes the pane", ->
      pane.activateItem(editor1)
      pane.trigger 'pane:close'
      expect(pane.hasParent()).toBeFalsy()
      expect(editor2.isDestroyed()).toBe true
      expect(editor1.isDestroyed()).toBe true

  describe "pane:close-other-items", ->
    it "destroys all items except the current", ->
      pane.activateItem(editor1)
      pane.trigger 'pane:close-other-items'
      expect(editor2.isDestroyed()).toBe true
      expect(pane.getItems()).toEqual [editor1]

  describe "::saveActiveItem()", ->
    describe "when the current item has a uri", ->
      describe "when the current item has a save method", ->
        it "saves the current item", ->
          spyOn(editor2, 'save')
          pane.activateItem(editor2)
          pane.saveActiveItem()
          expect(editor2.save).toHaveBeenCalled()

      describe "when the current item has no save method", ->
        it "does nothing", ->
          pane.activeItem.getUri = -> 'you are eye'
          expect(pane.activeItem.save).toBeUndefined()
          pane.saveActiveItem()

    describe "when the current item has no uri", ->
      beforeEach ->
        spyOn(atom, 'showSaveDialogSync').andReturn('/selected/path')

      describe "when the current item has a saveAs method", ->
        it "opens a save dialog and saves the current item as the selected path", ->
          newEditor = atom.project.openSync()
          spyOn(newEditor, 'saveAs')
          pane.activateItem(newEditor)

          pane.saveActiveItem()

          expect(atom.showSaveDialogSync).toHaveBeenCalled()
          expect(newEditor.saveAs).toHaveBeenCalledWith('/selected/path')

      describe "when the current item has no saveAs method", ->
        it "does nothing", ->
          expect(pane.activeItem.saveAs).toBeUndefined()
          pane.saveActiveItem()
          expect(atom.showSaveDialogSync).not.toHaveBeenCalled()

  describe "::saveActiveItemAs()", ->
    beforeEach ->
      spyOn(atom, 'showSaveDialogSync').andReturn('/selected/path')

    describe "when the current item has a saveAs method", ->
      it "opens the save dialog and calls saveAs on the item with the selected path", ->
        spyOn(editor2, 'saveAs')
        pane.activateItem(editor2)

        pane.saveActiveItemAs()

        expect(atom.showSaveDialogSync).toHaveBeenCalledWith(path.dirname(editor2.getPath()))
        expect(editor2.saveAs).toHaveBeenCalledWith('/selected/path')

    describe "when the current item does not have a saveAs method", ->
      it "does nothing", ->
        expect(pane.activeItem.saveAs).toBeUndefined()
        pane.saveActiveItemAs()
        expect(atom.showSaveDialogSync).not.toHaveBeenCalled()

  describe "pane:show-next-item and pane:show-previous-item", ->
    it "advances forward/backward through the pane's items, looping around at either end", ->
      expect(pane.activeItem).toBe view1
      pane.trigger 'pane:show-previous-item'
      expect(pane.activeItem).toBe editor2
      pane.trigger 'pane:show-previous-item'
      expect(pane.activeItem).toBe view2
      pane.trigger 'pane:show-next-item'
      expect(pane.activeItem).toBe editor2
      pane.trigger 'pane:show-next-item'
      expect(pane.activeItem).toBe view1

  describe "pane:show-item-N events", ->
    it "shows the (n-1)th item if it exists", ->
      pane.trigger 'pane:show-item-2'
      expect(pane.activeItem).toBe pane.itemAtIndex(1)
      pane.trigger 'pane:show-item-1'
      expect(pane.activeItem).toBe pane.itemAtIndex(0)
      pane.trigger 'pane:show-item-9' # don't fail on out-of-bounds indices
      expect(pane.activeItem).toBe pane.itemAtIndex(0)

  describe "when the title of the active item changes", ->
    it "emits pane:active-item-title-changed", ->
      activeItemTitleChangedHandler = jasmine.createSpy("activeItemTitleChangedHandler")
      pane.on 'pane:active-item-title-changed', activeItemTitleChangedHandler

      expect(pane.activeItem).toBe view1

      view2.trigger 'title-changed'
      expect(activeItemTitleChangedHandler).not.toHaveBeenCalled()

      view1.trigger 'title-changed'
      expect(activeItemTitleChangedHandler).toHaveBeenCalled()
      activeItemTitleChangedHandler.reset()

      pane.activateItem(view2)
      view2.trigger 'title-changed'
      expect(activeItemTitleChangedHandler).toHaveBeenCalled()

  describe "when an unmodifed buffer's path is deleted", ->
    it "removes the pane item", ->
      filePath = temp.openSync('atom').path
      editor = atom.project.openSync(filePath)
      pane.activateItem(editor)
      expect(pane.items).toHaveLength(5)

      fs.removeSync(filePath)
      waitsFor ->
        pane.items.length == 4

  describe "::remove()", ->
    it "destroys all the pane's items", ->
      pane.remove()
      expect(editor1.isDestroyed()).toBe true
      expect(editor2.isDestroyed()).toBe true

    it "triggers a 'pane:removed' event with the pane", ->
      removedHandler = jasmine.createSpy("removedHandler")
      container.on 'pane:removed', removedHandler
      pane.remove()
      expect(removedHandler).toHaveBeenCalled()
      expect(removedHandler.argsForCall[0][1]).toBe pane

    describe "when there are other panes", ->
      [paneToLeft, paneToRight] = []

      beforeEach ->
        pane.activateItem(editor1)
        paneToLeft = pane.splitLeft(pane.copyActiveItem())
        paneToRight = pane.splitRight(pane.copyActiveItem())
        container.attachToDom()

      describe "when the removed pane is active", ->
        it "makes the next the next pane active and focuses it", ->
          pane.activate()
          pane.remove()
          expect(paneToLeft.isActive()).toBeFalsy()
          expect(paneToRight.isActive()).toBeTruthy()
          expect(paneToRight).toMatchSelector ':has(:focus)'

      describe "when the removed pane is not active", ->
        it "does not affect the active pane or the focus", ->
          paneToLeft.focus()
          expect(paneToLeft.isActive()).toBeTruthy()
          expect(paneToRight.isActive()).toBeFalsy()

          pane.remove()
          expect(paneToLeft.isActive()).toBeTruthy()
          expect(paneToRight.isActive()).toBeFalsy()
          expect(paneToLeft).toMatchSelector ':has(:focus)'

    describe "when it is the last pane", ->
      beforeEach ->
        expect(container.getPanes().length).toBe 1
        atom.workspaceView = focus: jasmine.createSpy("workspaceView.focus")

      describe "when the removed pane is focused", ->
        it "calls focus on workspaceView so we don't lose focus", ->
          container.attachToDom()
          pane.focus()
          pane.remove()
          expect(atom.workspaceView.focus).toHaveBeenCalled()

      describe "when the removed pane is not focused", ->
        it "does not call focus on root view", ->
          expect(pane).not.toMatchSelector ':has(:focus)'
          pane.remove()
          expect(atom.workspaceView.focus).not.toHaveBeenCalled()

  describe "::getNextPane()", ->
    it "returns the next pane if one exists, wrapping around from the last pane to the first", ->
      pane.activateItem(editor1)
      expect(pane.getNextPane()).toBeUndefined
      pane2 = pane.splitRight(pane.copyActiveItem())
      expect(pane.getNextPane()).toBe pane2
      expect(pane2.getNextPane()).toBe pane

  describe "when the pane is focused", ->
    beforeEach ->
      container.attachToDom()

    it "focuses the active item view", ->
      focusHandler = jasmine.createSpy("focusHandler")
      pane.activeItem.on 'focus', focusHandler
      pane.focus()
      expect(focusHandler).toHaveBeenCalled()

    it "triggers 'pane:became-active' if it was not previously active", ->
      pane2 = pane.splitRight(view2) # Make pane inactive

      becameActiveHandler = jasmine.createSpy("becameActiveHandler")
      pane.on 'pane:became-active', becameActiveHandler
      expect(pane.isActive()).toBeFalsy()
      pane.focusin()
      expect(pane.isActive()).toBeTruthy()
      pane.focusin()

      expect(becameActiveHandler.callCount).toBe 1

    it "triggers 'pane:became-inactive' when it was previously active", ->
      pane2 = pane.splitRight(view2) # Make pane inactive

      becameInactiveHandler = jasmine.createSpy("becameInactiveHandler")
      pane.on 'pane:became-inactive', becameInactiveHandler

      expect(pane.isActive()).toBeFalsy()
      pane.focusin()
      expect(pane.isActive()).toBeTruthy()
      pane.splitRight(pane.copyActiveItem())
      expect(pane.isActive()).toBeFalsy()

      expect(becameInactiveHandler.callCount).toBe 1

  describe "split methods", ->
    [pane1, view3, view4] = []
    beforeEach ->
      pane1 = pane
      pane.activateItem(editor1)
      view3 = new TestView(id: 'view-3', text: 'View 3')
      view4 = new TestView(id: 'view-4', text: 'View 4')

    describe "splitRight(items...)", ->
      it "builds a row if needed, then appends a new pane after itself", ->
        # creates the new pane with a copy of the active item if none are given
        pane2 = pane1.splitRight(pane1.copyActiveItem())
        expect(container.find('.pane-row .pane').toArray()).toEqual [pane1[0], pane2[0]]
        expect(pane2.items).toEqual [editor1]
        expect(pane2.activeItem).not.toBe editor1 # it's a copy

        pane3 = pane2.splitRight(view3, view4)
        expect(pane3.getItems()).toEqual [view3, view4]
        expect(container.find('.pane-row .pane').toArray()).toEqual [pane[0], pane2[0], pane3[0]]

      it "builds a row if needed, then appends a new pane after itself ", ->
        # creates the new pane with a copy of the active item if none are given
        pane2 = pane1.splitRight()
        expect(container.find('.pane-row .pane').toArray()).toEqual [pane1[0], pane2[0]]
        expect(pane2.items).toEqual []
        expect(pane2.activeItem).toBeUndefined()

        pane3 = pane2.splitRight()
        expect(container.find('.pane-row .pane').toArray()).toEqual [pane1[0], pane2[0], pane3[0]]
        expect(pane3.items).toEqual []
        expect(pane3.activeItem).toBeUndefined()

    describe "splitLeft(items...)", ->
      it "builds a row if needed, then appends a new pane before itself", ->
        # creates the new pane with a copy of the active item if none are given
        pane2 = pane.splitLeft(pane1.copyActiveItem())
        expect(container.find('.pane-row .pane').toArray()).toEqual [pane2[0], pane[0]]
        expect(pane2.items).toEqual [editor1]
        expect(pane2.activeItem).not.toBe editor1 # it's a copy

        pane3 = pane2.splitLeft(view3, view4)
        expect(pane3.getItems()).toEqual [view3, view4]
        expect(container.find('.pane-row .pane').toArray()).toEqual [pane3[0], pane2[0], pane[0]]

    describe "splitDown(items...)", ->
      it "builds a column if needed, then appends a new pane after itself", ->
        # creates the new pane with a copy of the active item if none are given
        pane2 = pane.splitDown(pane1.copyActiveItem())
        expect(container.find('.pane-column .pane').toArray()).toEqual [pane[0], pane2[0]]
        expect(pane2.items).toEqual [editor1]
        expect(pane2.activeItem).not.toBe editor1 # it's a copy

        pane3 = pane2.splitDown(view3, view4)
        expect(pane3.getItems()).toEqual [view3, view4]
        expect(container.find('.pane-column .pane').toArray()).toEqual [pane[0], pane2[0], pane3[0]]

    describe "splitUp(items...)", ->
      it "builds a column if needed, then appends a new pane before itself", ->
        # creates the new pane with a copy of the active item if none are given
        pane2 = pane.splitUp(pane1.copyActiveItem())
        expect(container.find('.pane-column .pane').toArray()).toEqual [pane2[0], pane[0]]
        expect(pane2.items).toEqual [editor1]
        expect(pane2.activeItem).not.toBe editor1 # it's a copy

        pane3 = pane2.splitUp(view3, view4)
        expect(pane3.getItems()).toEqual [view3, view4]
        expect(container.find('.pane-column .pane').toArray()).toEqual [pane3[0], pane2[0], pane[0]]

  describe "::itemForUri(uri)", ->
    it "returns the item for which a call to .getUri() returns the given uri", ->
      expect(pane.itemForUri(editor1.getUri())).toBe editor1
      expect(pane.itemForUri(editor2.getUri())).toBe editor2

  describe "serialization", ->
    it "can serialize and deserialize the pane and all its items", ->
      newPane = new PaneView(pane.model.testSerialization())
      expect(newPane.getItems()).toEqual [view1, editor1, view2, editor2]

    it "restores the active item on deserialization", ->
      pane.activateItem(editor2)
      newPane = new PaneView(pane.model.testSerialization())
      expect(newPane.activeItem).toEqual editor2

    it "does not show items that cannot be deserialized", ->
      spyOn(console, 'warn')

      class Unserializable
        getViewClass: -> TestView

      pane.activateItem(new Unserializable)

      newPane = new PaneView(pane.model.testSerialization())
      expect(newPane.activeItem).toEqual pane.items[0]
      expect(newPane.items.length).toBe pane.items.length - 1

    it "focuses the pane after attach only if had focus when serialized", ->
      container.attachToDom()
      pane.focus()

      container2 = new PaneContainerView(container.model.testSerialization())
      pane2 = container2.getRoot()
      container2.attachToDom()
      expect(pane2).toMatchSelector(':has(:focus)')

      $(document.activeElement).blur()
      container3 = new PaneContainerView(container.model.testSerialization())
      pane3 = container3.getRoot()
      container3.attachToDom()
      expect(pane3).not.toMatchSelector(':has(:focus)')
