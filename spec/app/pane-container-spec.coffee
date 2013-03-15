PaneContainer = require 'pane-container'
Pane = require 'pane'
{View, $$} = require 'space-pen'
_ = require 'underscore'
$ = require 'jquery'

describe "PaneContainer", ->
  [TestView, container, pane1, pane2, pane3] = []

  beforeEach ->
    class TestView extends View
      registerDeserializer(this)
      @deserialize: ({name}) -> new TestView(name)
      @content: -> @div tabindex: -1
      initialize: (@name) -> @text(@name)
      serialize: -> { deserializer: 'TestView', @name }
      getUri: -> "/tmp/#{@name}"
      save: -> @saved = true
      isEqual: (other) -> @name is other.name

    container = new PaneContainer
    pane1 = new Pane(new TestView('1'))
    container.append(pane1)
    pane2 = pane1.splitRight(new TestView('2'))
    pane3 = pane2.splitDown(new TestView('3'))

  afterEach ->
    unregisterDeserializer(TestView)

  describe ".focusNextPane()", ->
    it "focuses the pane following the focused pane or the first pane if no pane has focus", ->
      container.attachToDom()
      container.focusNextPane()
      expect(pane1.activeItem).toMatchSelector ':focus'
      container.focusNextPane()
      expect(pane2.activeItem).toMatchSelector ':focus'
      container.focusNextPane()
      expect(pane3.activeItem).toMatchSelector ':focus'
      container.focusNextPane()
      expect(pane1.activeItem).toMatchSelector ':focus'

  describe ".getActivePane()", ->
    it "returns the most-recently focused pane", ->
      focusStealer = $$ -> @div tabindex: -1, "focus stealer"
      focusStealer.attachToDom()
      container.attachToDom()

      pane2.focus()
      expect(container.getFocusedPane()).toBe pane2
      expect(container.getActivePane()).toBe pane2

      focusStealer.focus()
      expect(container.getFocusedPane()).toBeUndefined()
      expect(container.getActivePane()).toBe pane2

      pane3.focus()
      expect(container.getFocusedPane()).toBe pane3
      expect(container.getActivePane()).toBe pane3

      # returns the first pane if none have been set to active
      container.find('.pane.active').removeClass('active')
      expect(container.getActivePane()).toBe pane1

  describe ".eachPane(callback)", ->
    it "runs the callback with all current and future panes until the subscription is cancelled", ->
      panes = []
      subscription = container.eachPane (pane) -> panes.push(pane)
      expect(panes).toEqual [pane1, pane2, pane3]

      panes = []
      pane4 = pane3.splitRight()
      expect(panes).toEqual [pane4]

      panes = []
      subscription.cancel()
      pane4.splitDown()
      expect(panes).toEqual []

  describe ".reopenItem()", ->
    describe "when there is an active pane", ->
      it "reconstructs and shows the last-closed pane item", ->
        expect(container.getActivePane()).toBe pane3
        item3 = pane3.activeItem
        item4 = new TestView('4')
        pane3.showItem(item4)

        pane3.destroyItem(item3)
        pane3.destroyItem(item4)
        expect(container.getActivePane()).toBe pane1

        expect(container.reopenItem()).toBeTruthy()
        expect(pane1.activeItem).toEqual item4

        expect(container.reopenItem()).toBeTruthy()
        expect(pane1.activeItem).toEqual item3

        expect(container.reopenItem()).toBeFalsy()
        expect(pane1.activeItem).toEqual item3

    describe "when there is no active pane", ->
      it "attaches a new pane with the reconstructed last pane item", ->
        pane1.remove()
        pane2.remove()
        item3 = pane3.activeItem
        pane3.destroyItem(item3)
        expect(container.getActivePane()).toBeUndefined()

        container.reopenItem()

        expect(container.getActivePane().activeItem).toEqual item3

    it "does not reopen an item that is already open", ->
      item3 = pane3.activeItem
      item4 = new TestView('4')
      pane3.showItem(item4)
      pane3.destroyItem(item3)
      pane3.destroyItem(item4)

      expect(container.getActivePane()).toBe pane1
      pane1.showItem(new TestView('4'))

      expect(container.reopenItem()).toBeTruthy()
      expect(_.pluck(pane1.getItems(), 'name')).toEqual ['1', '4', '3']
      expect(pane1.activeItem).toEqual item3

      expect(container.reopenItem()).toBeFalsy()
      expect(pane1.activeItem).toEqual item3

  describe ".saveAll()", ->
    it "saves all open pane items", ->
      pane1.showItem(new TestView('4'))

      container.saveAll()

      for pane in container.getPanes()
        for item in pane.getItems()
          expect(item.saved).toBeTruthy()

  describe ".confirmClose()", ->
    it "resolves the returned promise after modified files are saved", ->
      pane1.itemAtIndex(0).isModified = -> true
      pane2.itemAtIndex(0).isModified = -> true
      spyOn(atom, "confirm").andCallFake (a, b, c, d, e, f, g, noSaveFn) -> noSaveFn()

      promiseHandler = jasmine.createSpy("promiseHandler")
      failedPromiseHandler = jasmine.createSpy("failedPromiseHandler")
      promise = container.confirmClose()
      promise.done promiseHandler
      promise.fail failedPromiseHandler

      waitsFor ->
        promiseHandler.wasCalled

      runs ->
        expect(failedPromiseHandler).not.toHaveBeenCalled()
        expect(atom.confirm).toHaveBeenCalled()

    it "rejects the returned promise if the user cancels saving", ->
      pane1.itemAtIndex(0).isModified = -> true
      pane2.itemAtIndex(0).isModified = -> true
      spyOn(atom, "confirm").andCallFake (a, b, c, d, e, cancelFn, f, g) -> cancelFn()

      promiseHandler = jasmine.createSpy("promiseHandler")
      failedPromiseHandler = jasmine.createSpy("failedPromiseHandler")
      promise = container.confirmClose()
      promise.done promiseHandler
      promise.fail failedPromiseHandler

      waitsFor ->
        failedPromiseHandler.wasCalled

      runs ->
        expect(promiseHandler).not.toHaveBeenCalled()
        expect(atom.confirm).toHaveBeenCalled()

  describe "serialization", ->
    it "can be serialized and deserialized, and correctly adjusts dimensions of deserialized panes after attach", ->
      newContainer = deserialize(container.serialize())
      expect(newContainer.find('.row > :contains(1)')).toExist()
      expect(newContainer.find('.row > .column > :contains(2)')).toExist()
      expect(newContainer.find('.row > .column > :contains(3)')).toExist()

      newContainer.height(200).width(300).attachToDom()
      expect(newContainer.find('.row > :contains(1)').width()).toBe 150
      expect(newContainer.find('.row > .column > :contains(2)').height()).toBe 100

    it "removes empty panes on deserialization", ->
      # only deserialize pane 1's view successfully
      TestView.deserialize = ({name}) -> new TestView(name) if name is '1'
      newContainer = deserialize(container.serialize())
      expect(newContainer.find('.row, .column')).not.toExist()
      expect(newContainer.find('> :contains(1)')).toExist()
