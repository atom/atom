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

  describe "when an item is moved within the same pane", ->
    it "emits a 'pane:item-moved' event with the item and the new index", ->
      pane.on 'pane:item-moved', itemMovedHandler = jasmine.createSpy("itemMovedHandler")
      paneModel.moveItem(view1, 2)
      expect(itemMovedHandler).toHaveBeenCalled()
      expect(itemMovedHandler.argsForCall[0][1..2]).toEqual [view1, 2]

  describe "when an item is moved to another pane", ->
    it "detaches the item's view rather than removing it", ->
      paneModel2 = paneModel.splitRight()
      view1.data('preservative', 1234)
      paneModel.moveItemToPane(view1, paneModel2, 1)
      expect(view1.data('preservative')).toBe 1234
      paneModel2.activateItemAtIndex(1)
      expect(view1.data('preservative')).toBe 1234

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

  describe "when a pane is destroyed", ->
    it "triggers a 'pane:removed' event with the pane", ->
      removedHandler = jasmine.createSpy("removedHandler")
      container.on 'pane:removed', removedHandler
      pane.remove()
      expect(removedHandler).toHaveBeenCalled()
      expect(removedHandler.argsForCall[0][1]).toBe pane

    describe "if the destroyed pane has focus", ->
      [paneToLeft, paneToRight] = []

      describe "if it is not the last pane in the container", ->
        it "focuses the next pane", ->
          paneModel.activateItem(editor1)
          pane2Model = paneModel.splitRight(items: [paneModel.copyActiveItem()])
          pane2 = pane2Model._view
          container.attachToDom()
          expect(pane.hasFocus()).toBe false
          pane2Model.destroy()
          expect(pane.hasFocus()).toBe true

      describe "if it is the last pane in the container", ->
        it "shifts focus to the workspace view", ->
          atom.workspaceView = {focus: jasmine.createSpy("atom.workspaceView.focus")}
          container.attachToDom()
          pane.focus()
          expect(container.hasFocus()).toBe true
          paneModel.destroy()
          expect(atom.workspaceView.focus).toHaveBeenCalled()

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
