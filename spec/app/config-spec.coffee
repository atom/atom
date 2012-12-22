describe "Config", ->
  describe ".get([scopeSelector], keyPath) and .set([scopeDescriptor], keyPath, value)", ->
    describe "when called without a scope argument", ->
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

    describe "when called with a scope argument", ->
      it "returns the config value for the most specific scope selector that matches the given scope descriptor", ->
        expect(config.set(".source.coffee .string.quoted.double.coffee", "foo.bar.baz", 42)).toBe 42
        config.set(".source .string.quoted.double", "foo.bar.baz", 22)
        config.set(".source", "foo.bar.baz", 11)
        config.set("foo.bar.baz", 1)

        expect(config.get([".source.coffee", ".string.quoted.double.coffee"], "foo.bar.baz")).toBe 42
        expect(config.get([".source.js", ".string.quoted.double.js"], "foo.bar.baz")).toBe 22
        expect(config.get([".source.js", ".variable.assignment.js"], "foo.bar.baz")).toBe 11
        expect(config.get([".text"], "foo.bar.baz")).toBe 1

  describe ".setDefaults(keyPath, defaults)", ->
    it "assigns any previously-unassigned keys to the object at the key path", ->
      config.set("foo.bar.baz", a: 1)
      config.setDefaults("foo.bar.baz", a: 2, b: 3, c: 4)
      expect(config.get("foo.bar.baz")).toEqual(a: 1, b: 3, c: 4)

      config.setDefaults("foo.quux", x: 0, y: 1)
      expect(config.get("foo.quux")).toEqual(x: 0, y: 1)

  describe ".update()", ->
    it "updates observers if a value is mutated without the use of .set", ->
      config.set("foo.bar.baz", ["a"])
      observeHandler = jasmine.createSpy "observeHandler"
      config.observe "foo.bar.baz", observeHandler
      observeHandler.reset()

      config.get("foo.bar.baz").push("b")
      config.update()
      expect(observeHandler).toHaveBeenCalledWith config.get("foo.bar.baz")
      observeHandler.reset()

      config.update()
      expect(observeHandler).not.toHaveBeenCalled()

  describe ".observe(keyPath)", ->
    observeHandler = null

    beforeEach ->
      observeHandler = jasmine.createSpy("observeHandler")
      config.set("foo.bar.baz", "value 1")
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
