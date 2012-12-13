describe "Config", ->
  describe "#observe(keyPath)", ->
    observeHandler = null

    beforeEach ->
      observeHandler = jasmine.createSpy("observeHandler")
      config.foo = { bar: { baz: "value 1" } }
      config.observe "foo.bar.baz", observeHandler

    it "fires the given callback with the current value at the keypath", ->
      expect(observeHandler).toHaveBeenCalledWith("value 1")

    it "fires the callback every time the observed value changes", ->
      observeHandler.reset() # clear the initial call
      config.foo.bar.baz = "value 2"
      config.update()
      expect(observeHandler).toHaveBeenCalledWith("value 2")
      observeHandler.reset()

      config.foo.bar.baz = "value 1"
      config.update()
      expect(observeHandler).toHaveBeenCalledWith("value 1")

    it "fires the callback when the full key path goes into and out of existence", ->
      observeHandler.reset() # clear the initial call
      delete config.foo.bar
      config.update()

      expect(observeHandler).toHaveBeenCalledWith(undefined)
      observeHandler.reset()

      config.foo.bar = { baz: "i'm back" }
      config.update()
      expect(observeHandler).toHaveBeenCalledWith("i'm back")
