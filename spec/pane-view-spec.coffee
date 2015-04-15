PaneContainer = require '../src/pane-container'
PaneView = require '../src/pane-view'
fs = require 'fs-plus'
{Emitter, Disposable} = require 'event-kit'
{$, View} = require '../src/space-pen-extensions'
path = require 'path'
temp = require 'temp'

describe "PaneView", ->
  [container, containerModel, view1, view2, editor1, editor2, pane, paneModel, deserializerDisposable] = []

  class TestView extends View
    @deserialize: ({id, text}) -> new TestView({id, text})
    @content: ({id, text}) -> @div class: 'test-view', id: id, tabindex: -1, text
    initialize: ({@id, @text}) ->
      @emitter = new Emitter
    serialize: -> {deserializer: 'TestView', @id, @text}
    getURI: -> @id
    isEqual: (other) -> other? and @id is other.id and @text is other.text
    changeTitle: ->
      @emitter.emit 'did-change-title', 'title'
    onDidChangeTitle: (callback) ->
      @emitter.on 'did-change-title', callback
    onDidChangeModified: -> new Disposable(->)

  beforeEach ->
    jasmine.snapshotDeprecations()

    deserializerDisposable = atom.deserializers.add(TestView)
    container = atom.views.getView(new PaneContainer).__spacePenView
    containerModel = container.model
    view1 = new TestView(id: 'view-1', text: 'View 1')
    view2 = new TestView(id: 'view-2', text: 'View 2')
    waitsForPromise ->
      atom.workspace.open('sample.js').then (o) -> editor1 = o

    waitsForPromise ->
      atom.workspace.open('sample.txt').then (o) -> editor2 = o

    runs ->
      pane = container.getRoot()
      paneModel = pane.getModel()
      paneModel.addItems([view1, editor1, view2, editor2])

  afterEach ->
    deserializerDisposable.dispose()
    jasmine.restoreDeprecationsSnapshot()

  describe "when the active pane item changes", ->
    it "hides all item views except the active one", ->
      expect(pane.getActiveItem()).toBe view1
      expect(view1.css('display')).not.toBe 'none'

      pane.activateItem(view2)
      expect(view1.css('display')).toBe 'none'
      expect(view2.css('display')).not.toBe 'none'

    it "triggers 'pane:active-item-changed'", ->
      itemChangedHandler = jasmine.createSpy("itemChangedHandler")
      container.on 'pane:active-item-changed', itemChangedHandler

      expect(pane.getActiveItem()).toBe view1
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
        expect(pane.itemViews.find('atom-text-editor').length).toBe 1
        pane.destroyItem(editor1)
        expect(pane.itemViews.find('atom-text-editor').length).toBe 0

  describe "when an item is moved within the same pane", ->
    it "emits a 'pane:item-moved' event with the item and the new index", ->
      pane.on 'pane:item-moved', itemMovedHandler = jasmine.createSpy("itemMovedHandler")
      paneModel.moveItem(view1, 2)
      expect(itemMovedHandler).toHaveBeenCalled()
      expect(itemMovedHandler.argsForCall[0][1..2]).toEqual [view1, 2]

  describe "when an item is moved to another pane", ->
    it "detaches the item's view rather than removing it", ->
      container.attachToDom()
      expect(view1.is(':visible')).toBe true
      paneModel2 = paneModel.splitRight()
      view1.data('preservative', 1234)
      paneModel.moveItemToPane(view1, paneModel2, 1)
      expect(view1.data('preservative')).toBe 1234
      paneModel2.activateItemAtIndex(1)
      expect(view1.data('preservative')).toBe 1234
      expect(view1.is(':visible')).toBe true

  describe "when the title of the active item changes", ->
    describe 'when there is no onDidChangeTitle method (deprecated)', ->
      beforeEach ->
        jasmine.snapshotDeprecations()

        view1.onDidChangeTitle = null
        view2.onDidChangeTitle = null

        pane.activateItem(view2)
        pane.activateItem(view1)

      afterEach ->
        jasmine.restoreDeprecationsSnapshot()

      it "emits pane:active-item-title-changed", ->
        activeItemTitleChangedHandler = jasmine.createSpy("activeItemTitleChangedHandler")
        pane.on 'pane:active-item-title-changed', activeItemTitleChangedHandler

        expect(pane.getActiveItem()).toBe view1

        view2.trigger 'title-changed'
        expect(activeItemTitleChangedHandler).not.toHaveBeenCalled()

        view1.trigger 'title-changed'
        expect(activeItemTitleChangedHandler).toHaveBeenCalled()
        activeItemTitleChangedHandler.reset()

        pane.activateItem(view2)
        view2.trigger 'title-changed'
        expect(activeItemTitleChangedHandler).toHaveBeenCalled()

    describe 'when there is a onDidChangeTitle method', ->
      it "emits pane:active-item-title-changed", ->
        activeItemTitleChangedHandler = jasmine.createSpy("activeItemTitleChangedHandler")
        pane.on 'pane:active-item-title-changed', activeItemTitleChangedHandler

        expect(pane.getActiveItem()).toBe view1
        view2.changeTitle()
        expect(activeItemTitleChangedHandler).not.toHaveBeenCalled()

        view1.changeTitle()
        expect(activeItemTitleChangedHandler).toHaveBeenCalled()
        activeItemTitleChangedHandler.reset()

        pane.activateItem(view2)
        view2.changeTitle()
        expect(activeItemTitleChangedHandler).toHaveBeenCalled()

  describe "when an unmodifed buffer's path is deleted", ->
    it "removes the pane item", ->
      editor = null
      jasmine.unspy(window, 'setTimeout')
      filePath = path.join(temp.mkdirSync(), 'file.txt')
      fs.writeFileSync(filePath, '')

      waitsForPromise ->
        atom.workspace.open(filePath).then (o) -> editor = o

      runs ->
        pane.activateItem(editor)
        expect(pane.items).toHaveLength(5)
        fs.removeSync(filePath)

      waitsFor ->
        pane.items.length is 4

  describe "when a pane is destroyed", ->
    [pane2, pane2Model] = []

    beforeEach ->
      pane2Model = paneModel.splitRight() # Can't destroy the last pane, so we add another
      pane2 = atom.views.getView(pane2Model).__spacePenView

    it "triggers a 'pane:removed' event with the pane", ->
      removedHandler = jasmine.createSpy("removedHandler")
      container.on 'pane:removed', removedHandler
      paneModel.destroy()
      expect(removedHandler).toHaveBeenCalled()
      expect(removedHandler.argsForCall[0][1]).toBe pane

    describe "if the destroyed pane has focus", ->
      [paneToLeft, paneToRight] = []

      it "focuses the next pane", ->
        container.attachToDom()
        pane2.activate()
        expect(pane.hasFocus()).toBe false
        expect(pane2.hasFocus()).toBe true
        pane2Model.destroy()
        expect(pane.hasFocus()).toBe true

  describe "::getNextPane()", ->
    it "returns the next pane if one exists, wrapping around from the last pane to the first", ->
      pane.activateItem(editor1)
      expect(pane.getNextPane()).toBeUndefined
      pane2 = pane.splitRight(pane.copyActiveItem())
      expect(pane.getNextPane()).toBe pane2
      expect(pane2.getNextPane()).toBe pane

  describe "when the pane's active status changes", ->
    [pane2, pane2Model] = []

    beforeEach ->
      pane2Model = paneModel.splitRight(items: [pane.copyActiveItem()])
      pane2 = atom.views.getView(pane2Model).__spacePenView
      expect(pane2Model.isActive()).toBe true

    it "adds or removes the .active class as appropriate", ->
      expect(pane).not.toHaveClass('active')
      paneModel.activate()
      expect(pane).toHaveClass('active')
      pane2Model.activate()
      expect(pane).not.toHaveClass('active')

    it "triggers 'pane:became-active' or 'pane:became-inactive' according to the current status", ->
      pane.on 'pane:became-active', becameActiveHandler = jasmine.createSpy("becameActiveHandler")
      pane.on 'pane:became-inactive', becameInactiveHandler = jasmine.createSpy("becameInactiveHandler")
      paneModel.activate()

      expect(becameActiveHandler.callCount).toBe 1
      expect(becameInactiveHandler.callCount).toBe 0

      pane2Model.activate()
      expect(becameActiveHandler.callCount).toBe 1
      expect(becameInactiveHandler.callCount).toBe 1

  describe "when the pane is focused", ->
    beforeEach ->
      container.attachToDom()

    it "transfers focus to the active view", ->
      focusHandler = jasmine.createSpy("focusHandler")
      pane.getActiveItem().on 'focus', focusHandler
      pane.focus()
      expect(focusHandler).toHaveBeenCalled()

    it "makes the pane active", ->
      paneModel.splitRight(items: [pane.copyActiveItem()])
      expect(paneModel.isActive()).toBe false
      pane.focus()
      expect(paneModel.isActive()).toBe true

  describe "when a pane is split", ->
    it "builds the appropriateatom-pane-axis.horizontal and pane-column views", ->
      pane1 = pane
      pane1Model = pane.getModel()
      pane.activateItem(editor1)

      pane2Model = pane1Model.splitRight(items: [pane1Model.copyActiveItem()])
      pane3Model = pane2Model.splitDown(items: [pane2Model.copyActiveItem()])
      pane2 = pane2Model._view
      pane2 = atom.views.getView(pane2Model).__spacePenView
      pane3 = atom.views.getView(pane3Model).__spacePenView

      expect(container.find('> atom-pane-axis.horizontal > atom-pane').toArray()).toEqual [pane1[0]]
      expect(container.find('> atom-pane-axis.horizontal > atom-pane-axis.vertical > atom-pane').toArray()).toEqual [pane2[0], pane3[0]]

      pane1Model.destroy()
      expect(container.find('> atom-pane-axis.vertical > atom-pane').toArray()).toEqual [pane2[0], pane3[0]]

  describe "serialization", ->
    it "focuses the pane after attach only if had focus when serialized", ->
      container.attachToDom()
      pane.focus()

      container2 = atom.views.getView(container.model.testSerialization()).__spacePenView
      pane2 = container2.getRoot()
      container2.attachToDom()
      expect(pane2).toMatchSelector(':has(:focus)')

      $(document.activeElement).blur()
      container3 = atom.views.getView(container.model.testSerialization()).__spacePenView
      pane3 = container3.getRoot()
      container3.attachToDom()
      expect(pane3).not.toMatchSelector(':has(:focus)')
