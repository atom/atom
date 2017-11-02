path = require 'path'
temp = require('temp').track()
CSON = require 'season'
fs = require 'fs-plus'
Config = require '../src/config'
ConfigStorage = require '../src/config-storage'
ConfigSchema = require '../src/config-schema'
_ = require 'underscore-plus'

fdescribe "Config", ->
  dotAtomPath = null
  config = null
  configStorage = null

  beforeEach ->
    jasmine.useMockClock()
    spyOn(console, 'warn')
    dotAtomPath = temp.path('atom-spec-config')

    {resourcePath} = atom.getLoadSettings()
    @config = new Config()
    @config.setSchema null, {type: 'object', properties: _.clone(ConfigSchema)}
    ConfigSchema.projectHome = {
      type: 'string',
      default: path.join(fs.getHomeDirectory(), 'github'),
      description: 'The directory where projects are assumed to be located. Packages created using the Package Generator will be stored here by default.'
    }
    @configStorage = new ConfigStorage({@config, configDirPath: dotAtomPath, resourcePath})
    @config.initialize({configFilePath: @configStorage.getUserConfigPath(), projectHomeSchema: ConfigSchema.projectHome})
    spyOn(@configStorage, 'startSave')

    waitsForPromise =>
      @configStorage.start()

  afterEach ->
    @configStorage.stop()

  describe ".get(keyPath, {scope, sources, excludeSources})", ->
    it "allows a key path's value to be read", ->
      expect(@config.set("foo.bar.baz", 42)).toBe true
      expect(@config.get("foo.bar.baz")).toBe 42
      expect(@config.get("foo.quux")).toBeUndefined()

    it "returns a deep clone of the key path's value", ->
      @config.set('value', array: [1, b: 2, 3])
      retrievedValue = @config.get('value')
      retrievedValue.array[0] = 4
      retrievedValue.array[1].b = 2.1
      expect(@config.get('value')).toEqual(array: [1, b: 2, 3])

    it "merges defaults into the returned value if both the assigned value and the default value are objects", ->
      @config.setDefaults("foo.bar", baz: 1, ok: 2)
      @config.set("foo.bar", baz: 3)
      expect(@config.get("foo.bar")).toEqual {baz: 3, ok: 2}

      @config.setDefaults("other", baz: 1)
      @config.set("other", 7)
      expect(@config.get("other")).toBe 7

      @config.set("bar.baz", a: 3)
      @config.setDefaults("bar", baz: 7)
      expect(@config.get("bar.baz")).toEqual {a: 3}

    describe "when a 'sources' option is specified", ->
      it "only retrieves values from the specified sources", ->
        @config.set("x.y", 1, scopeSelector: ".foo", source: "a")
        @config.set("x.y", 2, scopeSelector: ".foo", source: "b")
        @config.set("x.y", 3, scopeSelector: ".foo", source: "c")
        @config.setSchema("x.y", type: "integer", default: 4)

        expect(@config.get("x.y", sources: ["a"], scope: [".foo"])).toBe 1
        expect(@config.get("x.y", sources: ["b"], scope: [".foo"])).toBe 2
        expect(@config.get("x.y", sources: ["c"], scope: [".foo"])).toBe 3
        # Schema defaults never match a specific source. We could potentially add a special "schema" source.
        expect(@config.get("x.y", sources: ["x"], scope: [".foo"])).toBeUndefined()

        expect(@config.get(null, sources: ['a'], scope: [".foo"]).x.y).toBe 1

    describe "when an 'excludeSources' option is specified", ->
      it "only retrieves values from the specified sources", ->
        @config.set("x.y", 0)
        @config.set("x.y", 1, scopeSelector: ".foo", source: "a")
        @config.set("x.y", 2, scopeSelector: ".foo", source: "b")
        @config.set("x.y", 3, scopeSelector: ".foo", source: "c")
        @config.setSchema("x.y", type: "integer", default: 4)

        expect(@config.get("x.y", excludeSources: ["a"], scope: [".foo"])).toBe 3
        expect(@config.get("x.y", excludeSources: ["c"], scope: [".foo"])).toBe 2
        expect(@config.get("x.y", excludeSources: ["b", "c"], scope: [".foo"])).toBe 1
        expect(@config.get("x.y", excludeSources: ["b", "c", "a"], scope: [".foo"])).toBe 0
        expect(@config.get("x.y", excludeSources: ["b", "c", "a", @config.getUserConfigPath()], scope: [".foo"])).toBe 4
        expect(@config.get("x.y", excludeSources: [@config.getUserConfigPath()])).toBe 4

    describe "when a 'scope' option is given", ->
      it "returns the property with the most specific scope selector", ->
        @config.set("foo.bar.baz", 42, scopeSelector: ".source.coffee .string.quoted.double.coffee")
        @config.set("foo.bar.baz", 22, scopeSelector: ".source .string.quoted.double")
        @config.set("foo.bar.baz", 11, scopeSelector: ".source")

        expect(@config.get("foo.bar.baz", scope: [".source.coffee", ".string.quoted.double.coffee"])).toBe 42
        expect(@config.get("foo.bar.baz", scope: [".source.js", ".string.quoted.double.js"])).toBe 22
        expect(@config.get("foo.bar.baz", scope: [".source.js", ".variable.assignment.js"])).toBe 11
        expect(@config.get("foo.bar.baz", scope: [".text"])).toBeUndefined()

      it "favors the most recently added properties in the event of a specificity tie", ->
        @config.set("foo.bar.baz", 42, scopeSelector: ".source.coffee .string.quoted.single")
        @config.set("foo.bar.baz", 22, scopeSelector: ".source.coffee .string.quoted.double")

        expect(@config.get("foo.bar.baz", scope: [".source.coffee", ".string.quoted.single"])).toBe 42
        expect(@config.get("foo.bar.baz", scope: [".source.coffee", ".string.quoted.single.double"])).toBe 22

      describe 'when there are global defaults', ->
        it 'falls back to the global when there is no scoped property specified', ->
          @config.setDefaults("foo", hasDefault: 'ok')
          expect(@config.get("foo.hasDefault", scope: [".source.coffee", ".string.quoted.single"])).toBe 'ok'

      describe 'when package settings are added after user settings', ->
        it "returns the user's setting because the user's setting has higher priority", ->
          @config.set("foo.bar.baz", 100, scopeSelector: ".source.coffee")
          @config.set("foo.bar.baz", 1, scopeSelector: ".source.coffee", source: "some-package")
          expect(@config.get("foo.bar.baz", scope: [".source.coffee"])).toBe 100

  describe ".getAll(keyPath, {scope, sources, excludeSources})", ->
    it "reads all of the values for a given key-path", ->
      expect(@config.set("foo", 41)).toBe true
      expect(@config.set("foo", 43, scopeSelector: ".a .b")).toBe true
      expect(@config.set("foo", 42, scopeSelector: ".a")).toBe true
      expect(@config.set("foo", 44, scopeSelector: ".a .b.c")).toBe true

      expect(@config.set("foo", -44, scopeSelector: ".d")).toBe true

      expect(@config.getAll("foo", scope: [".a", ".b.c"])).toEqual [
        {scopeSelector: '.a .b.c', value: 44}
        {scopeSelector: '.a .b', value: 43}
        {scopeSelector: '.a', value: 42}
        {scopeSelector: '*', value: 41}
      ]

    it "includes the schema's default value", ->
      @config.setSchema("foo", type: 'number', default: 40)
      expect(@config.set("foo", 43, scopeSelector: ".a .b")).toBe true
      expect(@config.getAll("foo", scope: [".a", ".b.c"])).toEqual [
        {scopeSelector: '.a .b', value: 43}
        {scopeSelector: '*', value: 40}
      ]

  describe ".set(keyPath, value, {source, scopeSelector})", ->
    it "allows a key path's value to be written", ->
      expect(@config.set("foo.bar.baz", 42)).toBe true
      expect(@config.get("foo.bar.baz")).toBe 42

    it "saves the user's config to disk after it stops changing", ->
      @config.set("foo.bar.baz", 42)
      advanceClock(50)
      expect(@configStorage.startSave).not.toHaveBeenCalled()
      @config.set("foo.bar.baz", 43)
      advanceClock(50)
      expect(@configStorage.startSave).not.toHaveBeenCalled()
      @config.set("foo.bar.baz", 44)
      advanceClock(250)
      expect(@configStorage.startSave).toHaveBeenCalled()

    it "does not save when a non-default 'source' is given", ->
      @config.set("foo.bar.baz", 42, source: 'some-other-source', scopeSelector: '.a')
      advanceClock(500)
      expect(@configStorage.startSave).not.toHaveBeenCalled()

    it "does not allow a 'source' option without a 'scopeSelector'", ->
      expect(-> @config.set("foo", 1, source: [".source.ruby"])).toThrow()

    describe "when the key-path is null", ->
      it "sets the root object", ->
        expect(@config.set(null, editor: tabLength: 6)).toBe true
        expect(@config.get("editor.tabLength")).toBe 6
        expect(@config.set(null, editor: tabLength: 8, scopeSelector: ['.source.js'])).toBe true
        expect(@config.get("editor.tabLength", scope: ['.source.js'])).toBe 8

    describe "when the value equals the default value", ->
      it "does not store the value in the user's config", ->
        @config.setSchema "foo",
          type: 'object'
          properties:
            same:
              type: 'number'
              default: 1
            changes:
              type: 'number'
              default: 1
            sameArray:
              type: 'array'
              default: [1, 2, 3]
            sameObject:
              type: 'object'
              default: {a: 1, b: 2}
            null:
              type: '*'
              default: null
            undefined:
              type: '*'
              default: undefined
        expect(@config.settings.foo).toBeUndefined()

        @config.set('foo.same', 1)
        @config.set('foo.changes', 2)
        @config.set('foo.sameArray', [1, 2, 3])
        @config.set('foo.null', undefined)
        @config.set('foo.undefined', null)
        @config.set('foo.sameObject', {b: 2, a: 1})

        userConfigPath = @config.getUserConfigPath()

        expect(@config.get("foo.same", sources: [userConfigPath])).toBeUndefined()

        expect(@config.get("foo.changes")).toBe 2
        expect(@config.get("foo.changes", sources: [userConfigPath])).toBe 2

        @config.set('foo.changes', 1)
        expect(@config.get("foo.changes", sources: [userConfigPath])).toBeUndefined()

    describe "when a 'scopeSelector' is given", ->
      it "sets the value and overrides the others", ->
        @config.set("foo.bar.baz", 42, scopeSelector: ".source.coffee .string.quoted.double.coffee")
        @config.set("foo.bar.baz", 22, scopeSelector: ".source .string.quoted.double")
        @config.set("foo.bar.baz", 11, scopeSelector: ".source")

        expect(@config.get("foo.bar.baz", scope: [".source.coffee", ".string.quoted.double.coffee"])).toBe 42

        expect(@config.set("foo.bar.baz", 100, scopeSelector: ".source.coffee .string.quoted.double.coffee")).toBe true
        expect(@config.get("foo.bar.baz", scope: [".source.coffee", ".string.quoted.double.coffee"])).toBe 100

  ffdescribe ".unset(keyPath, {source, scopeSelector})", ->
    beforeEach ->
      @config.setSchema 'foo',
        type: 'object'
        properties:
          bar:
            type: 'object'
            properties:
              baz:
                type: 'integer'
                default: 0
              ok:
                type: 'integer'
                default: 0
          quux:
            type: 'integer'
            default: 0

    it "sets the value of the key path to its default", ->
      @config.setDefaults('a', b: 3)
      @config.set('a.b', 4)
      expect(@config.get('a.b')).toBe 4
      @config.unset('a.b')
      expect(@config.get('a.b')).toBe 3

      @config.set('a.c', 5)
      expect(@config.get('a.c')).toBe 5
      @config.unset('a.c')
      expect(@config.get('a.c')).toBeUndefined()

    it "triggers ConfigStorage.startSave()", ->
      @config.setDefaults('a', b: 3)
      @config.set('a.b', 4)
      @configStorage.startSave.reset()

      @config.unset('a.c')
      advanceClock(500)
      expect(@configStorage.startSave.callCount).toBe 1

    describe "when no 'scopeSelector' is given", ->
      describe "when a 'source' but no key-path is given", ->
        it "removes all scoped settings with the given source", ->
          @config.set("foo.bar.baz", 1, scopeSelector: ".a", source: "source-a")
          @config.set("foo.bar.quux", 2, scopeSelector: ".b", source: "source-a")
          expect(@config.get("foo.bar", scope: [".a.b"])).toEqual(baz: 1, quux: 2)

          @config.unset(null, source: "source-a")
          expect(@config.get("foo.bar", scope: [".a"])).toEqual(baz: 0, ok: 0)

      describe "when a 'source' and a key-path is given", ->
        it "removes all scoped settings with the given source and key-path", ->
          @config.set("foo.bar.baz", 1)
          @config.set("foo.bar.baz", 2, scopeSelector: ".a", source: "source-a")
          @config.set("foo.bar.baz", 3, scopeSelector: ".a.b", source: "source-b")
          expect(@config.get("foo.bar.baz", scope: [".a.b"])).toEqual(3)

          @config.unset("foo.bar.baz", source: "source-b")
          expect(@config.get("foo.bar.baz", scope: [".a.b"])).toEqual(2)
          expect(@config.get("foo.bar.baz")).toEqual(1)

      describe "when no 'source' is given", ->
        it "removes all scoped and unscoped properties for that key-path", ->
          @config.setDefaults("foo.bar", baz: 100)

          @config.set("foo.bar", {baz: 1, ok: 2}, scopeSelector: ".a")
          @config.set("foo.bar", {baz: 11, ok: 12}, scopeSelector: ".b")
          @config.set("foo.bar", {baz: 21, ok: 22})

          @config.unset("foo.bar.baz")

          expect(@config.get("foo.bar.baz", scope: [".a"])).toBe 100
          expect(@config.get("foo.bar.baz", scope: [".b"])).toBe 100
          expect(@config.get("foo.bar.baz")).toBe 100

          expect(@config.get("foo.bar.ok", scope: [".a"])).toBe 2
          expect(@config.get("foo.bar.ok", scope: [".b"])).toBe 12
          expect(@config.get("foo.bar.ok")).toBe 22

    describe "when a 'scopeSelector' is given", ->
      it "restores the global default when no scoped default set", ->
        @config.setDefaults("foo", bar: baz: 10)
        @config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee')
        expect(@config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 55

        @config.unset('foo.bar.baz', scopeSelector: '.source.coffee')
        expect(@config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 10

      it "restores the scoped default when a scoped default is set", ->
        @config.setDefaults("foo", bar: baz: 10)
        @config.set("foo.bar.baz", 42, scopeSelector: ".source.coffee", source: "some-source")
        @config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee')
        @config.set('foo.bar.ok', 100, scopeSelector: '.source.coffee')
        expect(@config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 55

        @config.unset('foo.bar.baz', scopeSelector: '.source.coffee')
        expect(@config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 42
        expect(@config.get('foo.bar.ok', scope: ['.source.coffee'])).toBe 100

      it "triggers ConfigStorage.startSave()", ->
        @config.setDefaults("foo", bar: baz: 10)
        @config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee')
        @configStorage.startSave.reset()

        @config.unset('foo.bar.baz', scopeSelector: '.source.coffee')
        advanceClock(250)
        expect(@configStorage.startSave.callCount).toBe 1

      it "allows removing settings for a specific source and scope selector", ->
        @config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee', source: "source-a")
        @config.set('foo.bar.baz', 65, scopeSelector: '.source.coffee', source: "source-b")
        expect(@config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 65

        @config.unset('foo.bar.baz', source: "source-b", scopeSelector: ".source.coffee")
        expect(@config.get('foo.bar.baz', scope: ['.source.coffee', '.string'])).toBe 55

      it "allows removing all settings for a specific source", ->
        @config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee', source: "source-a")
        @config.set('foo.bar.baz', 65, scopeSelector: '.source.coffee', source: "source-b")
        @config.set('foo.bar.ok', 65, scopeSelector: '.source.coffee', source: "source-b")
        expect(@config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 65

        @config.unset(null, source: "source-b", scopeSelector: ".source.coffee")
        expect(@config.get('foo.bar.baz', scope: ['.source.coffee', '.string'])).toBe 55
        expect(@config.get('foo.bar.ok', scope: ['.source.coffee', '.string'])).toBe 0

      it "does not call ::save or add a scoped property when no value has been set", ->
        # see https://github.com/atom/atom/issues/4175
        @config.setDefaults("foo", bar: baz: 10)
        @config.unset('foo.bar.baz', scopeSelector: '.source.coffee')
        expect(@config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 10

        expect(@configStorage.startSave).not.toHaveBeenCalled()

        scopedProperties = @config.scopedSettingsStore.propertiesForSource('user-config')
        expect(scopedProperties['.coffee.source']).toBeUndefined()

      fffit "removes the scoped value when it was the only set value on the object", ->
        spyOn(CSON, 'writeFile').andCallThrough()
        @configStorage.startSave.andCallThrough()
        saveCount = 0
        @configStorage.onDidSave -> saveCount++

        @config.setDefaults("foo", bar: baz: 10)
        @config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee')
        @config.set('foo.bar.ok', 20, scopeSelector: '.source.coffee')
        expect(@config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 55
        advanceClock(250)

        waitsFor ->
          saveCount is 1

        runs ->
          debugger
          expect(CSON.writeFile).toHaveBeenCalled()
          @config.unset('foo.bar.baz', scopeSelector: '.source.coffee')
          expect(@config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 10
          expect(@config.get('foo.bar.ok', scope: ['.source.coffee'])).toBe 20
          CSON.writeFile.reset()
          advanceClock(250)

        waitsFor ->
          saveCount is 2

        runs ->
          expect(CSON.writeFile).toHaveBeenCalled()
          properties = CSON.writeFile.mostRecentCall.args[1]
          expect(properties['.coffee.source']).toEqual
            foo:
              bar:
                ok: 20

          console.log('block 3')
          debugger
          @config.unset('foo.bar.ok', scopeSelector: '.source.coffee')
          debugger
          CSON.writeFile.reset()
          advanceClock(250)

        waitsFor ->
          saveCount is 3

        runs ->
          expect(CSON.writeFile).toHaveBeenCalled()
          properties = CSON.writeFile.mostRecentCall.args[1]
          expect(properties['.coffee.source']).toBeUndefined()

      it "does not call ::save when the value is already at the default", ->
        @config.setDefaults("foo", bar: baz: 10)
        @config.set('foo.bar.baz', 55)
        @configStorage.startSave.reset()

        @config.unset('foo.bar.ok', scopeSelector: '.source.coffee')
        expect(@configStorage.startSave).not.toHaveBeenCalled()
        expect(@config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 55

  describe ".onDidChange(keyPath, {scope})", ->
    [observeHandler, observeSubscription] = []

    describe 'when a keyPath is specified', ->
      beforeEach ->
        observeHandler = jasmine.createSpy("observeHandler")
        @config.set("foo.bar.baz", "value 1")
        observeSubscription = @config.onDidChange "foo.bar.baz", observeHandler

      it "does not fire the given callback with the current value at the keypath", ->
        expect(observeHandler).not.toHaveBeenCalled()

      it "fires the callback every time the observed value changes", ->
        @config.set('foo.bar.baz', "value 2")
        expect(observeHandler).toHaveBeenCalledWith({newValue: 'value 2', oldValue: 'value 1'})
        observeHandler.reset()

        observeHandler.andCallFake -> throw new Error("oops")
        expect(-> @config.set('foo.bar.baz', "value 1")).toThrow("oops")
        expect(observeHandler).toHaveBeenCalledWith({newValue: 'value 1', oldValue: 'value 2'})
        observeHandler.reset()

        # Regression: exception in earlier handler shouldn't put observer
        # into a bad state.
        @config.set('something.else', "new value")
        expect(observeHandler).not.toHaveBeenCalled()

    describe 'when a keyPath is not specified', ->
      beforeEach ->
        observeHandler = jasmine.createSpy("observeHandler")
        @config.set("foo.bar.baz", "value 1")
        observeSubscription = @config.onDidChange observeHandler

      it "does not fire the given callback initially", ->
        expect(observeHandler).not.toHaveBeenCalled()

      it "fires the callback every time any value changes", ->
        observeHandler.reset() # clear the initial call
        @config.set('foo.bar.baz', "value 2")
        expect(observeHandler).toHaveBeenCalled()
        expect(observeHandler.mostRecentCall.args[0].newValue.foo.bar.baz).toBe("value 2")
        expect(observeHandler.mostRecentCall.args[0].oldValue.foo.bar.baz).toBe("value 1")

        observeHandler.reset()
        @config.set('foo.bar.baz', "value 1")
        expect(observeHandler).toHaveBeenCalled()
        expect(observeHandler.mostRecentCall.args[0].newValue.foo.bar.baz).toBe("value 1")
        expect(observeHandler.mostRecentCall.args[0].oldValue.foo.bar.baz).toBe("value 2")

        observeHandler.reset()
        @config.set('foo.bar.int', 1)
        expect(observeHandler).toHaveBeenCalled()
        expect(observeHandler.mostRecentCall.args[0].newValue.foo.bar.int).toBe(1)
        expect(observeHandler.mostRecentCall.args[0].oldValue.foo.bar.int).toBe(undefined)

    describe "when a 'scope' is given", ->
      it 'calls the supplied callback when the value at the descriptor/keypath changes', ->
        changeSpy = jasmine.createSpy('onDidChange callback')
        @config.onDidChange "foo.bar.baz", scope: [".source.coffee", ".string.quoted.double.coffee"], changeSpy

        @config.set("foo.bar.baz", 12)
        expect(changeSpy).toHaveBeenCalledWith({oldValue: undefined, newValue: 12})
        changeSpy.reset()

        @config.set("foo.bar.baz", 22, scopeSelector: ".source .string.quoted.double", source: "a")
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 12, newValue: 22})
        changeSpy.reset()

        @config.set("foo.bar.baz", 42, scopeSelector: ".source.coffee .string.quoted.double.coffee", source: "b")
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 22, newValue: 42})
        changeSpy.reset()

        @config.unset(null, scopeSelector: ".source.coffee .string.quoted.double.coffee", source: "b")
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 42, newValue: 22})
        changeSpy.reset()

        @config.unset(null, scopeSelector: ".source .string.quoted.double", source: "a")
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 22, newValue: 12})
        changeSpy.reset()

        @config.set("foo.bar.baz", undefined)
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 12, newValue: undefined})
        changeSpy.reset()

  describe ".observe(keyPath, {scope})", ->
    [observeHandler, observeSubscription] = []

    beforeEach ->
      observeHandler = jasmine.createSpy("observeHandler")
      @config.set("foo.bar.baz", "value 1")
      observeSubscription = @config.observe("foo.bar.baz", observeHandler)

    it "fires the given callback with the current value at the keypath", ->
      expect(observeHandler).toHaveBeenCalledWith("value 1")

    it "fires the callback every time the observed value changes", ->
      observeHandler.reset() # clear the initial call
      @config.set('foo.bar.baz', "value 2")
      expect(observeHandler).toHaveBeenCalledWith("value 2")

      observeHandler.reset()
      @config.set('foo.bar.baz', "value 1")
      expect(observeHandler).toHaveBeenCalledWith("value 1")
      advanceClock(100) # complete pending save that was requested in ::set

      observeHandler.reset()
      @config.loadUserConfig()
      expect(observeHandler).toHaveBeenCalledWith(undefined)

    it "fires the callback when the observed value is deleted", ->
      observeHandler.reset() # clear the initial call
      @config.set('foo.bar.baz', undefined)
      expect(observeHandler).toHaveBeenCalledWith(undefined)

    it "fires the callback when the full key path goes into and out of existence", ->
      observeHandler.reset() # clear the initial call
      @config.set("foo.bar", undefined)
      expect(observeHandler).toHaveBeenCalledWith(undefined)

      observeHandler.reset()
      @config.set("foo.bar.baz", "i'm back")
      expect(observeHandler).toHaveBeenCalledWith("i'm back")

    it "does not fire the callback once the subscription is disposed", ->
      observeHandler.reset() # clear the initial call
      observeSubscription.dispose()
      @config.set('foo.bar.baz', "value 2")
      expect(observeHandler).not.toHaveBeenCalled()

    it 'does not fire the callback for a similarly named keyPath', ->
      bazCatHandler = jasmine.createSpy("bazCatHandler")
      observeSubscription = @config.observe "foo.bar.bazCat", bazCatHandler

      bazCatHandler.reset()
      @config.set('foo.bar.baz', "value 10")
      expect(bazCatHandler).not.toHaveBeenCalled()

    describe "when a 'scope' is given", ->
      otherHandler = null

      beforeEach ->
        observeSubscription.dispose()
        otherHandler = jasmine.createSpy('otherHandler')

      it "allows settings to be observed in a specific scope", ->
        @config.observe("foo.bar.baz", scope: [".some.scope"], observeHandler)
        @config.observe("foo.bar.baz", scope: [".another.scope"], otherHandler)

        @config.set('foo.bar.baz', "value 2", scopeSelector: ".some")
        expect(observeHandler).toHaveBeenCalledWith("value 2")
        expect(otherHandler).not.toHaveBeenCalledWith("value 2")

      it 'calls the callback when properties with more specific selectors are removed', ->
        changeSpy = jasmine.createSpy()
        @config.observe("foo.bar.baz", scope: [".source.coffee", ".string.quoted.double.coffee"], changeSpy)
        expect(changeSpy).toHaveBeenCalledWith("value 1")
        changeSpy.reset()

        @config.set("foo.bar.baz", 12)
        expect(changeSpy).toHaveBeenCalledWith(12)
        changeSpy.reset()

        @config.set("foo.bar.baz", 22, scopeSelector: ".source .string.quoted.double", source: "a")
        expect(changeSpy).toHaveBeenCalledWith(22)
        changeSpy.reset()

        @config.set("foo.bar.baz", 42, scopeSelector: ".source.coffee .string.quoted.double.coffee", source: "b")
        expect(changeSpy).toHaveBeenCalledWith(42)
        changeSpy.reset()

        @config.unset(null, scopeSelector: ".source.coffee .string.quoted.double.coffee", source: "b")
        expect(changeSpy).toHaveBeenCalledWith(22)
        changeSpy.reset()

        @config.unset(null, scopeSelector: ".source .string.quoted.double", source: "a")
        expect(changeSpy).toHaveBeenCalledWith(12)
        changeSpy.reset()

        @config.set("foo.bar.baz", undefined)
        expect(changeSpy).toHaveBeenCalledWith(undefined)
        changeSpy.reset()

  describe ".transact(callback)", ->
    changeSpy = null

    beforeEach ->
      changeSpy = jasmine.createSpy('onDidChange callback')
      @config.onDidChange("foo.bar.baz", changeSpy)

    it "allows only one change event for the duration of the given callback", ->
      @config.transact ->
        @config.set("foo.bar.baz", 1)
        @config.set("foo.bar.baz", 2)
        @config.set("foo.bar.baz", 3)

      expect(changeSpy.callCount).toBe(1)
      expect(changeSpy.argsForCall[0][0]).toEqual(newValue: 3, oldValue: undefined)

    it "does not emit an event if no changes occur while paused", ->
      @config.transact ->
      expect(changeSpy).not.toHaveBeenCalled()

  describe ".transactAsync(callback)", ->
    changeSpy = null

    beforeEach ->
      changeSpy = jasmine.createSpy('onDidChange callback')
      @config.onDidChange("foo.bar.baz", changeSpy)

    it "allows only one change event for the duration of the given promise if it gets resolved", ->
      promiseResult = null
      transactionPromise = @config.transactAsync ->
        @config.set("foo.bar.baz", 1)
        @config.set("foo.bar.baz", 2)
        @config.set("foo.bar.baz", 3)
        Promise.resolve("a result")

      waitsForPromise -> transactionPromise.then (r) -> promiseResult = r

      runs ->
        expect(promiseResult).toBe("a result")
        expect(changeSpy.callCount).toBe(1)
        expect(changeSpy.argsForCall[0][0]).toEqual(newValue: 3, oldValue: undefined)

    it "allows only one change event for the duration of the given promise if it gets rejected", ->
      promiseError = null
      transactionPromise = @config.transactAsync ->
        @config.set("foo.bar.baz", 1)
        @config.set("foo.bar.baz", 2)
        @config.set("foo.bar.baz", 3)
        Promise.reject("an error")

      waitsForPromise -> transactionPromise.catch (e) -> promiseError = e

      runs ->
        expect(promiseError).toBe("an error")
        expect(changeSpy.callCount).toBe(1)
        expect(changeSpy.argsForCall[0][0]).toEqual(newValue: 3, oldValue: undefined)

    it "allows only one change event even when the given callback throws", ->
      error = new Error("Oops!")
      promiseError = null
      transactionPromise = @config.transactAsync ->
        @config.set("foo.bar.baz", 1)
        @config.set("foo.bar.baz", 2)
        @config.set("foo.bar.baz", 3)
        throw error

      waitsForPromise -> transactionPromise.catch (e) -> promiseError = e

      runs ->
        expect(promiseError).toBe(error)
        expect(changeSpy.callCount).toBe(1)
        expect(changeSpy.argsForCall[0][0]).toEqual(newValue: 3, oldValue: undefined)

  describe ".getSources()", ->
    it "returns an array of all of the config's source names", ->
      expect(@config.getSources()).toEqual([])

      @config.set("a.b", 1, scopeSelector: ".x1", source: "source-1")
      @config.set("a.c", 1, scopeSelector: ".x1", source: "source-1")
      @config.set("a.b", 2, scopeSelector: ".x2", source: "source-2")
      @config.set("a.b", 1, scopeSelector: ".x3", source: "source-3")

      expect(@config.getSources()).toEqual([
        "source-1"
        "source-2"
        "source-3"
      ])

  describe "Internal Methods", ->
    describe ".save()", ->
      CSON = require 'season'

      beforeEach ->
        spyOn(CSON, 'writeFileSync')
        jasmine.unspy @config, 'save'

      describe "when ~/.atom/config.json exists", ->
        it "writes any non-default properties to ~/.atom/config.json", ->
          @config.set("a.b.c", 1)
          @config.set("a.b.d", 2)
          @config.set("x.y.z", 3)
          @config.setDefaults("a.b", e: 4, f: 5)

          CSON.writeFileSync.reset()
          @config.save()

          expect(CSON.writeFileSync.argsForCall[0][0]).toBe @config.configFilePath
          writtenConfig = CSON.writeFileSync.argsForCall[0][1]
          expect(writtenConfig).toEqual '*': @config.settings

        it 'writes properties in alphabetical order', ->
          @config.set('foo', 1)
          @config.set('bar', 2)
          @config.set('baz.foo', 3)
          @config.set('baz.bar', 4)

          CSON.writeFileSync.reset()
          @config.save()

          expect(CSON.writeFileSync.argsForCall[0][0]).toBe @config.configFilePath
          writtenConfig = CSON.writeFileSync.argsForCall[0][1]
          expect(writtenConfig).toEqual '*': @config.settings

          expectedKeys = ['bar', 'baz', 'foo']
          foundKeys = (key for key of writtenConfig['*'] when key in expectedKeys)
          expect(foundKeys).toEqual expectedKeys
          expectedKeys = ['bar', 'foo']
          foundKeys = (key for key of writtenConfig['*']['baz'] when key in expectedKeys)
          expect(foundKeys).toEqual expectedKeys

      describe "when ~/.atom/config.json doesn't exist", ->
        it "writes any non-default properties to ~/.atom/config.cson", ->
          @config.set("a.b.c", 1)
          @config.set("a.b.d", 2)
          @config.set("x.y.z", 3)
          @config.setDefaults("a.b", e: 4, f: 5)

          CSON.writeFileSync.reset()
          @config.save()

          expect(CSON.writeFileSync.argsForCall[0][0]).toBe path.join(@config.configDirPath, "@config.cson")
          writtenConfig = CSON.writeFileSync.argsForCall[0][1]
          expect(writtenConfig).toEqual '*': @config.settings

      describe "when scoped settings are defined", ->
        it 'writes out explicitly set config settings', ->
          @config.set('foo.bar', 'ruby', scopeSelector: '.source.ruby')
          @config.set('foo.omg', 'wow', scopeSelector: '.source.ruby')
          @config.set('foo.bar', 'coffee', scopeSelector: '.source.coffee')

          CSON.writeFileSync.reset()
          @config.save()

          writtenConfig = CSON.writeFileSync.argsForCall[0][1]
          expect(writtenConfig).toEqualJson
            '*':
              @config.settings
            '.ruby.source':
              foo:
                bar: 'ruby'
                omg: 'wow'
            '.coffee.source':
              foo:
                bar: 'coffee'

      describe "when an error is thrown writing the file to disk", ->
        addErrorHandler = null
        beforeEach ->
          atom.notifications.onDidAddNotification addErrorHandler = jasmine.createSpy()

        it "creates a notification", ->
          jasmine.unspy CSON, 'writeFileSync'
          spyOn(CSON, 'writeFileSync').andCallFake ->
            error = new Error()
            error.code = 'EPERM'
            error.path = @config.getUserConfigPath()
            throw error

          save = -> @config.save()
          expect(save).not.toThrow()
          expect(addErrorHandler.callCount).toBe 1

    describe ".loadUserConfig()", ->
      beforeEach ->
        expect(fs.existsSync(@config.configDirPath)).toBeFalsy()
        @config.setSchema 'foo',
          type: 'object'
          properties:
            bar:
              type: 'string'
              default: 'def'
            int:
              type: 'integer'
              default: 12

      afterEach ->
        fs.removeSync(dotAtomPath)

      describe "when the config file contains scoped settings", ->
        beforeEach ->
          fs.writeFileSync @config.configFilePath, """
            '*':
              foo:
                bar: 'baz'

            '.source.ruby':
              foo:
                bar: 'more-specific'
          """
          @config.loadUserConfig()

        it "updates the config data based on the file contents", ->
          expect(@config.get("foo.bar")).toBe 'baz'
          expect(@config.get("foo.bar", scope: ['.source.ruby'])).toBe 'more-specific'

      describe "when the config file does not conform to the schema", ->
        beforeEach ->
          fs.writeFileSync @config.configFilePath, """
            '*':
              foo:
                bar: 'omg'
                int: 'baz'
            '.source.ruby':
              foo:
                bar: 'scoped'
                int: 'nope'
          """

        it "validates and does not load the incorrect values", ->
          @config.loadUserConfig()
          expect(@config.get("foo.int")).toBe 12
          expect(@config.get("foo.bar")).toBe 'omg'
          expect(@config.get("foo.int", scope: ['.source.ruby'])).toBe 12
          expect(@config.get("foo.bar", scope: ['.source.ruby'])).toBe 'scoped'

      describe "when the config file contains valid cson", ->
        beforeEach ->
          fs.writeFileSync(@config.configFilePath, "foo: bar: 'baz'")

        it "updates the config data based on the file contents", ->
          @config.loadUserConfig()
          expect(@config.get("foo.bar")).toBe 'baz'

        it "notifies observers for updated keypaths on load", ->
          observeHandler = jasmine.createSpy("observeHandler")
          observeSubscription = @config.observe "foo.bar", observeHandler

          @config.loadUserConfig()

          expect(observeHandler).toHaveBeenCalledWith 'baz'

      describe "when the config file contains invalid cson", ->
        addErrorHandler = null
        beforeEach ->
          atom.notifications.onDidAddNotification addErrorHandler = jasmine.createSpy()
          fs.writeFileSync(@config.configFilePath, "{{{{{")

        it "logs an error to the console and does not overwrite the config file on a subsequent save", ->
          @config.loadUserConfig()
          expect(addErrorHandler.callCount).toBe 1
          @config.set("hair", "blonde") # trigger a save
          expect(@config.save).not.toHaveBeenCalled()

      describe "when the config file does not exist", ->
        it "creates it with an empty object", ->
          fs.makeTreeSync(@config.configDirPath)
          @config.loadUserConfig()
          expect(fs.existsSync(@config.configFilePath)).toBe true
          expect(CSON.readFileSync(@config.configFilePath)).toEqual {}

      describe "when the config file contains values that do not adhere to the schema", ->
        beforeEach ->
          fs.writeFileSync @config.configFilePath, """
            foo:
              bar: 'baz'
              int: 'bad value'
          """
          @config.loadUserConfig()

        it "updates the only the settings that have values matching the schema", ->
          expect(@config.get("foo.bar")).toBe 'baz'
          expect(@config.get("foo.int")).toBe 12

          expect(console.warn).toHaveBeenCalled()
          expect(console.warn.mostRecentCall.args[0]).toContain "foo.int"

      describe "when there is a pending save", ->
        it "does not change the config settings", ->
          fs.writeFileSync @config.configFilePath, "'*': foo: bar: 'baz'"

          @config.set("foo.bar", "quux")
          @config.loadUserConfig()
          expect(@config.get("foo.bar")).toBe "quux"

          advanceClock(100)
          expect(@config.save.callCount).toBe 1

          expect(@config.get("foo.bar")).toBe "quux"
          @config.loadUserConfig()
          expect(@config.get("foo.bar")).toBe "baz"

      describe "when the config file fails to load", ->
        addErrorHandler = null

        beforeEach ->
          atom.notifications.onDidAddNotification addErrorHandler = jasmine.createSpy()
          spyOn(fs, "makeTreeSync").andCallFake ->
            error = new Error()
            error.code = 'EPERM'
            throw error

        it "creates a notification and does not try to save later changes to disk", ->
          load = -> @config.loadUserConfig()
          expect(load).not.toThrow()
          expect(addErrorHandler.callCount).toBe 1

          @config.set("foo.bar", "baz")
          advanceClock(100)
          expect(@config.save).not.toHaveBeenCalled()
          expect(@config.get("foo.bar")).toBe "baz"

    describe ".observeUserConfig()", ->
      updatedHandler = null

      writeConfigFile = (data, secondsInFuture = 0) ->
        fs.writeFileSync(@config.configFilePath, data)

        future = (Date.now() / 1000) + secondsInFuture
        fs.utimesSync(@config.configFilePath, future, future)

      beforeEach ->
        jasmine.useRealClock()

        @config.setSchema 'foo',
          type: 'object'
          properties:
            bar:
              type: 'string'
              default: 'def'
            baz:
              type: 'string'
            scoped:
              type: 'boolean'
            int:
              type: 'integer'
              default: 12

        expect(fs.existsSync(@config.configDirPath)).toBeFalsy()
        writeConfigFile """
          '*':
            foo:
              bar: 'baz'
              scoped: false
          '.source.ruby':
            foo:
              scoped: true
        """
        @config.loadUserConfig()

        waitsForPromise -> @config.observeUserConfig()

        runs ->
          updatedHandler = jasmine.createSpy "updatedHandler"
          @config.onDidChange updatedHandler

      afterEach ->
        @config.unobserveUserConfig()
        fs.removeSync(dotAtomPath)

      describe "when the config file changes to contain valid cson", ->

        it "updates the config data", ->
          writeConfigFile "foo: { bar: 'quux', baz: 'bar'}", 2

          waitsFor 'update event', -> updatedHandler.callCount > 0

          runs ->
            expect(@config.get('foo.bar')).toBe 'quux'
            expect(@config.get('foo.baz')).toBe 'bar'

        it "does not fire a change event for paths that did not change", ->
          @config.onDidChange 'foo.bar', noChangeSpy = jasmine.createSpy "unchanged"

          writeConfigFile "foo: { bar: 'baz', baz: 'ok'}", 2
          waitsFor 'update event', -> updatedHandler.callCount > 0

          runs ->
            expect(noChangeSpy).not.toHaveBeenCalled()
            expect(@config.get('foo.bar')).toBe 'baz'
            expect(@config.get('foo.baz')).toBe 'ok'

        describe "when the default value is a complex value", ->
          beforeEach ->
            @config.setSchema 'foo.bar',
              type: 'array'
              items:
                type: 'string'

            updatedHandler.reset()
            writeConfigFile "foo: { bar: ['baz', 'ok']}", 4
            waitsFor 'update event', -> updatedHandler.callCount > 0
            runs -> updatedHandler.reset()

          it "does not fire a change event for paths that did not change", ->
            noChangeSpy = jasmine.createSpy "unchanged"
            @config.onDidChange('foo.bar', noChangeSpy)

            writeConfigFile "foo: { bar: ['baz', 'ok'], baz: 'another'}", 2
            waitsFor 'update event', -> updatedHandler.callCount > 0

            runs ->
              expect(noChangeSpy).not.toHaveBeenCalled()
              expect(@config.get('foo.bar')).toEqual ['baz', 'ok']
              expect(@config.get('foo.baz')).toBe 'another'

        describe "when scoped settings are used", ->
          it "fires a change event for scoped settings that are removed", ->
            scopedSpy = jasmine.createSpy()
            @config.onDidChange('foo.scoped', scope: ['.source.ruby'], scopedSpy)

            writeConfigFile """
              '*':
                foo:
                  scoped: false
            """, 2
            waitsFor 'update event', -> updatedHandler.callCount > 0

            runs ->
              expect(scopedSpy).toHaveBeenCalled()
              expect(@config.get('foo.scoped', scope: ['.source.ruby'])).toBe false

          it "does not fire a change event for paths that did not change", ->
            noChangeSpy = jasmine.createSpy "no change"
            @config.onDidChange('foo.scoped', scope: ['.source.ruby'], noChangeSpy)

            writeConfigFile """
              '*':
                foo:
                  bar: 'baz'
              '.source.ruby':
                foo:
                  scoped: true
            """, 2
            waitsFor 'update event', -> updatedHandler.callCount > 0

            runs ->
              expect(noChangeSpy).not.toHaveBeenCalled()
              expect(@config.get('foo.bar', scope: ['.source.ruby'])).toBe 'baz'
              expect(@config.get('foo.scoped', scope: ['.source.ruby'])).toBe true

      describe "when the config file changes to omit a setting with a default", ->
        it "resets the setting back to the default", ->
          writeConfigFile "foo: { baz: 'new'}", 2
          waitsFor 'update event', -> updatedHandler.callCount > 0
          runs ->
            expect(@config.get('foo.bar')).toBe 'def'
            expect(@config.get('foo.baz')).toBe 'new'

      describe "when the config file changes to be empty", ->
        beforeEach ->
          updatedHandler.reset()
          writeConfigFile "", 4
          waitsFor 'update event', -> updatedHandler.callCount > 0

        it "resets all settings back to the defaults", ->
          expect(updatedHandler.callCount).toBe 1
          expect(@config.get('foo.bar')).toBe 'def'
          @config.set("hair", "blonde") # trigger a save
          waitsFor 'save', -> @config.save.callCount > 0

        describe "when the config file subsequently changes again to contain configuration", ->
          beforeEach ->
            updatedHandler.reset()
            writeConfigFile "foo: bar: 'newVal'", 2
            waitsFor 'update event', -> updatedHandler.callCount > 0

          it "sets the setting to the value specified in the config file", ->
            expect(@config.get('foo.bar')).toBe 'newVal'

      describe "when the config file changes to contain invalid cson", ->
        addErrorHandler = null
        beforeEach ->
          atom.notifications.onDidAddNotification addErrorHandler = jasmine.createSpy "error handler"
          writeConfigFile "}}}", 4
          waitsFor "error to be logged", -> addErrorHandler.callCount > 0

        it "logs a warning and does not update config data", ->
          expect(updatedHandler.callCount).toBe 0
          expect(@config.get('foo.bar')).toBe 'baz'

          @config.set("hair", "blonde") # trigger a save
          expect(@config.save).not.toHaveBeenCalled()

        describe "when the config file subsequently changes again to contain valid cson", ->
          beforeEach ->
            updatedHandler.reset()
            writeConfigFile "foo: bar: 'newVal'", 6
            waitsFor 'update event', -> updatedHandler.callCount > 0

          it "updates the config data and resumes saving", ->
            @config.set("hair", "blonde")
            waitsFor 'save', -> @config.save.callCount > 0

    describe ".initializeConfigDirectory()", ->
      beforeEach ->
        if fs.existsSync(dotAtomPath)
          fs.removeSync(dotAtomPath)

        @config.configDirPath = dotAtomPath

      afterEach ->
        fs.removeSync(dotAtomPath)

      describe "when the configDirPath doesn't exist", ->
        it "copies the contents of dot-atom to ~/.atom", ->
          return if process.platform is 'win32' # Flakey test on Win32
          initializationDone = false
          jasmine.unspy(window, "setTimeout")
          @config.initializeConfigDirectory ->
            initializationDone = true

          waitsFor -> initializationDone

          runs ->
            expect(fs.existsSync(@config.configDirPath)).toBeTruthy()
            expect(fs.existsSync(path.join(@config.configDirPath, 'packages'))).toBeTruthy()
            expect(fs.isFileSync(path.join(@config.configDirPath, 'snippets.cson'))).toBeTruthy()
            expect(fs.isFileSync(path.join(@config.configDirPath, 'init.coffee'))).toBeTruthy()
            expect(fs.isFileSync(path.join(@config.configDirPath, 'styles.less'))).toBeTruthy()

    describe ".pushAtKeyPath(keyPath, value)", ->
      it "pushes the given value to the array at the key path and updates observers", ->
        @config.set("foo.bar.baz", ["a"])
        observeHandler = jasmine.createSpy "observeHandler"
        @config.observe "foo.bar.baz", observeHandler
        observeHandler.reset()

        expect(@config.pushAtKeyPath("foo.bar.baz", "b")).toBe 2
        expect(@config.get("foo.bar.baz")).toEqual ["a", "b"]
        expect(observeHandler).toHaveBeenCalledWith @config.get("foo.bar.baz")

    describe ".unshiftAtKeyPath(keyPath, value)", ->
      it "unshifts the given value to the array at the key path and updates observers", ->
        @config.set("foo.bar.baz", ["b"])
        observeHandler = jasmine.createSpy "observeHandler"
        @config.observe "foo.bar.baz", observeHandler
        observeHandler.reset()

        expect(@config.unshiftAtKeyPath("foo.bar.baz", "a")).toBe 2
        expect(@config.get("foo.bar.baz")).toEqual ["a", "b"]
        expect(observeHandler).toHaveBeenCalledWith @config.get("foo.bar.baz")

    describe ".removeAtKeyPath(keyPath, value)", ->
      it "removes the given value from the array at the key path and updates observers", ->
        @config.set("foo.bar.baz", ["a", "b", "c"])
        observeHandler = jasmine.createSpy "observeHandler"
        @config.observe "foo.bar.baz", observeHandler
        observeHandler.reset()

        expect(@config.removeAtKeyPath("foo.bar.baz", "b")).toEqual ["a", "c"]
        expect(@config.get("foo.bar.baz")).toEqual ["a", "c"]
        expect(observeHandler).toHaveBeenCalledWith @config.get("foo.bar.baz")

    describe ".setDefaults(keyPath, defaults)", ->
      it "assigns any previously-unassigned keys to the object at the key path", ->
        @config.set("foo.bar.baz", a: 1)
        @config.setDefaults("foo.bar.baz", a: 2, b: 3, c: 4)
        expect(@config.get("foo.bar.baz.a")).toBe 1
        expect(@config.get("foo.bar.baz.b")).toBe 3
        expect(@config.get("foo.bar.baz.c")).toBe 4

        @config.setDefaults("foo.quux", x: 0, y: 1)
        expect(@config.get("foo.quux.x")).toBe 0
        expect(@config.get("foo.quux.y")).toBe 1

      it "emits an updated event", ->
        updatedCallback = jasmine.createSpy('updated')
        @config.onDidChange('foo.bar.baz.a', updatedCallback)
        expect(updatedCallback.callCount).toBe 0
        @config.setDefaults("foo.bar.baz", a: 2)
        expect(updatedCallback.callCount).toBe 1

    describe ".setSchema(keyPath, schema)", ->
      it 'creates a properly nested schema', ->
        schema =
          type: 'object'
          properties:
            anInt:
              type: 'integer'
              default: 12

        @config.setSchema('foo.bar', schema)

        expect(@config.getSchema('foo')).toEqual
          type: 'object'
          properties:
            bar:
              type: 'object'
              properties:
                anInt:
                  type: 'integer'
                  default: 12

      it 'sets defaults specified by the schema', ->
        schema =
          type: 'object'
          properties:
            anInt:
              type: 'integer'
              default: 12
            anObject:
              type: 'object'
              properties:
                nestedInt:
                  type: 'integer'
                  default: 24
                nestedObject:
                  type: 'object'
                  properties:
                    superNestedInt:
                      type: 'integer'
                      default: 36

        @config.setSchema('foo.bar', schema)
        expect(@config.get("foo.bar.anInt")).toBe 12
        expect(@config.get("foo.bar.anObject")).toEqual
          nestedInt: 24
          nestedObject:
            superNestedInt: 36

        expect(@config.get("foo")).toEqual {
          bar:
            anInt: 12
            anObject:
              nestedInt: 24
              nestedObject:
                superNestedInt: 36
        }
        @config.set("foo.bar.anObject.nestedObject.superNestedInt", 37)
        expect(@config.get("foo")).toEqual {
          bar:
            anInt: 12
            anObject:
              nestedInt: 24
              nestedObject:
                superNestedInt: 37
        }

      it 'can set a non-object schema', ->
        schema =
          type: 'integer'
          default: 12

        @config.setSchema('foo.bar.anInt', schema)
        expect(@config.get("foo.bar.anInt")).toBe 12
        expect(@config.getSchema('foo.bar.anInt')).toEqual
          type: 'integer'
          default: 12

      it "allows the schema to be retrieved via ::getSchema", ->
        schema =
          type: 'object'
          properties:
            anInt:
              type: 'integer'
              default: 12

        @config.setSchema('foo.bar', schema)

        expect(@config.getSchema('foo.bar')).toEqual
          type: 'object'
          properties:
            anInt:
              type: 'integer'
              default: 12

        expect(@config.getSchema('foo.bar.anInt')).toEqual
          type: 'integer'
          default: 12

        expect(@config.getSchema('foo.baz')).toEqual {type: 'any'}
        expect(@config.getSchema('foo.bar.anInt.baz')).toBe(null)

      it "respects the schema for scoped settings", ->
        schema =
          type: 'string'
          default: 'ok'
          scopes:
            '.source.js':
              default: 'omg'
        @config.setSchema('foo.bar.str', schema)

        expect(@config.get('foo.bar.str')).toBe 'ok'
        expect(@config.get('foo.bar.str', scope: ['.source.js'])).toBe 'omg'
        expect(@config.get('foo.bar.str', scope: ['.source.coffee'])).toBe 'ok'

      describe 'when a schema is added after config values have been set', ->
        schema = null
        beforeEach ->
          schema =
            type: 'object'
            properties:
              int:
                type: 'integer'
                default: 2
              str:
                type: 'string'
                default: 'def'

        it "respects the new schema when values are set", ->
          expect(@config.set('foo.bar.str', 'global')).toBe true
          expect(@config.set('foo.bar.str', 'scoped', scopeSelector: '.source.js')).toBe true
          expect(@config.get('foo.bar.str')).toBe 'global'
          expect(@config.get('foo.bar.str', scope: ['.source.js'])).toBe 'scoped'

          expect(@config.set('foo.bar.noschema', 'nsGlobal')).toBe true
          expect(@config.set('foo.bar.noschema', 'nsScoped', scopeSelector: '.source.js')).toBe true
          expect(@config.get('foo.bar.noschema')).toBe 'nsGlobal'
          expect(@config.get('foo.bar.noschema', scope: ['.source.js'])).toBe 'nsScoped'

          expect(@config.set('foo.bar.int', 'nope')).toBe true
          expect(@config.set('foo.bar.int', 'notanint', scopeSelector: '.source.js')).toBe true
          expect(@config.set('foo.bar.int', 23, scopeSelector: '.source.coffee')).toBe true
          expect(@config.get('foo.bar.int')).toBe 'nope'
          expect(@config.get('foo.bar.int', scope: ['.source.js'])).toBe 'notanint'
          expect(@config.get('foo.bar.int', scope: ['.source.coffee'])).toBe 23

          @config.setSchema('foo.bar', schema)

          expect(@config.get('foo.bar.str')).toBe 'global'
          expect(@config.get('foo.bar.str', scope: ['.source.js'])).toBe 'scoped'
          expect(@config.get('foo.bar.noschema')).toBe 'nsGlobal'
          expect(@config.get('foo.bar.noschema', scope: ['.source.js'])).toBe 'nsScoped'

          expect(@config.get('foo.bar.int')).toBe 2
          expect(@config.get('foo.bar.int', scope: ['.source.js'])).toBe 2
          expect(@config.get('foo.bar.int', scope: ['.source.coffee'])).toBe 23

        it "sets all values that adhere to the schema", ->
          expect(@config.set('foo.bar.int', 10)).toBe true
          expect(@config.set('foo.bar.int', 15, scopeSelector: '.source.js')).toBe true
          expect(@config.set('foo.bar.int', 23, scopeSelector: '.source.coffee')).toBe true
          expect(@config.get('foo.bar.int')).toBe 10
          expect(@config.get('foo.bar.int', scope: ['.source.js'])).toBe 15
          expect(@config.get('foo.bar.int', scope: ['.source.coffee'])).toBe 23

          @config.setSchema('foo.bar', schema)

          expect(@config.get('foo.bar.int')).toBe 10
          expect(@config.get('foo.bar.int', scope: ['.source.js'])).toBe 15
          expect(@config.get('foo.bar.int', scope: ['.source.coffee'])).toBe 23

      describe 'when the value has an "integer" type', ->
        beforeEach ->
          schema =
            type: 'integer'
            default: 12
          @config.setSchema('foo.bar.anInt', schema)

        it 'coerces a string to an int', ->
          @config.set('foo.bar.anInt', '123')
          expect(@config.get('foo.bar.anInt')).toBe 123

        it 'does not allow infinity', ->
          @config.set('foo.bar.anInt', Infinity)
          expect(@config.get('foo.bar.anInt')).toBe 12

        it 'coerces a float to an int', ->
          @config.set('foo.bar.anInt', 12.3)
          expect(@config.get('foo.bar.anInt')).toBe 12

        it 'will not set non-integers', ->
          @config.set('foo.bar.anInt', null)
          expect(@config.get('foo.bar.anInt')).toBe 12

          @config.set('foo.bar.anInt', 'nope')
          expect(@config.get('foo.bar.anInt')).toBe 12

        describe 'when the minimum and maximum keys are used', ->
          beforeEach ->
            schema =
              type: 'integer'
              minimum: 10
              maximum: 20
              default: 12
            @config.setSchema('foo.bar.anInt', schema)

          it 'keeps the specified value within the specified range', ->
            @config.set('foo.bar.anInt', '123')
            expect(@config.get('foo.bar.anInt')).toBe 20

            @config.set('foo.bar.anInt', '1')
            expect(@config.get('foo.bar.anInt')).toBe 10

      describe 'when the value has an "integer" and "string" type', ->
        beforeEach ->
          schema =
            type: ['integer', 'string']
            default: 12
          @config.setSchema('foo.bar.anInt', schema)

        it 'can coerce an int, and fallback to a string', ->
          @config.set('foo.bar.anInt', '123')
          expect(@config.get('foo.bar.anInt')).toBe 123

          @config.set('foo.bar.anInt', 'cats')
          expect(@config.get('foo.bar.anInt')).toBe 'cats'

      describe 'when the value has an "string" and "boolean" type', ->
        beforeEach ->
          schema =
            type: ['string', 'boolean']
            default: 'def'
          @config.setSchema('foo.bar', schema)

        it 'can set a string, a boolean, and revert back to the default', ->
          @config.set('foo.bar', 'ok')
          expect(@config.get('foo.bar')).toBe 'ok'

          @config.set('foo.bar', false)
          expect(@config.get('foo.bar')).toBe false

          @config.set('foo.bar', undefined)
          expect(@config.get('foo.bar')).toBe 'def'

      describe 'when the value has a "number" type', ->
        beforeEach ->
          schema =
            type: 'number'
            default: 12.1
          @config.setSchema('foo.bar.aFloat', schema)

        it 'coerces a string to a float', ->
          @config.set('foo.bar.aFloat', '12.23')
          expect(@config.get('foo.bar.aFloat')).toBe 12.23

        it 'will not set non-numbers', ->
          @config.set('foo.bar.aFloat', null)
          expect(@config.get('foo.bar.aFloat')).toBe 12.1

          @config.set('foo.bar.aFloat', 'nope')
          expect(@config.get('foo.bar.aFloat')).toBe 12.1

        describe 'when the minimum and maximum keys are used', ->
          beforeEach ->
            schema =
              type: 'number'
              minimum: 11.2
              maximum: 25.4
              default: 12.1
            @config.setSchema('foo.bar.aFloat', schema)

          it 'keeps the specified value within the specified range', ->
            @config.set('foo.bar.aFloat', '123.2')
            expect(@config.get('foo.bar.aFloat')).toBe 25.4

            @config.set('foo.bar.aFloat', '1.0')
            expect(@config.get('foo.bar.aFloat')).toBe 11.2

      describe 'when the value has a "boolean" type', ->
        beforeEach ->
          schema =
            type: 'boolean'
            default: true
          @config.setSchema('foo.bar.aBool', schema)

        it 'coerces various types to a boolean', ->
          @config.set('foo.bar.aBool', 'true')
          expect(@config.get('foo.bar.aBool')).toBe true
          @config.set('foo.bar.aBool', 'false')
          expect(@config.get('foo.bar.aBool')).toBe false
          @config.set('foo.bar.aBool', 'TRUE')
          expect(@config.get('foo.bar.aBool')).toBe true
          @config.set('foo.bar.aBool', 'FALSE')
          expect(@config.get('foo.bar.aBool')).toBe false
          @config.set('foo.bar.aBool', 1)
          expect(@config.get('foo.bar.aBool')).toBe false
          @config.set('foo.bar.aBool', 0)
          expect(@config.get('foo.bar.aBool')).toBe false
          @config.set('foo.bar.aBool', {})
          expect(@config.get('foo.bar.aBool')).toBe false
          @config.set('foo.bar.aBool', null)
          expect(@config.get('foo.bar.aBool')).toBe false

        it 'reverts back to the default value when undefined is passed to set', ->
          @config.set('foo.bar.aBool', 'false')
          expect(@config.get('foo.bar.aBool')).toBe false

          @config.set('foo.bar.aBool', undefined)
          expect(@config.get('foo.bar.aBool')).toBe true

      describe 'when the value has an "string" type', ->
        beforeEach ->
          schema =
            type: 'string'
            default: 'ok'
          @config.setSchema('foo.bar.aString', schema)

        it 'allows strings', ->
          @config.set('foo.bar.aString', 'yep')
          expect(@config.get('foo.bar.aString')).toBe 'yep'

        it 'will only set strings', ->
          expect(@config.set('foo.bar.aString', 123)).toBe false
          expect(@config.get('foo.bar.aString')).toBe 'ok'

          expect(@config.set('foo.bar.aString', true)).toBe false
          expect(@config.get('foo.bar.aString')).toBe 'ok'

          expect(@config.set('foo.bar.aString', null)).toBe false
          expect(@config.get('foo.bar.aString')).toBe 'ok'

          expect(@config.set('foo.bar.aString', [])).toBe false
          expect(@config.get('foo.bar.aString')).toBe 'ok'

          expect(@config.set('foo.bar.aString', nope: 'nope')).toBe false
          expect(@config.get('foo.bar.aString')).toBe 'ok'

        it 'does not allow setting children of that key-path', ->
          expect(@config.set('foo.bar.aString.something', 123)).toBe false
          expect(@config.get('foo.bar.aString')).toBe 'ok'

        describe 'when the schema has a "maximumLength" key', ->
          it "trims the string to be no longer than the specified maximum", ->
            schema =
              type: 'string'
              default: 'ok'
              maximumLength: 3
            @config.setSchema('foo.bar.aString', schema)
            @config.set('foo.bar.aString', 'abcdefg')
            expect(@config.get('foo.bar.aString')).toBe 'abc'

      describe 'when the value has an "object" type', ->
        beforeEach ->
          schema =
            type: 'object'
            properties:
              anInt:
                type: 'integer'
                default: 12
              nestedObject:
                type: 'object'
                properties:
                  nestedBool:
                    type: 'boolean'
                    default: false
          @config.setSchema('foo.bar', schema)

        it 'converts and validates all the children', ->
          @config.set 'foo.bar',
            anInt: '23'
            nestedObject:
              nestedBool: 'true'
          expect(@config.get('foo.bar')).toEqual
            anInt: 23
            nestedObject:
              nestedBool: true

        it 'will set only the values that adhere to the schema', ->
          expect(@config.set 'foo.bar',
            anInt: 'nope'
            nestedObject:
              nestedBool: true
          ).toBe true
          expect(@config.get('foo.bar.anInt')).toEqual 12
          expect(@config.get('foo.bar.nestedObject.nestedBool')).toEqual true

        describe "when the value has additionalProperties set to false", ->
          it 'does not allow other properties to be set on the object', ->
            @config.setSchema('foo.bar',
              type: 'object'
              properties:
                anInt:
                  type: 'integer'
                  default: 12
              additionalProperties: false
            )

            expect(@config.set('foo.bar', {anInt: 5, somethingElse: 'ok'})).toBe true
            expect(@config.get('foo.bar.anInt')).toBe 5
            expect(@config.get('foo.bar.somethingElse')).toBeUndefined()

            expect(@config.set('foo.bar.somethingElse', {anInt: 5})).toBe false
            expect(@config.get('foo.bar.somethingElse')).toBeUndefined()

        describe 'when the value has an additionalProperties schema', ->
          it 'validates properties of the object against that schema', ->
            @config.setSchema('foo.bar',
              type: 'object'
              properties:
                anInt:
                  type: 'integer'
                  default: 12
              additionalProperties:
                type: 'string'
            )

            expect(@config.set('foo.bar', {anInt: 5, somethingElse: 'ok'})).toBe true
            expect(@config.get('foo.bar.anInt')).toBe 5
            expect(@config.get('foo.bar.somethingElse')).toBe 'ok'

            expect(@config.set('foo.bar.somethingElse', 7)).toBe false
            expect(@config.get('foo.bar.somethingElse')).toBe 'ok'

            expect(@config.set('foo.bar', {anInt: 6, somethingElse: 7})).toBe true
            expect(@config.get('foo.bar.anInt')).toBe 6
            expect(@config.get('foo.bar.somethingElse')).toBe undefined

      describe 'when the value has an "array" type', ->
        beforeEach ->
          schema =
            type: 'array'
            default: [1, 2, 3]
            items:
              type: 'integer'
          @config.setSchema('foo.bar', schema)

        it 'converts an array of strings to an array of ints', ->
          @config.set 'foo.bar', ['2', '3', '4']
          expect(@config.get('foo.bar')).toEqual  [2, 3, 4]

        it 'does not allow setting children of that key-path', ->
          expect(@config.set('foo.bar.child', 123)).toBe false
          expect(@config.set('foo.bar.child.grandchild', 123)).toBe false
          expect(@config.get('foo.bar')).toEqual [1, 2, 3]

      describe 'when the value has a "color" type', ->
        beforeEach ->
          schema =
            type: 'color'
            default: 'white'
          @config.setSchema('foo.bar.aColor', schema)

        it 'returns a Color object', ->
          color = @config.get('foo.bar.aColor')
          expect(color.toHexString()).toBe '#ffffff'
          expect(color.toRGBAString()).toBe 'rgba(255, 255, 255, 1)'

          color.red = 0
          color.green = 0
          color.blue = 0
          color.alpha = 0
          @config.set('foo.bar.aColor', color)

          color = @config.get('foo.bar.aColor')
          expect(color.toHexString()).toBe '#000000'
          expect(color.toRGBAString()).toBe 'rgba(0, 0, 0, 0)'

          color.red = 300
          color.green = -200
          color.blue = -1
          color.alpha = 'not see through'
          @config.set('foo.bar.aColor', color)

          color = @config.get('foo.bar.aColor')
          expect(color.toHexString()).toBe '#ff0000'
          expect(color.toRGBAString()).toBe 'rgba(255, 0, 0, 1)'

          color.red = 11
          color.green = 11
          color.blue = 124
          color.alpha = 1
          @config.set('foo.bar.aColor', color)

          color = @config.get('foo.bar.aColor')
          expect(color.toHexString()).toBe '#0b0b7c'
          expect(color.toRGBAString()).toBe 'rgba(11, 11, 124, 1)'

        it 'coerces various types to a color object', ->
          @config.set('foo.bar.aColor', 'red')
          expect(@config.get('foo.bar.aColor')).toEqual {red: 255, green: 0, blue: 0, alpha: 1}
          @config.set('foo.bar.aColor', '#020')
          expect(@config.get('foo.bar.aColor')).toEqual {red: 0, green: 34, blue: 0, alpha: 1}
          @config.set('foo.bar.aColor', '#abcdef')
          expect(@config.get('foo.bar.aColor')).toEqual {red: 171, green: 205, blue: 239, alpha: 1}
          @config.set('foo.bar.aColor', 'rgb(1,2,3)')
          expect(@config.get('foo.bar.aColor')).toEqual {red: 1, green: 2, blue: 3, alpha: 1}
          @config.set('foo.bar.aColor', 'rgba(4,5,6,.7)')
          expect(@config.get('foo.bar.aColor')).toEqual {red: 4, green: 5, blue: 6, alpha: .7}
          @config.set('foo.bar.aColor', 'hsl(120,100%,50%)')
          expect(@config.get('foo.bar.aColor')).toEqual {red: 0, green: 255, blue: 0, alpha: 1}
          @config.set('foo.bar.aColor', 'hsla(120,100%,50%,0.3)')
          expect(@config.get('foo.bar.aColor')).toEqual {red: 0, green: 255, blue: 0, alpha: .3}
          @config.set('foo.bar.aColor', {red: 100, green: 255, blue: 2, alpha: .5})
          expect(@config.get('foo.bar.aColor')).toEqual {red: 100, green: 255, blue: 2, alpha: .5}
          @config.set('foo.bar.aColor', {red: 255})
          expect(@config.get('foo.bar.aColor')).toEqual {red: 255, green: 0, blue: 0, alpha: 1}
          @config.set('foo.bar.aColor', {red: 1000})
          expect(@config.get('foo.bar.aColor')).toEqual {red: 255, green: 0, blue: 0, alpha: 1}
          @config.set('foo.bar.aColor', {red: 'dark'})
          expect(@config.get('foo.bar.aColor')).toEqual {red: 0, green: 0, blue: 0, alpha: 1}

        it 'reverts back to the default value when undefined is passed to set', ->
          @config.set('foo.bar.aColor', undefined)
          expect(@config.get('foo.bar.aColor')).toEqual {red: 255, green: 255, blue: 255, alpha: 1}

        it 'will not set non-colors', ->
          @config.set('foo.bar.aColor', null)
          expect(@config.get('foo.bar.aColor')).toEqual {red: 255, green: 255, blue: 255, alpha: 1}

          @config.set('foo.bar.aColor', 'nope')
          expect(@config.get('foo.bar.aColor')).toEqual {red: 255, green: 255, blue: 255, alpha: 1}

          @config.set('foo.bar.aColor', 30)
          expect(@config.get('foo.bar.aColor')).toEqual {red: 255, green: 255, blue: 255, alpha: 1}

          @config.set('foo.bar.aColor', false)
          expect(@config.get('foo.bar.aColor')).toEqual {red: 255, green: 255, blue: 255, alpha: 1}

        it "returns a clone of the Color when returned in a parent object", ->
          color1 = @config.get('foo.bar').aColor
          color2 = @config.get('foo.bar').aColor
          expect(color1.toRGBAString()).toBe 'rgba(255, 255, 255, 1)'
          expect(color2.toRGBAString()).toBe 'rgba(255, 255, 255, 1)'
          expect(color1).not.toBe color2
          expect(color1).toEqual color2

      describe 'when the `enum` key is used', ->
        beforeEach ->
          schema =
            type: 'object'
            properties:
              str:
                type: 'string'
                default: 'ok'
                enum: ['ok', 'one', 'two']
              int:
                type: 'integer'
                default: 2
                enum: [2, 3, 5]
              arr:
                type: 'array'
                default: ['one', 'two']
                items:
                  type: 'string'
                  enum: ['one', 'two', 'three']
              str_options:
                type: 'string'
                default: 'one'
                enum: [
                  value: 'one', description: 'One'
                  'two',
                  value: 'three', description: 'Three'
                ]

          @config.setSchema('foo.bar', schema)

        it 'will only set a string when the string is in the enum values', ->
          expect(@config.set('foo.bar.str', 'nope')).toBe false
          expect(@config.get('foo.bar.str')).toBe 'ok'

          expect(@config.set('foo.bar.str', 'one')).toBe true
          expect(@config.get('foo.bar.str')).toBe 'one'

        it 'will only set an integer when the integer is in the enum values', ->
          expect(@config.set('foo.bar.int', '400')).toBe false
          expect(@config.get('foo.bar.int')).toBe 2

          expect(@config.set('foo.bar.int', '3')).toBe true
          expect(@config.get('foo.bar.int')).toBe 3

        it 'will only set an array when the array values are in the enum values', ->
          expect(@config.set('foo.bar.arr', ['one', 'five'])).toBe true
          expect(@config.get('foo.bar.arr')).toEqual ['one']

          expect(@config.set('foo.bar.arr', ['two', 'three'])).toBe true
          expect(@config.get('foo.bar.arr')).toEqual ['two', 'three']

        it 'will honor the enum when specified as an array', ->
          expect(@config.set('foo.bar.str_options', 'one')).toBe true
          expect(@config.get('foo.bar.str_options')).toEqual 'one'

          expect(@config.set('foo.bar.str_options', 'two')).toBe true
          expect(@config.get('foo.bar.str_options')).toEqual 'two'

          expect(@config.set('foo.bar.str_options', 'One')).toBe false
          expect(@config.get('foo.bar.str_options')).toEqual 'two'

  describe "when .set/.unset is called prior to .loadUserConfig", ->
    beforeEach ->
      @config.settingsLoaded = false
      fs.writeFileSync @config.configFilePath, """
        '*':
          foo:
            bar: 'baz'
          do:
            ray: 'me'
      """

    it "ensures that early set and unset calls are replayed after the config is loaded from disk", ->
      @config.unset 'foo.bar'
      @config.set 'foo.qux', 'boo'

      expect(@config.get('foo.bar')).toBeUndefined()
      expect(@config.get('foo.qux')).toBe 'boo'
      expect(@config.get('do.ray')).toBeUndefined()

      advanceClock 100
      expect(@config.save).not.toHaveBeenCalled()

      @config.loadUserConfig()

      advanceClock 100
      waitsFor -> @config.save.callCount > 0

      runs ->
        expect(@config.get('foo.bar')).toBeUndefined()
        expect(@config.get('foo.qux')).toBe 'boo'
        expect(@config.get('do.ray')).toBe 'me'
