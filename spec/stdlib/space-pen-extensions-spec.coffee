{View, $$} = require 'space-pen'

describe "SpacePen extensions", ->
  class TestView extends View
    @content: -> @div()

  [view, parent, observeHandler] = []

  beforeEach ->
    view = new TestView
    parent = $$ -> @div()
    parent.append(view)
    observeHandler = jasmine.createSpy("observeHandler")
    view.observeConfig "foo.bar", observeHandler
    expect(view.hasParent()).toBeTruthy()

  describe "View#observeConfig(keyPath, callback)", ->
    it "observes the keyPath and destroys the subscription when unsubscribe is called", ->
      expect(observeHandler).toHaveBeenCalledWith(undefined)
      observeHandler.reset()

      config.foo = { bar: "hello" }
      config.update()

      expect(observeHandler).toHaveBeenCalledWith("hello")
      observeHandler.reset()

      view.unsubscribe()

      config.foo.bar = "goodbye"
      config.update()

      expect(observeHandler).not.toHaveBeenCalled()

    it "unsubscribes on remove", ->
      observeHandler.reset()
      view.remove()
      expect(view.hasParent()).toBeFalsy()
      config.foo = { bar: "hello" }
      config.update()
      expect(observeHandler).not.toHaveBeenCalled()
