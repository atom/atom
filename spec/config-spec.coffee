path = require 'path'
temp = require 'temp'
CSON = require 'season'
fs = require 'fs-plus'

describe "Config", ->
  dotAtomPath = path.join(temp.dir, 'dot-atom-dir')

  describe ".get(keyPath)", ->
    it "allows a key path's value to be read", ->
      expect(atom.config.set("foo.bar.baz", 42)).toBe 42
      expect(atom.config.get("foo.bar.baz")).toBe 42
      expect(atom.config.get("bogus.key.path")).toBeUndefined()

    it "returns a deep clone of the key path's value", ->
      atom.config.set('value', array: [1, b: 2, 3])
      retrievedValue = atom.config.get('value')
      retrievedValue.array[0] = 4
      retrievedValue.array[1].b = 2.1
      expect(atom.config.get('value')).toEqual(array: [1, b: 2, 3])

  describe ".set(keyPath, value)", ->
    it "allows a key path's value to be written", ->
      expect(atom.config.set("foo.bar.baz", 42)).toBe 42
      expect(atom.config.get("foo.bar.baz")).toBe 42

    it "updates observers and saves when a key path is set", ->
      observeHandler = jasmine.createSpy "observeHandler"
      atom.config.observe "foo.bar.baz", observeHandler
      observeHandler.reset()

      atom.config.set("foo.bar.baz", 42)

      expect(atom.config.save).toHaveBeenCalled()
      expect(observeHandler).toHaveBeenCalledWith 42, {previous: undefined}

    describe "when the value equals the default value", ->
      it "does not store the value", ->
        atom.config.setDefaults("foo", same: 1, changes: 1)
        expect(atom.config.settings.foo).toBeUndefined()
        atom.config.set('foo.same', 1)
        atom.config.set('foo.changes', 2)
        expect(atom.config.settings.foo).toEqual {changes: 2}

        atom.config.set('foo.changes', 1)
        expect(atom.config.settings.foo).toEqual {}

  describe ".toggle(keyPath)", ->
    it "negates the boolean value of the current key path value", ->
      atom.config.set('foo.a', 1)
      atom.config.toggle('foo.a')
      expect(atom.config.get('foo.a')).toBe false

      atom.config.set('foo.a', '')
      atom.config.toggle('foo.a')
      expect(atom.config.get('foo.a')).toBe true

      atom.config.set('foo.a', null)
      atom.config.toggle('foo.a')
      expect(atom.config.get('foo.a')).toBe true

      atom.config.set('foo.a', true)
      atom.config.toggle('foo.a')
      expect(atom.config.get('foo.a')).toBe false

  describe ".restoreDefault(keyPath)", ->
    it "sets the value of the key path to its default", ->
      atom.config.setDefaults('a', b: 3)
      atom.config.set('a.b', 4)
      expect(atom.config.get('a.b')).toBe 4
      atom.config.restoreDefault('a.b')
      expect(atom.config.get('a.b')).toBe 3

      atom.config.set('a.c', 5)
      expect(atom.config.get('a.c')).toBe 5
      atom.config.restoreDefault('a.c')
      expect(atom.config.get('a.c')).toBeUndefined()

  describe ".pushAtKeyPath(keyPath, value)", ->
    it "pushes the given value to the array at the key path and updates observers", ->
      atom.config.set("foo.bar.baz", ["a"])
      observeHandler = jasmine.createSpy "observeHandler"
      atom.config.observe "foo.bar.baz", observeHandler
      observeHandler.reset()

      expect(atom.config.pushAtKeyPath("foo.bar.baz", "b")).toBe 2
      expect(atom.config.get("foo.bar.baz")).toEqual ["a", "b"]
      expect(observeHandler).toHaveBeenCalledWith atom.config.get("foo.bar.baz"), {previous: ['a']}

  describe ".unshiftAtKeyPath(keyPath, value)", ->
    it "unshifts the given value to the array at the key path and updates observers", ->
      atom.config.set("foo.bar.baz", ["b"])
      observeHandler = jasmine.createSpy "observeHandler"
      atom.config.observe "foo.bar.baz", observeHandler
      observeHandler.reset()

      expect(atom.config.unshiftAtKeyPath("foo.bar.baz", "a")).toBe 2
      expect(atom.config.get("foo.bar.baz")).toEqual ["a", "b"]
      expect(observeHandler).toHaveBeenCalledWith atom.config.get("foo.bar.baz"), {previous: ['b']}

  describe ".removeAtKeyPath(keyPath, value)", ->
    it "removes the given value from the array at the key path and updates observers", ->
      atom.config.set("foo.bar.baz", ["a", "b", "c"])
      observeHandler = jasmine.createSpy "observeHandler"
      atom.config.observe "foo.bar.baz", observeHandler
      observeHandler.reset()

      expect(atom.config.removeAtKeyPath("foo.bar.baz", "b")).toEqual ["a", "c"]
      expect(atom.config.get("foo.bar.baz")).toEqual ["a", "c"]
      expect(observeHandler).toHaveBeenCalledWith atom.config.get("foo.bar.baz"), {previous: ['a', 'b', 'c']}

  describe ".getPositiveInt(keyPath, defaultValue)", ->
    it "returns the proper current or default value", ->
      atom.config.set('editor.preferredLineLength', 0)
      expect(atom.config.getPositiveInt('editor.preferredLineLength', 80)).toBe 80
      atom.config.set('editor.preferredLineLength', -1234)
      expect(atom.config.getPositiveInt('editor.preferredLineLength', 80)).toBe 80
      atom.config.set('editor.preferredLineLength', 'abcd')
      expect(atom.config.getPositiveInt('editor.preferredLineLength', 80)).toBe 80
      atom.config.set('editor.preferredLineLength', null)
      expect(atom.config.getPositiveInt('editor.preferredLineLength', 80)).toBe 80

  describe ".save()", ->
    CSON = require 'season'

    beforeEach ->
      spyOn(CSON, 'writeFileSync')
      jasmine.unspy atom.config, 'save'

    describe "when ~/.atom/config.json exists", ->
      it "writes any non-default properties to ~/.atom/config.json", ->
        atom.config.configFilePath = path.join(atom.config.configDirPath, "atom.config.json")
        atom.config.set("a.b.c", 1)
        atom.config.set("a.b.d", 2)
        atom.config.set("x.y.z", 3)
        atom.config.setDefaults("a.b", e: 4, f: 5)

        CSON.writeFileSync.reset()
        atom.config.save()

        expect(CSON.writeFileSync.argsForCall[0][0]).toBe(path.join(atom.config.configDirPath, "atom.config.json"))
        writtenConfig = CSON.writeFileSync.argsForCall[0][1]
        expect(writtenConfig).toBe atom.config.settings

    describe "when ~/.atom/config.json doesn't exist", ->
      it "writes any non-default properties to ~/.atom/config.cson", ->
        atom.config.configFilePath = path.join(atom.config.configDirPath, "atom.config.cson")
        atom.config.set("a.b.c", 1)
        atom.config.set("a.b.d", 2)
        atom.config.set("x.y.z", 3)
        atom.config.setDefaults("a.b", e: 4, f: 5)

        CSON.writeFileSync.reset()
        atom.config.save()

        expect(CSON.writeFileSync.argsForCall[0][0]).toBe(path.join(atom.config.configDirPath, "atom.config.cson"))
        CoffeeScript = require 'coffee-script'
        writtenConfig = CSON.writeFileSync.argsForCall[0][1]
        expect(writtenConfig).toEqual atom.config.settings

  describe ".setDefaults(keyPath, defaults)", ->
    it "assigns any previously-unassigned keys to the object at the key path", ->
      atom.config.set("foo.bar.baz", a: 1)
      atom.config.setDefaults("foo.bar.baz", a: 2, b: 3, c: 4)
      expect(atom.config.get("foo.bar.baz.a")).toBe 1
      expect(atom.config.get("foo.bar.baz.b")).toBe 3
      expect(atom.config.get("foo.bar.baz.c")).toBe 4

      atom.config.setDefaults("foo.quux", x: 0, y: 1)
      expect(atom.config.get("foo.quux.x")).toBe 0
      expect(atom.config.get("foo.quux.y")).toBe 1

  describe ".observe(keyPath)", ->
    [observeHandler, observeSubscription] = []

    beforeEach ->
      observeHandler = jasmine.createSpy("observeHandler")
      atom.config.set("foo.bar.baz", "value 1")
      observeSubscription = atom.config.observe "foo.bar.baz", observeHandler

    it "fires the given callback with the current value at the keypath", ->
      expect(observeHandler).toHaveBeenCalledWith("value 1")

    it "fires the callback every time the observed value changes", ->
      observeHandler.reset() # clear the initial call
      atom.config.set('foo.bar.baz', "value 2")
      expect(observeHandler).toHaveBeenCalledWith("value 2", {previous: 'value 1'})
      observeHandler.reset()

      atom.config.set('foo.bar.baz', "value 1")
      expect(observeHandler).toHaveBeenCalledWith("value 1", {previous: 'value 2'})

    it "fires the callback when the observed value is deleted", ->
      observeHandler.reset() # clear the initial call
      atom.config.set('foo.bar.baz', undefined)
      expect(observeHandler).toHaveBeenCalledWith(undefined, {previous: 'value 1'})

    it "fires the callback when the full key path goes into and out of existence", ->
      observeHandler.reset() # clear the initial call
      atom.config.set("foo.bar", undefined)

      expect(observeHandler).toHaveBeenCalledWith(undefined, {previous: 'value 1'})
      observeHandler.reset()

      atom.config.set("foo.bar.baz", "i'm back")
      expect(observeHandler).toHaveBeenCalledWith("i'm back", {previous: undefined})

    it "does not fire the callback once the observe subscription is off'ed", ->
      observeHandler.reset() # clear the initial call
      observeSubscription.off()
      atom.config.set('foo.bar.baz', "value 2")
      expect(observeHandler).not.toHaveBeenCalled()

  describe ".initializeConfigDirectory()", ->
    beforeEach ->
      atom.config.configDirPath = dotAtomPath
      expect(fs.existsSync(atom.config.configDirPath)).toBeFalsy()

    afterEach ->
      fs.removeSync(dotAtomPath)

    describe "when the configDirPath doesn't exist", ->
      it "copies the contents of dot-atom to ~/.atom", ->
        initializationDone = false
        jasmine.unspy(window, "setTimeout")
        atom.config.initializeConfigDirectory ->
          initializationDone = true

        waitsFor -> initializationDone

        runs ->
          expect(fs.existsSync(atom.config.configDirPath)).toBeTruthy()
          expect(fs.existsSync(path.join(atom.config.configDirPath, 'packages'))).toBeTruthy()
          expect(fs.isFileSync(path.join(atom.config.configDirPath, 'snippets.cson'))).toBeTruthy()
          expect(fs.isFileSync(path.join(atom.config.configDirPath, 'config.cson'))).toBeTruthy()
          expect(fs.isFileSync(path.join(atom.config.configDirPath, 'init.coffee'))).toBeTruthy()
          expect(fs.isFileSync(path.join(atom.config.configDirPath, 'styles.less'))).toBeTruthy()

  describe ".loadUserConfig()", ->
    beforeEach ->
      atom.config.configDirPath = dotAtomPath
      atom.config.configFilePath = path.join(atom.config.configDirPath, "atom.config.cson")
      expect(fs.existsSync(atom.config.configDirPath)).toBeFalsy()

    afterEach ->
      fs.removeSync(dotAtomPath)

    describe "when the config file contains valid cson", ->
      beforeEach ->
        fs.writeFileSync(atom.config.configFilePath, "foo: bar: 'baz'")
        atom.config.loadUserConfig()

      it "updates the config data based on the file contents", ->
        expect(atom.config.get("foo.bar")).toBe 'baz'

    describe "when the config file contains invalid cson", ->
      beforeEach ->
        spyOn(console, 'error')
        fs.writeFileSync(atom.config.configFilePath, "{{{{{")

      it "logs an error to the console and does not overwrite the config file on a subsequent save", ->
        atom.config.loadUserConfig()
        expect(console.error).toHaveBeenCalled()
        atom.config.set("hair", "blonde") # trigger a save
        expect(atom.config.save).not.toHaveBeenCalled()

    describe "when the config file does not exist", ->
      it "creates it with an empty object", ->
        fs.makeTreeSync(atom.config.configDirPath)
        atom.config.loadUserConfig()
        expect(fs.existsSync(atom.config.configFilePath)).toBe true
        expect(CSON.readFileSync(atom.config.configFilePath)).toEqual {}

  describe ".observeUserConfig()", ->
    updatedHandler = null

    beforeEach ->
      atom.config.configDirPath = dotAtomPath
      atom.config.configFilePath = path.join(atom.config.configDirPath, "atom.config.cson")
      expect(fs.existsSync(atom.config.configDirPath)).toBeFalsy()
      fs.writeFileSync(atom.config.configFilePath, "foo: bar: 'baz'")
      atom.config.loadUserConfig()
      atom.config.observeUserConfig()
      updatedHandler = jasmine.createSpy("updatedHandler")
      atom.config.on 'updated', updatedHandler

    afterEach ->
      atom.config.unobserveUserConfig()
      fs.removeSync(dotAtomPath)

    describe "when the config file changes to contain valid cson", ->
      it "updates the config data", ->
        fs.writeFileSync(atom.config.configFilePath, "foo: { bar: 'quux', baz: 'bar'}")
        waitsFor 'update event', -> updatedHandler.callCount > 0
        runs ->
          expect(atom.config.get('foo.bar')).toBe 'quux'
          expect(atom.config.get('foo.baz')).toBe 'bar'

    describe "when the config file changes to contain invalid cson", ->
      beforeEach ->
        spyOn(console, 'error')
        fs.writeFileSync(atom.config.configFilePath, "}}}")
        waitsFor "error to be logged", -> console.error.callCount > 0

      it "logs a warning and does not update config data", ->
        expect(updatedHandler.callCount).toBe 0
        expect(atom.config.get('foo.bar')).toBe 'baz'
        atom.config.set("hair", "blonde") # trigger a save
        expect(atom.config.save).not.toHaveBeenCalled()

      describe "when the config file subsequently changes again to contain valid cson", ->
        beforeEach ->
          fs.writeFileSync(atom.config.configFilePath, "foo: bar: 'baz'")
          waitsFor 'update event', -> updatedHandler.callCount > 0

        it "updates the config data and resumes saving", ->
          atom.config.set("hair", "blonde")
          expect(atom.config.save).toHaveBeenCalled()
