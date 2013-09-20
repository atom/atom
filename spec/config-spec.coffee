{fs} = require 'atom'
path = require 'path'
CSON = require 'season'

describe "Config", ->
  describe ".get(keyPath)", ->
    it "allows a key path's value to be read", ->
      expect(config.set("foo.bar.baz", 42)).toBe 42
      expect(config.get("foo.bar.baz")).toBe 42
      expect(config.get("bogus.key.path")).toBeUndefined()

    it "returns a deep clone of the key path's value", ->
      config.set('value', array: [1, b: 2, 3])
      retrievedValue = config.get('value')
      retrievedValue.array[0] = 4
      retrievedValue.array[1].b = 2.1
      expect(config.get('value')).toEqual(array: [1, b: 2, 3])

  describe ".set(keyPath, value)", ->
    it "allows a key path's value to be written", ->
      expect(config.set("foo.bar.baz", 42)).toBe 42
      expect(config.get("foo.bar.baz")).toBe 42

    it "updates observers and saves when a key path is set", ->
      observeHandler = jasmine.createSpy "observeHandler"
      config.observe "foo.bar.baz", observeHandler
      observeHandler.reset()

      config.set("foo.bar.baz", 42)

      expect(config.save).toHaveBeenCalled()
      expect(observeHandler).toHaveBeenCalledWith 42

    describe "when the value equals the default value", ->
      it "does not store the value", ->
        config.setDefaults("foo", same: 1, changes: 1)
        expect(config.settings.foo).toBeUndefined()
        config.set('foo.same', 1)
        config.set('foo.changes', 2)
        expect(config.settings.foo).toEqual {changes: 2}

        config.set('foo.changes', 1)
        expect(config.settings.foo).toEqual {}

  describe ".pushAtKeyPath(keyPath, value)", ->
    it "pushes the given value to the array at the key path and updates observers", ->
      config.set("foo.bar.baz", ["a"])
      observeHandler = jasmine.createSpy "observeHandler"
      config.observe "foo.bar.baz", observeHandler
      observeHandler.reset()

      expect(config.pushAtKeyPath("foo.bar.baz", "b")).toBe 2
      expect(config.get("foo.bar.baz")).toEqual ["a", "b"]
      expect(observeHandler).toHaveBeenCalledWith config.get("foo.bar.baz")

  describe ".removeAtKeyPath(keyPath, value)", ->
    it "removes the given value from the array at the key path and updates observers", ->
      config.set("foo.bar.baz", ["a", "b", "c"])
      observeHandler = jasmine.createSpy "observeHandler"
      config.observe "foo.bar.baz", observeHandler
      observeHandler.reset()

      expect(config.removeAtKeyPath("foo.bar.baz", "b")).toEqual ["a", "c"]
      expect(config.get("foo.bar.baz")).toEqual ["a", "c"]
      expect(observeHandler).toHaveBeenCalledWith config.get("foo.bar.baz")

  describe ".getPositiveInt(keyPath, defaultValue)", ->
    it "returns the proper current or default value", ->
      config.set('editor.preferredLineLength', 0)
      expect(config.getPositiveInt('editor.preferredLineLength', 80)).toBe 80
      config.set('editor.preferredLineLength', -1234)
      expect(config.getPositiveInt('editor.preferredLineLength', 80)).toBe 80
      config.set('editor.preferredLineLength', 'abcd')
      expect(config.getPositiveInt('editor.preferredLineLength', 80)).toBe 80
      config.set('editor.preferredLineLength', null)
      expect(config.getPositiveInt('editor.preferredLineLength', 80)).toBe 80

  describe ".save()", ->
    nodeFs = require 'fs'

    beforeEach ->
      spyOn(nodeFs, 'writeFileSync')
      jasmine.unspy config, 'save'

    describe "when ~/.atom/config.json exists", ->
      it "writes any non-default properties to ~/.atom/config.json", ->
        config.configFilePath = path.join(config.configDirPath, "config.json")
        config.set("a.b.c", 1)
        config.set("a.b.d", 2)
        config.set("x.y.z", 3)
        config.setDefaults("a.b", e: 4, f: 5)

        nodeFs.writeFileSync.reset()
        config.save()

        expect(nodeFs.writeFileSync.argsForCall[0][0]).toBe(path.join(config.configDirPath, "config.json"))
        writtenConfig = JSON.parse(nodeFs.writeFileSync.argsForCall[0][1])
        expect(writtenConfig).toEqual config.settings

    describe "when ~/.atom/config.json doesn't exist", ->
      it "writes any non-default properties to ~/.atom/config.cson", ->
        config.configFilePath = path.join(config.configDirPath, "config.cson")
        config.set("a.b.c", 1)
        config.set("a.b.d", 2)
        config.set("x.y.z", 3)
        config.setDefaults("a.b", e: 4, f: 5)

        nodeFs.writeFileSync.reset()
        config.save()

        expect(nodeFs.writeFileSync.argsForCall[0][0]).toBe(path.join(config.configDirPath, "config.cson"))
        CoffeeScript = require 'coffee-script'
        writtenConfig = CoffeeScript.eval(nodeFs.writeFileSync.argsForCall[0][1], bare: true)
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

    it "fires the callback when the observed value is deleted", ->
      observeHandler.reset() # clear the initial call
      config.set('foo.bar.baz', undefined)
      expect(observeHandler).toHaveBeenCalledWith(undefined)

    it "fires the callback when the full key path goes into and out of existence", ->
      observeHandler.reset() # clear the initial call
      config.set("foo.bar", undefined)

      expect(observeHandler).toHaveBeenCalledWith(undefined)
      observeHandler.reset()

      config.set("foo.bar.baz", "i'm back")
      expect(observeHandler).toHaveBeenCalledWith("i'm back")

  describe ".initializeConfigDirectory()", ->
    beforeEach ->
      config.configDirPath = '/tmp/dot-atom-dir'
      expect(fs.exists(config.configDirPath)).toBeFalsy()

    afterEach ->
      fs.remove('/tmp/dot-atom-dir') if fs.exists('/tmp/dot-atom-dir')

    describe "when the configDirPath doesn't exist", ->
      it "copies the contents of dot-atom to ~/.atom", ->
        initializationDone = false
        jasmine.unspy(window, "setTimeout")
        config.initializeConfigDirectory ->
          initializationDone = true

        waitsFor -> initializationDone

        runs ->
          expect(fs.exists(config.configDirPath)).toBeTruthy()
          expect(fs.exists(path.join(config.configDirPath, 'packages'))).toBeTruthy()
          expect(fs.exists(path.join(config.configDirPath, 'snippets'))).toBeTruthy()
          expect(fs.exists(path.join(config.configDirPath, 'themes'))).toBeTruthy()
          expect(fs.isFileSync(path.join(config.configDirPath, 'config.cson'))).toBeTruthy()

  describe ".loadUserConfig()", ->
    beforeEach ->
      config.configDirPath = '/tmp/dot-atom-dir'
      config.configFilePath = path.join(config.configDirPath, "config.cson")
      expect(fs.exists(config.configDirPath)).toBeFalsy()

    afterEach ->
      fs.remove('/tmp/dot-atom-dir') if fs.exists('/tmp/dot-atom-dir')

    describe "when the config file contains valid cson", ->
      beforeEach ->
        fs.writeSync(config.configFilePath, "foo: bar: 'baz'")
        config.loadUserConfig()

      it "updates the config data based on the file contents", ->
        expect(config.get("foo.bar")).toBe 'baz'

    describe "when the config file contains invalid cson", ->
      beforeEach ->
        spyOn(console, 'error')
        fs.writeSync(config.configFilePath, "{{{{{")

      it "logs an error to the console and does not overwrite the config file on a subsequent save", ->
        config.loadUserConfig()
        expect(console.error).toHaveBeenCalled()
        config.set("hair", "blonde") # trigger a save
        expect(config.save).not.toHaveBeenCalled()

    describe "when the config file does not exist", ->
      it "creates it with an empty object", ->
        fs.makeTree(config.configDirPath)
        config.loadUserConfig()
        expect(fs.exists(config.configFilePath)).toBe true
        expect(CSON.readFileSync(config.configFilePath)).toEqual {}

  describe ".observeUserConfig()", ->
    updatedHandler = null

    beforeEach ->
      config.configDirPath = '/tmp/dot-atom-dir'
      config.configFilePath = path.join(config.configDirPath, "config.cson")
      expect(fs.exists(config.configDirPath)).toBeFalsy()
      fs.writeSync(config.configFilePath, "foo: bar: 'baz'")
      config.loadUserConfig()
      config.observeUserConfig()
      updatedHandler = jasmine.createSpy("updatedHandler")
      config.on 'updated', updatedHandler

    afterEach ->
      config.unobserveUserConfig()
      fs.remove('/tmp/dot-atom-dir') if fs.exists('/tmp/dot-atom-dir')

    describe "when the config file changes to contain valid cson", ->
      it "updates the config data", ->
        fs.writeSync(config.configFilePath, "foo: { bar: 'quux', baz: 'bar'}")
        waitsFor 'update event', -> updatedHandler.callCount > 0
        runs ->
          expect(config.get('foo.bar')).toBe 'quux'
          expect(config.get('foo.baz')).toBe 'bar'

    describe "when the config file changes to contain invalid cson", ->
      beforeEach ->
        spyOn(console, 'error')
        fs.writeSync(config.configFilePath, "}}}")
        waitsFor "error to be logged", -> console.error.callCount > 0

      it "logs a warning and does not update config data", ->
        expect(updatedHandler.callCount).toBe 0
        expect(config.get('foo.bar')).toBe 'baz'
        config.set("hair", "blonde") # trigger a save
        expect(config.save).not.toHaveBeenCalled()

      describe "when the config file subsequently changes again to contain valid cson", ->
        beforeEach ->
          fs.writeSync(config.configFilePath, "foo: bar: 'baz'")
          waitsFor 'update event', -> updatedHandler.callCount > 0

        it "updates the config data and resumes saving", ->
          config.set("hair", "blonde")
          expect(config.save).toHaveBeenCalled()
