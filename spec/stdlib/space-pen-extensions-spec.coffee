{View, $$} = require 'space-pen'
EventEmitter = require 'event-emitter'

describe "SpacePen extensions", ->
  class TestView extends View
    @content: -> @div()

  [view, parent] = []

  beforeEach ->
    view = new TestView
    parent = $$ -> @div()
    parent.append(view)

  describe "View#observeConfig(keyPath, callback)", ->
    observeHandler = null

    beforeEach ->
      observeHandler = jasmine.createSpy("observeHandler")
      view.observeConfig "foo.bar", observeHandler
      expect(view.hasParent()).toBeTruthy()

    it "observes the keyPath and destroys the subscription when unsubscribe is called", ->
      expect(observeHandler).toHaveBeenCalledWith(undefined)
      observeHandler.reset()

      config.update("foo.bar", "hello")

      expect(observeHandler).toHaveBeenCalledWith("hello")
      observeHandler.reset()

      view.unsubscribe()

      config.update("foo.bar", "goodbye")

      expect(observeHandler).not.toHaveBeenCalled()

    it "unsubscribes when the view is removed", ->
      observeHandler.reset()
      parent.remove()
      config.update("foo.bar", "hello")
      expect(observeHandler).not.toHaveBeenCalled()

  describe "View#subscribe(eventEmitter, eventName, callback)", ->
    [emitter, eventHandler] = []

    beforeEach ->
      eventHandler = jasmine.createSpy 'eventHandler'
      emitter = $$ -> @div()
      view.subscribe emitter, 'foo', eventHandler

    it "subscribes to the given event emitter and unsubscribes when unsubscribe is called", ->
      emitter.trigger "foo"
      expect(eventHandler).toHaveBeenCalled()
