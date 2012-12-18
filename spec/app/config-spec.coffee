describe "Config", ->
  describe ".get(keyPath) and .set(keyPath, value)", ->
    it "allows a key path's value to be read and written", ->
      expect(config.set("foo.bar.baz", 42)).toBe 42
      expect(config.get("foo.bar.baz")).toBe 42
      expect(config.get("bogus.key.path")).toBeUndefined()

    it "updates observers and saves when a key path is set", ->
      observeHandler = jasmine.createSpy "observeHandler"
      config.observe "foo.bar.baz", observeHandler
      observeHandler.reset()

      config.set("foo.bar.baz", 42)

      expect(config.save).toHaveBeenCalled()
      expect(observeHandler).toHaveBeenCalledWith 42

  describe ".update()", ->
    it "updates observers if a value is mutated without the use of .set()", ->
      config.set("foo.bar.baz", ["a"])
      observeHandler = jasmine.createSpy "observeHandler"
      config.observe "foo.bar.baz", observeHandler
      observeHandler.reset()

      config.get("foo.bar.baz").push("b")
      config.update()
      expect(observeHandler).toHaveBeenCalledWith config.get("foo.bar.baz")

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
      config.set('foo.bar.baz', "value 2")
      expect(observeHandler).toHaveBeenCalledWith("value 2")
      observeHandler.reset()

      config.set('foo.bar.baz', "value 1")
      expect(observeHandler).toHaveBeenCalledWith("value 1")

    it "fires the callback when the full key path goes into and out of existence", ->
      observeHandler.reset() # clear the initial call
      config.set("foo.bar", undefined)

      expect(observeHandler).toHaveBeenCalledWith(undefined)
      observeHandler.reset()

      config.set("foo.bar.baz", "i'm back")
      expect(observeHandler).toHaveBeenCalledWith("i'm back")
