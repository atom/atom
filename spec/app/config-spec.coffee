fsUtils = require 'fs-utils'

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

  describe ".save()", ->
    beforeEach ->
      spyOn(fsUtils, 'write')
      jasmine.unspy config, 'save'

    describe "when ~/.atom/config.json exists", ->
      it "writes any non-default properties to ~/.atom/config.json", ->
        config.configFilePath = fsUtils.join(config.configDirPath, "config.json")
        config.set("a.b.c", 1)
        config.set("a.b.d", 2)
        config.set("x.y.z", 3)
        config.setDefaults("a.b", e: 4, f: 5)

        fsUtils.write.reset()
        config.save()

        expect(fsUtils.write.argsForCall[0][0]).toBe(fsUtils.join(config.configDirPath, "config.json"))
        writtenConfig = JSON.parse(fsUtils.write.argsForCall[0][1])
        expect(writtenConfig).toEqual config.settings

    describe "when ~/.atom/config.json doesn't exist", ->
      it "writes any non-default properties to ~/.atom/config.cson", ->
        config.configFilePath = fsUtils.join(config.configDirPath, "config.cson")
        config.set("a.b.c", 1)
        config.set("a.b.d", 2)
        config.set("x.y.z", 3)
        config.setDefaults("a.b", e: 4, f: 5)

        fsUtils.write.reset()
        config.save()

        expect(fsUtils.write.argsForCall[0][0]).toBe(fsUtils.join(config.configDirPath, "config.cson"))
        CoffeeScript = require 'coffee-script'
        writtenConfig = CoffeeScript.eval(fsUtils.write.argsForCall[0][1], bare: true)
        expect(writtenConfig).toEqual config.settings

  describe ".setDefaults(keyPath, defaults)", ->
    it "assigns any previously-unassigned keys to the object at the key path", ->
      config.set("foo.bar.baz", a: 1)
      config.setDefaults("foo.bar.baz", a: 2, b: 3, c: 4)
      expect(config.get("foo.bar.baz.a")).toBe 1
      expect(config.get("foo.bar.baz.b")).toBe 3
      expect(config.get("foo.bar.baz.c")).toBe 4

      config.setDefaults("foo.quux", x: 0, y: 1)
      expect(config.get("foo.quux.x")).toBe 0
      expect(config.get("foo.quux.y")).toBe 1

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

  describe "initializeConfigDirectory()", ->
    beforeEach ->
      config.configDirPath = '/tmp/dot-atom-dir'
      expect(fsUtils.exists(config.configDirPath)).toBeFalsy()

    afterEach ->
      fsUtils.remove('/tmp/dot-atom-dir') if fsUtils.exists('/tmp/dot-atom-dir')

    describe "when the configDirPath doesn't exist", ->
      it "copies the contents of dot-atom to ~/.atom", ->
        initializationDone = false
        jasmine.unspy(window, "setTimeout")
        config.initializeConfigDirectory ->
          initializationDone = true

        waitsFor -> initializationDone

        runs ->
          expect(fsUtils.exists(config.configDirPath)).toBeTruthy()
          expect(fsUtils.exists(fsUtils.join(config.configDirPath, 'packages'))).toBeTruthy()
          expect(fsUtils.exists(fsUtils.join(config.configDirPath, 'snippets'))).toBeTruthy()
          expect(fsUtils.exists(fsUtils.join(config.configDirPath, 'themes'))).toBeTruthy()
          expect(fsUtils.isFile(fsUtils.join(config.configDirPath, 'config.cson'))).toBeTruthy()

      it "copies the bundles themes to ~/.atom", ->
        initializationDone = false
        jasmine.unspy(window, "setTimeout")
        config.initializeConfigDirectory ->
          initializationDone = true

        waitsFor -> initializationDone

        runs ->
          expect(fsUtils.isFile(fsUtils.join(config.configDirPath, 'themes/atom-dark-ui/package.cson'))).toBeTruthy()
          expect(fsUtils.isFile(fsUtils.join(config.configDirPath, 'themes/atom-light-ui/package.cson'))).toBeTruthy()
          expect(fsUtils.isFile(fsUtils.join(config.configDirPath, 'themes/atom-dark-syntax.css'))).toBeTruthy()
          expect(fsUtils.isFile(fsUtils.join(config.configDirPath, 'themes/atom-light-syntax.css'))).toBeTruthy()

  describe "when the config file is not parseable", ->
    beforeEach ->
     config.configDirPath = '/tmp/dot-atom-dir'
     config.configFilePath = fsUtils.join(config.configDirPath, "config.cson")
     expect(fsUtils.exists(config.configDirPath)).toBeFalsy()

    afterEach ->
      fsUtils.remove('/tmp/dot-atom-dir') if fsUtils.exists('/tmp/dot-atom-dir')

    it "logs an error to the console and does not overwrite the config file", ->
      config.save.reset()
      spyOn(console, 'error')
      fsUtils.write(config.configFilePath, "{{{{{")
      config.loadUserConfig()
      config.set("hair", "blonde") # trigger a save
      expect(console.error).toHaveBeenCalled()
      expect(config.save).not.toHaveBeenCalled()
