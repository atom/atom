describe "Config", ->
  describe ".update(keyPath, value)", ->
    it "sets the value at the given key path and emits an update event", ->
      updateHandler = jasmine.createSpy 'updateHandler'
      config.on 'update', updateHandler
      config.update("foo.bar.baz", "hello")
      expect(config.foo.bar.baz).toBe "hello"
      expect(updateHandler).toHaveBeenCalled()

  describe ".observe(keyPath)", ->
    observeHandler = null

    beforeEach ->
      observeHandler = jasmine.createSpy("observeHandler")
      config.foo = { bar: { baz: "value 1" } }
      config.observe "foo.bar.baz", observeHandler

    it "fires the given callback with the current value at the keypath", ->
      expect(observeHandler).toHaveBeenCalledWith("value 1")

    it "fires the callback every time the observed value changes", ->
      observeHandler.reset() # clear the initial call
      config.update('foo.bar.baz', "value 2")
      expect(observeHandler).toHaveBeenCalledWith("value 2")
      observeHandler.reset()

      config.update('foo.bar.baz', "value 1")
      expect(observeHandler).toHaveBeenCalledWith("value 1")

    it "fires the callback when the full key path goes into and out of existence", ->
      observeHandler.reset() # clear the initial call
      config.update("foo.bar", undefined)

      expect(observeHandler).toHaveBeenCalledWith(undefined)
      observeHandler.reset()

      config.update("foo.bar.baz", "i'm back")
      expect(observeHandler).toHaveBeenCalledWith("i'm back")
