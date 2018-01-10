path = require 'path'
temp = require('temp').track()
CSON = require 'season'
fs = require 'fs-plus'

describe "Config", ->
  dotAtomPath = null

  beforeEach ->
    spyOn(atom.config, "load")
    spyOn(atom.config, "save")
    spyOn(console, 'warn')
    dotAtomPath = temp.path('atom-spec-config')
    atom.config.configDirPath = dotAtomPath
    atom.config.enablePersistence = true
    atom.config.settingsLoaded = true
    atom.config.pendingOperations = []
    atom.config.configFilePath = path.join(atom.config.configDirPath, "atom.config.cson")

  afterEach ->
    atom.config.enablePersistence = false
    fs.removeSync(dotAtomPath)

  describe ".get(keyPath, {scope, sources, excludeSources})", ->
    it "allows a key path's value to be read", ->
      expect(atom.config.set("foo.bar.baz", 42)).toBe true
      expect(atom.config.get("foo.bar.baz")).toBe 42
      expect(atom.config.get("foo.quux")).toBeUndefined()

    it "returns a deep clone of the key path's value", ->
      atom.config.set('value', array: [1, b: 2, 3])
      retrievedValue = atom.config.get('value')
      retrievedValue.array[0] = 4
      retrievedValue.array[1].b = 2.1
      expect(atom.config.get('value')).toEqual(array: [1, b: 2, 3])

    it "merges defaults into the returned value if both the assigned value and the default value are objects", ->
      atom.config.setDefaults("foo.bar", baz: 1, ok: 2)
      atom.config.set("foo.bar", baz: 3)
      expect(atom.config.get("foo.bar")).toEqual {baz: 3, ok: 2}

      atom.config.setDefaults("other", baz: 1)
      atom.config.set("other", 7)
      expect(atom.config.get("other")).toBe 7

      atom.config.set("bar.baz", a: 3)
      atom.config.setDefaults("bar", baz: 7)
      expect(atom.config.get("bar.baz")).toEqual {a: 3}

    describe "when a 'sources' option is specified", ->
      it "only retrieves values from the specified sources", ->
        atom.config.set("x.y", 1, scopeSelector: ".foo", source: "a")
        atom.config.set("x.y", 2, scopeSelector: ".foo", source: "b")
        atom.config.set("x.y", 3, scopeSelector: ".foo", source: "c")
        atom.config.setSchema("x.y", type: "integer", default: 4)

        expect(atom.config.get("x.y", sources: ["a"], scope: [".foo"])).toBe 1
        expect(atom.config.get("x.y", sources: ["b"], scope: [".foo"])).toBe 2
        expect(atom.config.get("x.y", sources: ["c"], scope: [".foo"])).toBe 3
        # Schema defaults never match a specific source. We could potentially add a special "schema" source.
        expect(atom.config.get("x.y", sources: ["x"], scope: [".foo"])).toBeUndefined()

        expect(atom.config.get(null, sources: ['a'], scope: [".foo"]).x.y).toBe 1

    describe "when an 'excludeSources' option is specified", ->
      it "only retrieves values from the specified sources", ->
        atom.config.set("x.y", 0)
        atom.config.set("x.y", 1, scopeSelector: ".foo", source: "a")
        atom.config.set("x.y", 2, scopeSelector: ".foo", source: "b")
        atom.config.set("x.y", 3, scopeSelector: ".foo", source: "c")
        atom.config.setSchema("x.y", type: "integer", default: 4)

        expect(atom.config.get("x.y", excludeSources: ["a"], scope: [".foo"])).toBe 3
        expect(atom.config.get("x.y", excludeSources: ["c"], scope: [".foo"])).toBe 2
        expect(atom.config.get("x.y", excludeSources: ["b", "c"], scope: [".foo"])).toBe 1
        expect(atom.config.get("x.y", excludeSources: ["b", "c", "a"], scope: [".foo"])).toBe 0
        expect(atom.config.get("x.y", excludeSources: ["b", "c", "a", atom.config.getUserConfigPath()], scope: [".foo"])).toBe 4
        expect(atom.config.get("x.y", excludeSources: [atom.config.getUserConfigPath()])).toBe 4

    describe "when a 'scope' option is given", ->
      it "returns the property with the most specific scope selector", ->
        atom.config.set("foo.bar.baz", 42, scopeSelector: ".source.coffee .string.quoted.double.coffee")
        atom.config.set("foo.bar.baz", 22, scopeSelector: ".source .string.quoted.double")
        atom.config.set("foo.bar.baz", 11, scopeSelector: ".source")

        expect(atom.config.get("foo.bar.baz", scope: [".source.coffee", ".string.quoted.double.coffee"])).toBe 42
        expect(atom.config.get("foo.bar.baz", scope: [".source.js", ".string.quoted.double.js"])).toBe 22
        expect(atom.config.get("foo.bar.baz", scope: [".source.js", ".variable.assignment.js"])).toBe 11
        expect(atom.config.get("foo.bar.baz", scope: [".text"])).toBeUndefined()

      it "favors the most recently added properties in the event of a specificity tie", ->
        atom.config.set("foo.bar.baz", 42, scopeSelector: ".source.coffee .string.quoted.single")
        atom.config.set("foo.bar.baz", 22, scopeSelector: ".source.coffee .string.quoted.double")

        expect(atom.config.get("foo.bar.baz", scope: [".source.coffee", ".string.quoted.single"])).toBe 42
        expect(atom.config.get("foo.bar.baz", scope: [".source.coffee", ".string.quoted.single.double"])).toBe 22

      describe 'when there are global defaults', ->
        it 'falls back to the global when there is no scoped property specified', ->
          atom.config.setDefaults("foo", hasDefault: 'ok')
          expect(atom.config.get("foo.hasDefault", scope: [".source.coffee", ".string.quoted.single"])).toBe 'ok'

      describe 'when package settings are added after user settings', ->
        it "returns the user's setting because the user's setting has higher priority", ->
          atom.config.set("foo.bar.baz", 100, scopeSelector: ".source.coffee")
          atom.config.set("foo.bar.baz", 1, scopeSelector: ".source.coffee", source: "some-package")
          expect(atom.config.get("foo.bar.baz", scope: [".source.coffee"])).toBe 100

      describe "when the first component of the scope descriptor matches a legacy scope alias", ->
        it "falls back to properties defined for the legacy scope if no value is found for the original scope descriptor", ->
          atom.config.addLegacyScopeAlias('javascript', '.source.js')
          atom.config.set('foo', 100, scopeSelector: '.source.js')
          atom.config.set('foo', 200, scopeSelector: 'javascript for_statement')

          expect(atom.config.get('foo', scope: ['javascript', 'for_statement', 'identifier'])).toBe(200)
          expect(atom.config.get('foo', scope: ['javascript', 'function', 'identifier'])).toBe(100)

  describe ".getAll(keyPath, {scope, sources, excludeSources})", ->
    it "reads all of the values for a given key-path", ->
      expect(atom.config.set("foo", 41)).toBe true
      expect(atom.config.set("foo", 43, scopeSelector: ".a .b")).toBe true
      expect(atom.config.set("foo", 42, scopeSelector: ".a")).toBe true
      expect(atom.config.set("foo", 44, scopeSelector: ".a .b.c")).toBe true

      expect(atom.config.set("foo", -44, scopeSelector: ".d")).toBe true

      expect(atom.config.getAll("foo", scope: [".a", ".b.c"])).toEqual [
        {scopeSelector: '.a .b.c', value: 44}
        {scopeSelector: '.a .b', value: 43}
        {scopeSelector: '.a', value: 42}
        {scopeSelector: '*', value: 41}
      ]

    it "includes the schema's default value", ->
      atom.config.setSchema("foo", type: 'number', default: 40)
      expect(atom.config.set("foo", 43, scopeSelector: ".a .b")).toBe true
      expect(atom.config.getAll("foo", scope: [".a", ".b.c"])).toEqual [
        {scopeSelector: '.a .b', value: 43}
        {scopeSelector: '*', value: 40}
      ]

    describe "when the first component of the scope descriptor matches a legacy scope alias", ->
      it "includes the values defined for the legacy scope", ->
        atom.config.addLegacyScopeAlias('javascript', '.source.js')

        expect(atom.config.set('foo', 41)).toBe true
        expect(atom.config.set('foo', 42, scopeSelector: 'javascript')).toBe true
        expect(atom.config.set('foo', 43, scopeSelector: '.source.js')).toBe true

        expect(atom.config.getAll('foo', scope: ['javascript'])).toEqual([
          {scopeSelector: 'javascript', value: 42},
          {scopeSelector: '.js.source', value: 43},
          {scopeSelector: '*', value: 41}
        ])

  describe ".set(keyPath, value, {source, scopeSelector})", ->
    it "allows a key path's value to be written", ->
      expect(atom.config.set("foo.bar.baz", 42)).toBe true
      expect(atom.config.get("foo.bar.baz")).toBe 42

    it "saves the user's config to disk after it stops changing", ->
      atom.config.set("foo.bar.baz", 42)
      advanceClock(50)
      expect(atom.config.save).not.toHaveBeenCalled()
      atom.config.set("foo.bar.baz", 43)
      advanceClock(50)
      expect(atom.config.save).not.toHaveBeenCalled()
      atom.config.set("foo.bar.baz", 44)
      advanceClock(150)
      expect(atom.config.save).toHaveBeenCalled()

    it "does not save when a non-default 'source' is given", ->
      atom.config.set("foo.bar.baz", 42, source: 'some-other-source', scopeSelector: '.a')
      advanceClock(500)
      expect(atom.config.save).not.toHaveBeenCalled()

    it "does not allow a 'source' option without a 'scopeSelector'", ->
      expect(-> atom.config.set("foo", 1, source: [".source.ruby"])).toThrow()

    describe "when the key-path is null", ->
      it "sets the root object", ->
        expect(atom.config.set(null, editor: tabLength: 6)).toBe true
        expect(atom.config.get("editor.tabLength")).toBe 6
        expect(atom.config.set(null, editor: tabLength: 8, scopeSelector: ['.source.js'])).toBe true
        expect(atom.config.get("editor.tabLength", scope: ['.source.js'])).toBe 8

    describe "when the value equals the default value", ->
      it "does not store the value in the user's config", ->
        atom.config.setSchema "foo",
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
        expect(atom.config.settings.foo).toBeUndefined()

        atom.config.set('foo.same', 1)
        atom.config.set('foo.changes', 2)
        atom.config.set('foo.sameArray', [1, 2, 3])
        atom.config.set('foo.null', undefined)
        atom.config.set('foo.undefined', null)
        atom.config.set('foo.sameObject', {b: 2, a: 1})

        userConfigPath = atom.config.getUserConfigPath()

        expect(atom.config.get("foo.same", sources: [userConfigPath])).toBeUndefined()

        expect(atom.config.get("foo.changes")).toBe 2
        expect(atom.config.get("foo.changes", sources: [userConfigPath])).toBe 2

        atom.config.set('foo.changes', 1)
        expect(atom.config.get("foo.changes", sources: [userConfigPath])).toBeUndefined()

    describe "when a 'scopeSelector' is given", ->
      it "sets the value and overrides the others", ->
        atom.config.set("foo.bar.baz", 42, scopeSelector: ".source.coffee .string.quoted.double.coffee")
        atom.config.set("foo.bar.baz", 22, scopeSelector: ".source .string.quoted.double")
        atom.config.set("foo.bar.baz", 11, scopeSelector: ".source")

        expect(atom.config.get("foo.bar.baz", scope: [".source.coffee", ".string.quoted.double.coffee"])).toBe 42

        expect(atom.config.set("foo.bar.baz", 100, scopeSelector: ".source.coffee .string.quoted.double.coffee")).toBe true
        expect(atom.config.get("foo.bar.baz", scope: [".source.coffee", ".string.quoted.double.coffee"])).toBe 100

  describe ".unset(keyPath, {source, scopeSelector})", ->
    beforeEach ->
      atom.config.setSchema 'foo',
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
      atom.config.setDefaults('a', b: 3)
      atom.config.set('a.b', 4)
      expect(atom.config.get('a.b')).toBe 4
      atom.config.unset('a.b')
      expect(atom.config.get('a.b')).toBe 3

      atom.config.set('a.c', 5)
      expect(atom.config.get('a.c')).toBe 5
      atom.config.unset('a.c')
      expect(atom.config.get('a.c')).toBeUndefined()

    it "calls ::save()", ->
      atom.config.setDefaults('a', b: 3)
      atom.config.set('a.b', 4)
      atom.config.save.reset()

      atom.config.unset('a.c')
      advanceClock(500)
      expect(atom.config.save.callCount).toBe 1

    describe "when no 'scopeSelector' is given", ->
      describe "when a 'source' but no key-path is given", ->
        it "removes all scoped settings with the given source", ->
          atom.config.set("foo.bar.baz", 1, scopeSelector: ".a", source: "source-a")
          atom.config.set("foo.bar.quux", 2, scopeSelector: ".b", source: "source-a")
          expect(atom.config.get("foo.bar", scope: [".a.b"])).toEqual(baz: 1, quux: 2)

          atom.config.unset(null, source: "source-a")
          expect(atom.config.get("foo.bar", scope: [".a"])).toEqual(baz: 0, ok: 0)

      describe "when a 'source' and a key-path is given", ->
        it "removes all scoped settings with the given source and key-path", ->
          atom.config.set("foo.bar.baz", 1)
          atom.config.set("foo.bar.baz", 2, scopeSelector: ".a", source: "source-a")
          atom.config.set("foo.bar.baz", 3, scopeSelector: ".a.b", source: "source-b")
          expect(atom.config.get("foo.bar.baz", scope: [".a.b"])).toEqual(3)

          atom.config.unset("foo.bar.baz", source: "source-b")
          expect(atom.config.get("foo.bar.baz", scope: [".a.b"])).toEqual(2)
          expect(atom.config.get("foo.bar.baz")).toEqual(1)

      describe "when no 'source' is given", ->
        it "removes all scoped and unscoped properties for that key-path", ->
          atom.config.setDefaults("foo.bar", baz: 100)

          atom.config.set("foo.bar", {baz: 1, ok: 2}, scopeSelector: ".a")
          atom.config.set("foo.bar", {baz: 11, ok: 12}, scopeSelector: ".b")
          atom.config.set("foo.bar", {baz: 21, ok: 22})

          atom.config.unset("foo.bar.baz")

          expect(atom.config.get("foo.bar.baz", scope: [".a"])).toBe 100
          expect(atom.config.get("foo.bar.baz", scope: [".b"])).toBe 100
          expect(atom.config.get("foo.bar.baz")).toBe 100

          expect(atom.config.get("foo.bar.ok", scope: [".a"])).toBe 2
          expect(atom.config.get("foo.bar.ok", scope: [".b"])).toBe 12
          expect(atom.config.get("foo.bar.ok")).toBe 22

    describe "when a 'scopeSelector' is given", ->
      it "restores the global default when no scoped default set", ->
        atom.config.setDefaults("foo", bar: baz: 10)
        atom.config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee')
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 55

        atom.config.unset('foo.bar.baz', scopeSelector: '.source.coffee')
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 10

      it "restores the scoped default when a scoped default is set", ->
        atom.config.setDefaults("foo", bar: baz: 10)
        atom.config.set("foo.bar.baz", 42, scopeSelector: ".source.coffee", source: "some-source")
        atom.config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee')
        atom.config.set('foo.bar.ok', 100, scopeSelector: '.source.coffee')
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 55

        atom.config.unset('foo.bar.baz', scopeSelector: '.source.coffee')
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 42
        expect(atom.config.get('foo.bar.ok', scope: ['.source.coffee'])).toBe 100

      it "calls ::save()", ->
        atom.config.setDefaults("foo", bar: baz: 10)
        atom.config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee')
        atom.config.save.reset()

        atom.config.unset('foo.bar.baz', scopeSelector: '.source.coffee')
        advanceClock(150)
        expect(atom.config.save.callCount).toBe 1

      it "allows removing settings for a specific source and scope selector", ->
        atom.config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee', source: "source-a")
        atom.config.set('foo.bar.baz', 65, scopeSelector: '.source.coffee', source: "source-b")
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 65

        atom.config.unset('foo.bar.baz', source: "source-b", scopeSelector: ".source.coffee")
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee', '.string'])).toBe 55

      it "allows removing all settings for a specific source", ->
        atom.config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee', source: "source-a")
        atom.config.set('foo.bar.baz', 65, scopeSelector: '.source.coffee', source: "source-b")
        atom.config.set('foo.bar.ok', 65, scopeSelector: '.source.coffee', source: "source-b")
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 65

        atom.config.unset(null, source: "source-b", scopeSelector: ".source.coffee")
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee', '.string'])).toBe 55
        expect(atom.config.get('foo.bar.ok', scope: ['.source.coffee', '.string'])).toBe 0

      it "does not call ::save or add a scoped property when no value has been set", ->
        # see https://github.com/atom/atom/issues/4175
        atom.config.setDefaults("foo", bar: baz: 10)
        atom.config.unset('foo.bar.baz', scopeSelector: '.source.coffee')
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 10

        expect(atom.config.save).not.toHaveBeenCalled()

        scopedProperties = atom.config.scopedSettingsStore.propertiesForSource('user-config')
        expect(scopedProperties['.coffee.source']).toBeUndefined()

      it "removes the scoped value when it was the only set value on the object", ->
        spyOn(CSON, 'writeFileSync')
        atom.config.save.andCallThrough()

        atom.config.setDefaults("foo", bar: baz: 10)
        atom.config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee')
        atom.config.set('foo.bar.ok', 20, scopeSelector: '.source.coffee')
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 55

        advanceClock(150)
        CSON.writeFileSync.reset()

        atom.config.unset('foo.bar.baz', scopeSelector: '.source.coffee')
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 10
        expect(atom.config.get('foo.bar.ok', scope: ['.source.coffee'])).toBe 20

        advanceClock(150)
        expect(CSON.writeFileSync).toHaveBeenCalled()
        properties = CSON.writeFileSync.mostRecentCall.args[1]
        expect(properties['.coffee.source']).toEqual
          foo:
            bar:
              ok: 20
        CSON.writeFileSync.reset()

        atom.config.unset('foo.bar.ok', scopeSelector: '.source.coffee')

        advanceClock(150)
        expect(CSON.writeFileSync).toHaveBeenCalled()
        properties = CSON.writeFileSync.mostRecentCall.args[1]
        expect(properties['.coffee.source']).toBeUndefined()

      it "does not call ::save when the value is already at the default", ->
        atom.config.setDefaults("foo", bar: baz: 10)
        atom.config.set('foo.bar.baz', 55)
        atom.config.save.reset()

        atom.config.unset('foo.bar.ok', scopeSelector: '.source.coffee')
        expect(atom.config.save).not.toHaveBeenCalled()
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 55

  describe ".onDidChange(keyPath, {scope})", ->
    [observeHandler, observeSubscription] = []

    describe 'when a keyPath is specified', ->
      beforeEach ->
        observeHandler = jasmine.createSpy("observeHandler")
        atom.config.set("foo.bar.baz", "value 1")
        observeSubscription = atom.config.onDidChange "foo.bar.baz", observeHandler

      it "does not fire the given callback with the current value at the keypath", ->
        expect(observeHandler).not.toHaveBeenCalled()

      it "fires the callback every time the observed value changes", ->
        atom.config.set('foo.bar.baz', "value 2")
        expect(observeHandler).toHaveBeenCalledWith({newValue: 'value 2', oldValue: 'value 1'})
        observeHandler.reset()

        observeHandler.andCallFake -> throw new Error("oops")
        expect(-> atom.config.set('foo.bar.baz', "value 1")).toThrow("oops")
        expect(observeHandler).toHaveBeenCalledWith({newValue: 'value 1', oldValue: 'value 2'})
        observeHandler.reset()

        # Regression: exception in earlier handler shouldn't put observer
        # into a bad state.
        atom.config.set('something.else', "new value")
        expect(observeHandler).not.toHaveBeenCalled()

    describe 'when a keyPath is not specified', ->
      beforeEach ->
        observeHandler = jasmine.createSpy("observeHandler")
        atom.config.set("foo.bar.baz", "value 1")
        observeSubscription = atom.config.onDidChange observeHandler

      it "does not fire the given callback initially", ->
        expect(observeHandler).not.toHaveBeenCalled()

      it "fires the callback every time any value changes", ->
        observeHandler.reset() # clear the initial call
        atom.config.set('foo.bar.baz', "value 2")
        expect(observeHandler).toHaveBeenCalled()
        expect(observeHandler.mostRecentCall.args[0].newValue.foo.bar.baz).toBe("value 2")
        expect(observeHandler.mostRecentCall.args[0].oldValue.foo.bar.baz).toBe("value 1")

        observeHandler.reset()
        atom.config.set('foo.bar.baz', "value 1")
        expect(observeHandler).toHaveBeenCalled()
        expect(observeHandler.mostRecentCall.args[0].newValue.foo.bar.baz).toBe("value 1")
        expect(observeHandler.mostRecentCall.args[0].oldValue.foo.bar.baz).toBe("value 2")

        observeHandler.reset()
        atom.config.set('foo.bar.int', 1)
        expect(observeHandler).toHaveBeenCalled()
        expect(observeHandler.mostRecentCall.args[0].newValue.foo.bar.int).toBe(1)
        expect(observeHandler.mostRecentCall.args[0].oldValue.foo.bar.int).toBe(undefined)

    describe "when a 'scope' is given", ->
      it 'calls the supplied callback when the value at the descriptor/keypath changes', ->
        changeSpy = jasmine.createSpy('onDidChange callback')
        atom.config.onDidChange "foo.bar.baz", scope: [".source.coffee", ".string.quoted.double.coffee"], changeSpy

        atom.config.set("foo.bar.baz", 12)
        expect(changeSpy).toHaveBeenCalledWith({oldValue: undefined, newValue: 12})
        changeSpy.reset()

        atom.config.set("foo.bar.baz", 22, scopeSelector: ".source .string.quoted.double", source: "a")
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 12, newValue: 22})
        changeSpy.reset()

        atom.config.set("foo.bar.baz", 42, scopeSelector: ".source.coffee .string.quoted.double.coffee", source: "b")
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 22, newValue: 42})
        changeSpy.reset()

        atom.config.unset(null, scopeSelector: ".source.coffee .string.quoted.double.coffee", source: "b")
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 42, newValue: 22})
        changeSpy.reset()

        atom.config.unset(null, scopeSelector: ".source .string.quoted.double", source: "a")
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 22, newValue: 12})
        changeSpy.reset()

        atom.config.set("foo.bar.baz", undefined)
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 12, newValue: undefined})
        changeSpy.reset()

  describe ".observe(keyPath, {scope})", ->
    [observeHandler, observeSubscription] = []

    beforeEach ->
      observeHandler = jasmine.createSpy("observeHandler")
      atom.config.set("foo.bar.baz", "value 1")
      observeSubscription = atom.config.observe("foo.bar.baz", observeHandler)

    it "fires the given callback with the current value at the keypath", ->
      expect(observeHandler).toHaveBeenCalledWith("value 1")

    it "fires the callback every time the observed value changes", ->
      observeHandler.reset() # clear the initial call
      atom.config.set('foo.bar.baz', "value 2")
      expect(observeHandler).toHaveBeenCalledWith("value 2")

      observeHandler.reset()
      atom.config.set('foo.bar.baz', "value 1")
      expect(observeHandler).toHaveBeenCalledWith("value 1")
      advanceClock(100) # complete pending save that was requested in ::set

      observeHandler.reset()
      atom.config.loadUserConfig()
      expect(observeHandler).toHaveBeenCalledWith(undefined)

    it "fires the callback when the observed value is deleted", ->
      observeHandler.reset() # clear the initial call
      atom.config.set('foo.bar.baz', undefined)
      expect(observeHandler).toHaveBeenCalledWith(undefined)

    it "fires the callback when the full key path goes into and out of existence", ->
      observeHandler.reset() # clear the initial call
      atom.config.set("foo.bar", undefined)
      expect(observeHandler).toHaveBeenCalledWith(undefined)

      observeHandler.reset()
      atom.config.set("foo.bar.baz", "i'm back")
      expect(observeHandler).toHaveBeenCalledWith("i'm back")

    it "does not fire the callback once the subscription is disposed", ->
      observeHandler.reset() # clear the initial call
      observeSubscription.dispose()
      atom.config.set('foo.bar.baz', "value 2")
      expect(observeHandler).not.toHaveBeenCalled()

    it 'does not fire the callback for a similarly named keyPath', ->
      bazCatHandler = jasmine.createSpy("bazCatHandler")
      observeSubscription = atom.config.observe "foo.bar.bazCat", bazCatHandler

      bazCatHandler.reset()
      atom.config.set('foo.bar.baz', "value 10")
      expect(bazCatHandler).not.toHaveBeenCalled()

    describe "when a 'scope' is given", ->
      otherHandler = null

      beforeEach ->
        observeSubscription.dispose()
        otherHandler = jasmine.createSpy('otherHandler')

      it "allows settings to be observed in a specific scope", ->
        atom.config.observe("foo.bar.baz", scope: [".some.scope"], observeHandler)
        atom.config.observe("foo.bar.baz", scope: [".another.scope"], otherHandler)

        atom.config.set('foo.bar.baz', "value 2", scopeSelector: ".some")
        expect(observeHandler).toHaveBeenCalledWith("value 2")
        expect(otherHandler).not.toHaveBeenCalledWith("value 2")

      it 'calls the callback when properties with more specific selectors are removed', ->
        changeSpy = jasmine.createSpy()
        atom.config.observe("foo.bar.baz", scope: [".source.coffee", ".string.quoted.double.coffee"], changeSpy)
        expect(changeSpy).toHaveBeenCalledWith("value 1")
        changeSpy.reset()

        atom.config.set("foo.bar.baz", 12)
        expect(changeSpy).toHaveBeenCalledWith(12)
        changeSpy.reset()

        atom.config.set("foo.bar.baz", 22, scopeSelector: ".source .string.quoted.double", source: "a")
        expect(changeSpy).toHaveBeenCalledWith(22)
        changeSpy.reset()

        atom.config.set("foo.bar.baz", 42, scopeSelector: ".source.coffee .string.quoted.double.coffee", source: "b")
        expect(changeSpy).toHaveBeenCalledWith(42)
        changeSpy.reset()

        atom.config.unset(null, scopeSelector: ".source.coffee .string.quoted.double.coffee", source: "b")
        expect(changeSpy).toHaveBeenCalledWith(22)
        changeSpy.reset()

        atom.config.unset(null, scopeSelector: ".source .string.quoted.double", source: "a")
        expect(changeSpy).toHaveBeenCalledWith(12)
        changeSpy.reset()

        atom.config.set("foo.bar.baz", undefined)
        expect(changeSpy).toHaveBeenCalledWith(undefined)
        changeSpy.reset()

  describe ".transact(callback)", ->
    changeSpy = null

    beforeEach ->
      changeSpy = jasmine.createSpy('onDidChange callback')
      atom.config.onDidChange("foo.bar.baz", changeSpy)

    it "allows only one change event for the duration of the given callback", ->
      atom.config.transact ->
        atom.config.set("foo.bar.baz", 1)
        atom.config.set("foo.bar.baz", 2)
        atom.config.set("foo.bar.baz", 3)

      expect(changeSpy.callCount).toBe(1)
      expect(changeSpy.argsForCall[0][0]).toEqual(newValue: 3, oldValue: undefined)

    it "does not emit an event if no changes occur while paused", ->
      atom.config.transact ->
      expect(changeSpy).not.toHaveBeenCalled()

  describe ".transactAsync(callback)", ->
    changeSpy = null

    beforeEach ->
      changeSpy = jasmine.createSpy('onDidChange callback')
      atom.config.onDidChange("foo.bar.baz", changeSpy)

    it "allows only one change event for the duration of the given promise if it gets resolved", ->
      promiseResult = null
      transactionPromise = atom.config.transactAsync ->
        atom.config.set("foo.bar.baz", 1)
        atom.config.set("foo.bar.baz", 2)
        atom.config.set("foo.bar.baz", 3)
        Promise.resolve("a result")

      waitsForPromise -> transactionPromise.then (r) -> promiseResult = r

      runs ->
        expect(promiseResult).toBe("a result")
        expect(changeSpy.callCount).toBe(1)
        expect(changeSpy.argsForCall[0][0]).toEqual(newValue: 3, oldValue: undefined)

    it "allows only one change event for the duration of the given promise if it gets rejected", ->
      promiseError = null
      transactionPromise = atom.config.transactAsync ->
        atom.config.set("foo.bar.baz", 1)
        atom.config.set("foo.bar.baz", 2)
        atom.config.set("foo.bar.baz", 3)
        Promise.reject("an error")

      waitsForPromise -> transactionPromise.catch (e) -> promiseError = e

      runs ->
        expect(promiseError).toBe("an error")
        expect(changeSpy.callCount).toBe(1)
        expect(changeSpy.argsForCall[0][0]).toEqual(newValue: 3, oldValue: undefined)

    it "allows only one change event even when the given callback throws", ->
      error = new Error("Oops!")
      promiseError = null
      transactionPromise = atom.config.transactAsync ->
        atom.config.set("foo.bar.baz", 1)
        atom.config.set("foo.bar.baz", 2)
        atom.config.set("foo.bar.baz", 3)
        throw error

      waitsForPromise -> transactionPromise.catch (e) -> promiseError = e

      runs ->
        expect(promiseError).toBe(error)
        expect(changeSpy.callCount).toBe(1)
        expect(changeSpy.argsForCall[0][0]).toEqual(newValue: 3, oldValue: undefined)

  describe ".getSources()", ->
    it "returns an array of all of the config's source names", ->
      expect(atom.config.getSources()).toEqual([])

      atom.config.set("a.b", 1, scopeSelector: ".x1", source: "source-1")
      atom.config.set("a.c", 1, scopeSelector: ".x1", source: "source-1")
      atom.config.set("a.b", 2, scopeSelector: ".x2", source: "source-2")
      atom.config.set("a.b", 1, scopeSelector: ".x3", source: "source-3")

      expect(atom.config.getSources()).toEqual([
        "source-1"
        "source-2"
        "source-3"
      ])

  describe "Internal Methods", ->
    describe ".save()", ->
      CSON = require 'season'

      beforeEach ->
        spyOn(CSON, 'writeFileSync')
        jasmine.unspy atom.config, 'save'

      describe "when ~/.atom/config.json exists", ->
        it "writes any non-default properties to ~/.atom/config.json", ->
          atom.config.set("a.b.c", 1)
          atom.config.set("a.b.d", 2)
          atom.config.set("x.y.z", 3)
          atom.config.setDefaults("a.b", e: 4, f: 5)

          CSON.writeFileSync.reset()
          atom.config.save()

          expect(CSON.writeFileSync.argsForCall[0][0]).toBe atom.config.configFilePath
          writtenConfig = CSON.writeFileSync.argsForCall[0][1]
          expect(writtenConfig).toEqual '*': atom.config.settings

        it 'writes properties in alphabetical order', ->
          atom.config.set('foo', 1)
          atom.config.set('bar', 2)
          atom.config.set('baz.foo', 3)
          atom.config.set('baz.bar', 4)

          CSON.writeFileSync.reset()
          atom.config.save()

          expect(CSON.writeFileSync.argsForCall[0][0]).toBe atom.config.configFilePath
          writtenConfig = CSON.writeFileSync.argsForCall[0][1]
          expect(writtenConfig).toEqual '*': atom.config.settings

          expectedKeys = ['bar', 'baz', 'foo']
          foundKeys = (key for key of writtenConfig['*'] when key in expectedKeys)
          expect(foundKeys).toEqual expectedKeys
          expectedKeys = ['bar', 'foo']
          foundKeys = (key for key of writtenConfig['*']['baz'] when key in expectedKeys)
          expect(foundKeys).toEqual expectedKeys

      describe "when ~/.atom/config.json doesn't exist", ->
        it "writes any non-default properties to ~/.atom/config.cson", ->
          atom.config.set("a.b.c", 1)
          atom.config.set("a.b.d", 2)
          atom.config.set("x.y.z", 3)
          atom.config.setDefaults("a.b", e: 4, f: 5)

          CSON.writeFileSync.reset()
          atom.config.save()

          expect(CSON.writeFileSync.argsForCall[0][0]).toBe path.join(atom.config.configDirPath, "atom.config.cson")
          writtenConfig = CSON.writeFileSync.argsForCall[0][1]
          expect(writtenConfig).toEqual '*': atom.config.settings

      describe "when scoped settings are defined", ->
        it 'writes out explicitly set config settings', ->
          atom.config.set('foo.bar', 'ruby', scopeSelector: '.source.ruby')
          atom.config.set('foo.omg', 'wow', scopeSelector: '.source.ruby')
          atom.config.set('foo.bar', 'coffee', scopeSelector: '.source.coffee')

          CSON.writeFileSync.reset()
          atom.config.save()

          writtenConfig = CSON.writeFileSync.argsForCall[0][1]
          expect(writtenConfig).toEqualJson
            '*':
              atom.config.settings
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
            error.path = atom.config.getUserConfigPath()
            throw error

          save = -> atom.config.save()
          expect(save).not.toThrow()
          expect(addErrorHandler.callCount).toBe 1

    describe ".loadUserConfig()", ->
      beforeEach ->
        expect(fs.existsSync(atom.config.configDirPath)).toBeFalsy()
        atom.config.setSchema 'foo',
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
          fs.writeFileSync atom.config.configFilePath, """
            '*':
              foo:
                bar: 'baz'

            '.source.ruby':
              foo:
                bar: 'more-specific'
          """
          atom.config.loadUserConfig()

        it "updates the config data based on the file contents", ->
          expect(atom.config.get("foo.bar")).toBe 'baz'
          expect(atom.config.get("foo.bar", scope: ['.source.ruby'])).toBe 'more-specific'

      describe "when the config file does not conform to the schema", ->
        beforeEach ->
          fs.writeFileSync atom.config.configFilePath, """
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
          atom.config.loadUserConfig()
          expect(atom.config.get("foo.int")).toBe 12
          expect(atom.config.get("foo.bar")).toBe 'omg'
          expect(atom.config.get("foo.int", scope: ['.source.ruby'])).toBe 12
          expect(atom.config.get("foo.bar", scope: ['.source.ruby'])).toBe 'scoped'

      describe "when the config file contains valid cson", ->
        beforeEach ->
          fs.writeFileSync(atom.config.configFilePath, "foo: bar: 'baz'")

        it "updates the config data based on the file contents", ->
          atom.config.loadUserConfig()
          expect(atom.config.get("foo.bar")).toBe 'baz'

        it "notifies observers for updated keypaths on load", ->
          observeHandler = jasmine.createSpy("observeHandler")
          observeSubscription = atom.config.observe "foo.bar", observeHandler

          atom.config.loadUserConfig()

          expect(observeHandler).toHaveBeenCalledWith 'baz'

      describe "when the config file contains invalid cson", ->
        addErrorHandler = null
        beforeEach ->
          atom.notifications.onDidAddNotification addErrorHandler = jasmine.createSpy()
          fs.writeFileSync(atom.config.configFilePath, "{{{{{")

        it "logs an error to the console and does not overwrite the config file on a subsequent save", ->
          atom.config.loadUserConfig()
          expect(addErrorHandler.callCount).toBe 1
          atom.config.set("hair", "blonde") # trigger a save
          expect(atom.config.save).not.toHaveBeenCalled()

      describe "when the config file does not exist", ->
        it "creates it with an empty object", ->
          fs.makeTreeSync(atom.config.configDirPath)
          atom.config.loadUserConfig()
          expect(fs.existsSync(atom.config.configFilePath)).toBe true
          expect(CSON.readFileSync(atom.config.configFilePath)).toEqual {}

      describe "when the config file contains values that do not adhere to the schema", ->
        beforeEach ->
          fs.writeFileSync atom.config.configFilePath, """
            foo:
              bar: 'baz'
              int: 'bad value'
          """
          atom.config.loadUserConfig()

        it "updates the only the settings that have values matching the schema", ->
          expect(atom.config.get("foo.bar")).toBe 'baz'
          expect(atom.config.get("foo.int")).toBe 12

          expect(console.warn).toHaveBeenCalled()
          expect(console.warn.mostRecentCall.args[0]).toContain "foo.int"

      describe "when there is a pending save", ->
        it "does not change the config settings", ->
          fs.writeFileSync atom.config.configFilePath, "'*': foo: bar: 'baz'"

          atom.config.set("foo.bar", "quux")
          atom.config.loadUserConfig()
          expect(atom.config.get("foo.bar")).toBe "quux"

          advanceClock(100)
          expect(atom.config.save.callCount).toBe 1

          expect(atom.config.get("foo.bar")).toBe "quux"
          atom.config.loadUserConfig()
          expect(atom.config.get("foo.bar")).toBe "baz"

      describe "when the config file fails to load", ->
        addErrorHandler = null

        beforeEach ->
          atom.notifications.onDidAddNotification addErrorHandler = jasmine.createSpy()
          spyOn(fs, "makeTreeSync").andCallFake ->
            error = new Error()
            error.code = 'EPERM'
            throw error

        it "creates a notification and does not try to save later changes to disk", ->
          load = -> atom.config.loadUserConfig()
          expect(load).not.toThrow()
          expect(addErrorHandler.callCount).toBe 1

          atom.config.set("foo.bar", "baz")
          advanceClock(100)
          expect(atom.config.save).not.toHaveBeenCalled()
          expect(atom.config.get("foo.bar")).toBe "baz"

    describe ".observeUserConfig()", ->
      updatedHandler = null

      writeConfigFile = (data, secondsInFuture = 0) ->
        fs.writeFileSync(atom.config.configFilePath, data)

        future = (Date.now() / 1000) + secondsInFuture
        fs.utimesSync(atom.config.configFilePath, future, future)

      beforeEach ->
        jasmine.useRealClock()

        atom.config.setSchema 'foo',
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

        expect(fs.existsSync(atom.config.configDirPath)).toBeFalsy()
        writeConfigFile """
          '*':
            foo:
              bar: 'baz'
              scoped: false
          '.source.ruby':
            foo:
              scoped: true
        """
        atom.config.loadUserConfig()

        waitsForPromise -> atom.config.observeUserConfig()

        runs ->
          updatedHandler = jasmine.createSpy "updatedHandler"
          atom.config.onDidChange updatedHandler

      afterEach ->
        atom.config.unobserveUserConfig()
        fs.removeSync(dotAtomPath)

      describe "when the config file changes to contain valid cson", ->

        it "updates the config data", ->
          writeConfigFile "foo: { bar: 'quux', baz: 'bar'}", 2

          waitsFor 'update event', -> updatedHandler.callCount > 0

          runs ->
            expect(atom.config.get('foo.bar')).toBe 'quux'
            expect(atom.config.get('foo.baz')).toBe 'bar'

        it "does not fire a change event for paths that did not change", ->
          atom.config.onDidChange 'foo.bar', noChangeSpy = jasmine.createSpy "unchanged"

          writeConfigFile "foo: { bar: 'baz', baz: 'ok'}", 2
          waitsFor 'update event', -> updatedHandler.callCount > 0

          runs ->
            expect(noChangeSpy).not.toHaveBeenCalled()
            expect(atom.config.get('foo.bar')).toBe 'baz'
            expect(atom.config.get('foo.baz')).toBe 'ok'

        describe "when the default value is a complex value", ->
          beforeEach ->
            atom.config.setSchema 'foo.bar',
              type: 'array'
              items:
                type: 'string'

            updatedHandler.reset()
            writeConfigFile "foo: { bar: ['baz', 'ok']}", 4
            waitsFor 'update event', -> updatedHandler.callCount > 0
            runs -> updatedHandler.reset()

          it "does not fire a change event for paths that did not change", ->
            noChangeSpy = jasmine.createSpy "unchanged"
            atom.config.onDidChange('foo.bar', noChangeSpy)

            writeConfigFile "foo: { bar: ['baz', 'ok'], baz: 'another'}", 2
            waitsFor 'update event', -> updatedHandler.callCount > 0

            runs ->
              expect(noChangeSpy).not.toHaveBeenCalled()
              expect(atom.config.get('foo.bar')).toEqual ['baz', 'ok']
              expect(atom.config.get('foo.baz')).toBe 'another'

        describe "when scoped settings are used", ->
          it "fires a change event for scoped settings that are removed", ->
            scopedSpy = jasmine.createSpy()
            atom.config.onDidChange('foo.scoped', scope: ['.source.ruby'], scopedSpy)

            writeConfigFile """
              '*':
                foo:
                  scoped: false
            """, 2
            waitsFor 'update event', -> updatedHandler.callCount > 0

            runs ->
              expect(scopedSpy).toHaveBeenCalled()
              expect(atom.config.get('foo.scoped', scope: ['.source.ruby'])).toBe false

          it "does not fire a change event for paths that did not change", ->
            noChangeSpy = jasmine.createSpy "no change"
            atom.config.onDidChange('foo.scoped', scope: ['.source.ruby'], noChangeSpy)

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
              expect(atom.config.get('foo.bar', scope: ['.source.ruby'])).toBe 'baz'
              expect(atom.config.get('foo.scoped', scope: ['.source.ruby'])).toBe true

      describe "when the config file changes to omit a setting with a default", ->
        it "resets the setting back to the default", ->
          writeConfigFile "foo: { baz: 'new'}", 2
          waitsFor 'update event', -> updatedHandler.callCount > 0
          runs ->
            expect(atom.config.get('foo.bar')).toBe 'def'
            expect(atom.config.get('foo.baz')).toBe 'new'

      describe "when the config file changes to be empty", ->
        beforeEach ->
          updatedHandler.reset()
          writeConfigFile "", 4
          waitsFor 'update event', -> updatedHandler.callCount > 0

        it "resets all settings back to the defaults", ->
          expect(updatedHandler.callCount).toBe 1
          expect(atom.config.get('foo.bar')).toBe 'def'
          atom.config.set("hair", "blonde") # trigger a save
          waitsFor 'save', -> atom.config.save.callCount > 0

        describe "when the config file subsequently changes again to contain configuration", ->
          beforeEach ->
            updatedHandler.reset()
            writeConfigFile "foo: bar: 'newVal'", 2
            waitsFor 'update event', -> updatedHandler.callCount > 0

          it "sets the setting to the value specified in the config file", ->
            expect(atom.config.get('foo.bar')).toBe 'newVal'

      describe "when the config file changes to contain invalid cson", ->
        addErrorHandler = null
        beforeEach ->
          atom.notifications.onDidAddNotification addErrorHandler = jasmine.createSpy "error handler"
          writeConfigFile "}}}", 4
          waitsFor "error to be logged", -> addErrorHandler.callCount > 0

        it "logs a warning and does not update config data", ->
          expect(updatedHandler.callCount).toBe 0
          expect(atom.config.get('foo.bar')).toBe 'baz'

          atom.config.set("hair", "blonde") # trigger a save
          expect(atom.config.save).not.toHaveBeenCalled()

        describe "when the config file subsequently changes again to contain valid cson", ->
          beforeEach ->
            updatedHandler.reset()
            writeConfigFile "foo: bar: 'newVal'", 6
            waitsFor 'update event', -> updatedHandler.callCount > 0

          it "updates the config data and resumes saving", ->
            atom.config.set("hair", "blonde")
            waitsFor 'save', -> atom.config.save.callCount > 0

    describe ".initializeConfigDirectory()", ->
      beforeEach ->
        if fs.existsSync(dotAtomPath)
          fs.removeSync(dotAtomPath)

        atom.config.configDirPath = dotAtomPath

      afterEach ->
        fs.removeSync(dotAtomPath)

      describe "when the configDirPath doesn't exist", ->
        it "copies the contents of dot-atom to ~/.atom", ->
          return if process.platform is 'win32' # Flakey test on Win32
          initializationDone = false
          jasmine.unspy(window, "setTimeout")
          atom.config.initializeConfigDirectory ->
            initializationDone = true

          waitsFor -> initializationDone

          runs ->
            expect(fs.existsSync(atom.config.configDirPath)).toBeTruthy()
            expect(fs.existsSync(path.join(atom.config.configDirPath, 'packages'))).toBeTruthy()
            expect(fs.isFileSync(path.join(atom.config.configDirPath, 'snippets.cson'))).toBeTruthy()
            expect(fs.isFileSync(path.join(atom.config.configDirPath, 'init.coffee'))).toBeTruthy()
            expect(fs.isFileSync(path.join(atom.config.configDirPath, 'styles.less'))).toBeTruthy()

    describe ".pushAtKeyPath(keyPath, value)", ->
      it "pushes the given value to the array at the key path and updates observers", ->
        atom.config.set("foo.bar.baz", ["a"])
        observeHandler = jasmine.createSpy "observeHandler"
        atom.config.observe "foo.bar.baz", observeHandler
        observeHandler.reset()

        expect(atom.config.pushAtKeyPath("foo.bar.baz", "b")).toBe 2
        expect(atom.config.get("foo.bar.baz")).toEqual ["a", "b"]
        expect(observeHandler).toHaveBeenCalledWith atom.config.get("foo.bar.baz")

    describe ".unshiftAtKeyPath(keyPath, value)", ->
      it "unshifts the given value to the array at the key path and updates observers", ->
        atom.config.set("foo.bar.baz", ["b"])
        observeHandler = jasmine.createSpy "observeHandler"
        atom.config.observe "foo.bar.baz", observeHandler
        observeHandler.reset()

        expect(atom.config.unshiftAtKeyPath("foo.bar.baz", "a")).toBe 2
        expect(atom.config.get("foo.bar.baz")).toEqual ["a", "b"]
        expect(observeHandler).toHaveBeenCalledWith atom.config.get("foo.bar.baz")

    describe ".removeAtKeyPath(keyPath, value)", ->
      it "removes the given value from the array at the key path and updates observers", ->
        atom.config.set("foo.bar.baz", ["a", "b", "c"])
        observeHandler = jasmine.createSpy "observeHandler"
        atom.config.observe "foo.bar.baz", observeHandler
        observeHandler.reset()

        expect(atom.config.removeAtKeyPath("foo.bar.baz", "b")).toEqual ["a", "c"]
        expect(atom.config.get("foo.bar.baz")).toEqual ["a", "c"]
        expect(observeHandler).toHaveBeenCalledWith atom.config.get("foo.bar.baz")

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

      it "emits an updated event", ->
        updatedCallback = jasmine.createSpy('updated')
        atom.config.onDidChange('foo.bar.baz.a', updatedCallback)
        expect(updatedCallback.callCount).toBe 0
        atom.config.setDefaults("foo.bar.baz", a: 2)
        expect(updatedCallback.callCount).toBe 1

    describe ".setSchema(keyPath, schema)", ->
      it 'creates a properly nested schema', ->
        schema =
          type: 'object'
          properties:
            anInt:
              type: 'integer'
              default: 12

        atom.config.setSchema('foo.bar', schema)

        expect(atom.config.getSchema('foo')).toEqual
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

        atom.config.setSchema('foo.bar', schema)
        expect(atom.config.get("foo.bar.anInt")).toBe 12
        expect(atom.config.get("foo.bar.anObject")).toEqual
          nestedInt: 24
          nestedObject:
            superNestedInt: 36

        expect(atom.config.get("foo")).toEqual {
          bar:
            anInt: 12
            anObject:
              nestedInt: 24
              nestedObject:
                superNestedInt: 36
        }
        atom.config.set("foo.bar.anObject.nestedObject.superNestedInt", 37)
        expect(atom.config.get("foo")).toEqual {
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

        atom.config.setSchema('foo.bar.anInt', schema)
        expect(atom.config.get("foo.bar.anInt")).toBe 12
        expect(atom.config.getSchema('foo.bar.anInt')).toEqual
          type: 'integer'
          default: 12

      it "allows the schema to be retrieved via ::getSchema", ->
        schema =
          type: 'object'
          properties:
            anInt:
              type: 'integer'
              default: 12

        atom.config.setSchema('foo.bar', schema)

        expect(atom.config.getSchema('foo.bar')).toEqual
          type: 'object'
          properties:
            anInt:
              type: 'integer'
              default: 12

        expect(atom.config.getSchema('foo.bar.anInt')).toEqual
          type: 'integer'
          default: 12

        expect(atom.config.getSchema('foo.baz')).toEqual {type: 'any'}
        expect(atom.config.getSchema('foo.bar.anInt.baz')).toBe(null)

      it "respects the schema for scoped settings", ->
        schema =
          type: 'string'
          default: 'ok'
          scopes:
            '.source.js':
              default: 'omg'
        atom.config.setSchema('foo.bar.str', schema)

        expect(atom.config.get('foo.bar.str')).toBe 'ok'
        expect(atom.config.get('foo.bar.str', scope: ['.source.js'])).toBe 'omg'
        expect(atom.config.get('foo.bar.str', scope: ['.source.coffee'])).toBe 'ok'

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
          expect(atom.config.set('foo.bar.str', 'global')).toBe true
          expect(atom.config.set('foo.bar.str', 'scoped', scopeSelector: '.source.js')).toBe true
          expect(atom.config.get('foo.bar.str')).toBe 'global'
          expect(atom.config.get('foo.bar.str', scope: ['.source.js'])).toBe 'scoped'

          expect(atom.config.set('foo.bar.noschema', 'nsGlobal')).toBe true
          expect(atom.config.set('foo.bar.noschema', 'nsScoped', scopeSelector: '.source.js')).toBe true
          expect(atom.config.get('foo.bar.noschema')).toBe 'nsGlobal'
          expect(atom.config.get('foo.bar.noschema', scope: ['.source.js'])).toBe 'nsScoped'

          expect(atom.config.set('foo.bar.int', 'nope')).toBe true
          expect(atom.config.set('foo.bar.int', 'notanint', scopeSelector: '.source.js')).toBe true
          expect(atom.config.set('foo.bar.int', 23, scopeSelector: '.source.coffee')).toBe true
          expect(atom.config.get('foo.bar.int')).toBe 'nope'
          expect(atom.config.get('foo.bar.int', scope: ['.source.js'])).toBe 'notanint'
          expect(atom.config.get('foo.bar.int', scope: ['.source.coffee'])).toBe 23

          atom.config.setSchema('foo.bar', schema)

          expect(atom.config.get('foo.bar.str')).toBe 'global'
          expect(atom.config.get('foo.bar.str', scope: ['.source.js'])).toBe 'scoped'
          expect(atom.config.get('foo.bar.noschema')).toBe 'nsGlobal'
          expect(atom.config.get('foo.bar.noschema', scope: ['.source.js'])).toBe 'nsScoped'

          expect(atom.config.get('foo.bar.int')).toBe 2
          expect(atom.config.get('foo.bar.int', scope: ['.source.js'])).toBe 2
          expect(atom.config.get('foo.bar.int', scope: ['.source.coffee'])).toBe 23

        it "sets all values that adhere to the schema", ->
          expect(atom.config.set('foo.bar.int', 10)).toBe true
          expect(atom.config.set('foo.bar.int', 15, scopeSelector: '.source.js')).toBe true
          expect(atom.config.set('foo.bar.int', 23, scopeSelector: '.source.coffee')).toBe true
          expect(atom.config.get('foo.bar.int')).toBe 10
          expect(atom.config.get('foo.bar.int', scope: ['.source.js'])).toBe 15
          expect(atom.config.get('foo.bar.int', scope: ['.source.coffee'])).toBe 23

          atom.config.setSchema('foo.bar', schema)

          expect(atom.config.get('foo.bar.int')).toBe 10
          expect(atom.config.get('foo.bar.int', scope: ['.source.js'])).toBe 15
          expect(atom.config.get('foo.bar.int', scope: ['.source.coffee'])).toBe 23

      describe 'when the value has an "integer" type', ->
        beforeEach ->
          schema =
            type: 'integer'
            default: 12
          atom.config.setSchema('foo.bar.anInt', schema)

        it 'coerces a string to an int', ->
          atom.config.set('foo.bar.anInt', '123')
          expect(atom.config.get('foo.bar.anInt')).toBe 123

        it 'does not allow infinity', ->
          atom.config.set('foo.bar.anInt', Infinity)
          expect(atom.config.get('foo.bar.anInt')).toBe 12

        it 'coerces a float to an int', ->
          atom.config.set('foo.bar.anInt', 12.3)
          expect(atom.config.get('foo.bar.anInt')).toBe 12

        it 'will not set non-integers', ->
          atom.config.set('foo.bar.anInt', null)
          expect(atom.config.get('foo.bar.anInt')).toBe 12

          atom.config.set('foo.bar.anInt', 'nope')
          expect(atom.config.get('foo.bar.anInt')).toBe 12

        describe 'when the minimum and maximum keys are used', ->
          beforeEach ->
            schema =
              type: 'integer'
              minimum: 10
              maximum: 20
              default: 12
            atom.config.setSchema('foo.bar.anInt', schema)

          it 'keeps the specified value within the specified range', ->
            atom.config.set('foo.bar.anInt', '123')
            expect(atom.config.get('foo.bar.anInt')).toBe 20

            atom.config.set('foo.bar.anInt', '1')
            expect(atom.config.get('foo.bar.anInt')).toBe 10

      describe 'when the value has an "integer" and "string" type', ->
        beforeEach ->
          schema =
            type: ['integer', 'string']
            default: 12
          atom.config.setSchema('foo.bar.anInt', schema)

        it 'can coerce an int, and fallback to a string', ->
          atom.config.set('foo.bar.anInt', '123')
          expect(atom.config.get('foo.bar.anInt')).toBe 123

          atom.config.set('foo.bar.anInt', 'cats')
          expect(atom.config.get('foo.bar.anInt')).toBe 'cats'

      describe 'when the value has an "string" and "boolean" type', ->
        beforeEach ->
          schema =
            type: ['string', 'boolean']
            default: 'def'
          atom.config.setSchema('foo.bar', schema)

        it 'can set a string, a boolean, and revert back to the default', ->
          atom.config.set('foo.bar', 'ok')
          expect(atom.config.get('foo.bar')).toBe 'ok'

          atom.config.set('foo.bar', false)
          expect(atom.config.get('foo.bar')).toBe false

          atom.config.set('foo.bar', undefined)
          expect(atom.config.get('foo.bar')).toBe 'def'

      describe 'when the value has a "number" type', ->
        beforeEach ->
          schema =
            type: 'number'
            default: 12.1
          atom.config.setSchema('foo.bar.aFloat', schema)

        it 'coerces a string to a float', ->
          atom.config.set('foo.bar.aFloat', '12.23')
          expect(atom.config.get('foo.bar.aFloat')).toBe 12.23

        it 'will not set non-numbers', ->
          atom.config.set('foo.bar.aFloat', null)
          expect(atom.config.get('foo.bar.aFloat')).toBe 12.1

          atom.config.set('foo.bar.aFloat', 'nope')
          expect(atom.config.get('foo.bar.aFloat')).toBe 12.1

        describe 'when the minimum and maximum keys are used', ->
          beforeEach ->
            schema =
              type: 'number'
              minimum: 11.2
              maximum: 25.4
              default: 12.1
            atom.config.setSchema('foo.bar.aFloat', schema)

          it 'keeps the specified value within the specified range', ->
            atom.config.set('foo.bar.aFloat', '123.2')
            expect(atom.config.get('foo.bar.aFloat')).toBe 25.4

            atom.config.set('foo.bar.aFloat', '1.0')
            expect(atom.config.get('foo.bar.aFloat')).toBe 11.2

      describe 'when the value has a "boolean" type', ->
        beforeEach ->
          schema =
            type: 'boolean'
            default: true
          atom.config.setSchema('foo.bar.aBool', schema)

        it 'coerces various types to a boolean', ->
          atom.config.set('foo.bar.aBool', 'true')
          expect(atom.config.get('foo.bar.aBool')).toBe true
          atom.config.set('foo.bar.aBool', 'false')
          expect(atom.config.get('foo.bar.aBool')).toBe false
          atom.config.set('foo.bar.aBool', 'TRUE')
          expect(atom.config.get('foo.bar.aBool')).toBe true
          atom.config.set('foo.bar.aBool', 'FALSE')
          expect(atom.config.get('foo.bar.aBool')).toBe false
          atom.config.set('foo.bar.aBool', 1)
          expect(atom.config.get('foo.bar.aBool')).toBe false
          atom.config.set('foo.bar.aBool', 0)
          expect(atom.config.get('foo.bar.aBool')).toBe false
          atom.config.set('foo.bar.aBool', {})
          expect(atom.config.get('foo.bar.aBool')).toBe false
          atom.config.set('foo.bar.aBool', null)
          expect(atom.config.get('foo.bar.aBool')).toBe false

        it 'reverts back to the default value when undefined is passed to set', ->
          atom.config.set('foo.bar.aBool', 'false')
          expect(atom.config.get('foo.bar.aBool')).toBe false

          atom.config.set('foo.bar.aBool', undefined)
          expect(atom.config.get('foo.bar.aBool')).toBe true

      describe 'when the value has an "string" type', ->
        beforeEach ->
          schema =
            type: 'string'
            default: 'ok'
          atom.config.setSchema('foo.bar.aString', schema)

        it 'allows strings', ->
          atom.config.set('foo.bar.aString', 'yep')
          expect(atom.config.get('foo.bar.aString')).toBe 'yep'

        it 'will only set strings', ->
          expect(atom.config.set('foo.bar.aString', 123)).toBe false
          expect(atom.config.get('foo.bar.aString')).toBe 'ok'

          expect(atom.config.set('foo.bar.aString', true)).toBe false
          expect(atom.config.get('foo.bar.aString')).toBe 'ok'

          expect(atom.config.set('foo.bar.aString', null)).toBe false
          expect(atom.config.get('foo.bar.aString')).toBe 'ok'

          expect(atom.config.set('foo.bar.aString', [])).toBe false
          expect(atom.config.get('foo.bar.aString')).toBe 'ok'

          expect(atom.config.set('foo.bar.aString', nope: 'nope')).toBe false
          expect(atom.config.get('foo.bar.aString')).toBe 'ok'

        it 'does not allow setting children of that key-path', ->
          expect(atom.config.set('foo.bar.aString.something', 123)).toBe false
          expect(atom.config.get('foo.bar.aString')).toBe 'ok'

        describe 'when the schema has a "maximumLength" key', ->
          it "trims the string to be no longer than the specified maximum", ->
            schema =
              type: 'string'
              default: 'ok'
              maximumLength: 3
            atom.config.setSchema('foo.bar.aString', schema)
            atom.config.set('foo.bar.aString', 'abcdefg')
            expect(atom.config.get('foo.bar.aString')).toBe 'abc'

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
          atom.config.setSchema('foo.bar', schema)

        it 'converts and validates all the children', ->
          atom.config.set 'foo.bar',
            anInt: '23'
            nestedObject:
              nestedBool: 'true'
          expect(atom.config.get('foo.bar')).toEqual
            anInt: 23
            nestedObject:
              nestedBool: true

        it 'will set only the values that adhere to the schema', ->
          expect(atom.config.set 'foo.bar',
            anInt: 'nope'
            nestedObject:
              nestedBool: true
          ).toBe true
          expect(atom.config.get('foo.bar.anInt')).toEqual 12
          expect(atom.config.get('foo.bar.nestedObject.nestedBool')).toEqual true

        describe "when the value has additionalProperties set to false", ->
          it 'does not allow other properties to be set on the object', ->
            atom.config.setSchema('foo.bar',
              type: 'object'
              properties:
                anInt:
                  type: 'integer'
                  default: 12
              additionalProperties: false
            )

            expect(atom.config.set('foo.bar', {anInt: 5, somethingElse: 'ok'})).toBe true
            expect(atom.config.get('foo.bar.anInt')).toBe 5
            expect(atom.config.get('foo.bar.somethingElse')).toBeUndefined()

            expect(atom.config.set('foo.bar.somethingElse', {anInt: 5})).toBe false
            expect(atom.config.get('foo.bar.somethingElse')).toBeUndefined()

        describe 'when the value has an additionalProperties schema', ->
          it 'validates properties of the object against that schema', ->
            atom.config.setSchema('foo.bar',
              type: 'object'
              properties:
                anInt:
                  type: 'integer'
                  default: 12
              additionalProperties:
                type: 'string'
            )

            expect(atom.config.set('foo.bar', {anInt: 5, somethingElse: 'ok'})).toBe true
            expect(atom.config.get('foo.bar.anInt')).toBe 5
            expect(atom.config.get('foo.bar.somethingElse')).toBe 'ok'

            expect(atom.config.set('foo.bar.somethingElse', 7)).toBe false
            expect(atom.config.get('foo.bar.somethingElse')).toBe 'ok'

            expect(atom.config.set('foo.bar', {anInt: 6, somethingElse: 7})).toBe true
            expect(atom.config.get('foo.bar.anInt')).toBe 6
            expect(atom.config.get('foo.bar.somethingElse')).toBe undefined

      describe 'when the value has an "array" type', ->
        beforeEach ->
          schema =
            type: 'array'
            default: [1, 2, 3]
            items:
              type: 'integer'
          atom.config.setSchema('foo.bar', schema)

        it 'converts an array of strings to an array of ints', ->
          atom.config.set 'foo.bar', ['2', '3', '4']
          expect(atom.config.get('foo.bar')).toEqual  [2, 3, 4]

        it 'does not allow setting children of that key-path', ->
          expect(atom.config.set('foo.bar.child', 123)).toBe false
          expect(atom.config.set('foo.bar.child.grandchild', 123)).toBe false
          expect(atom.config.get('foo.bar')).toEqual [1, 2, 3]

      describe 'when the value has a "color" type', ->
        beforeEach ->
          schema =
            type: 'color'
            default: 'white'
          atom.config.setSchema('foo.bar.aColor', schema)

        it 'returns a Color object', ->
          color = atom.config.get('foo.bar.aColor')
          expect(color.toHexString()).toBe '#ffffff'
          expect(color.toRGBAString()).toBe 'rgba(255, 255, 255, 1)'

          color.red = 0
          color.green = 0
          color.blue = 0
          color.alpha = 0
          atom.config.set('foo.bar.aColor', color)

          color = atom.config.get('foo.bar.aColor')
          expect(color.toHexString()).toBe '#000000'
          expect(color.toRGBAString()).toBe 'rgba(0, 0, 0, 0)'

          color.red = 300
          color.green = -200
          color.blue = -1
          color.alpha = 'not see through'
          atom.config.set('foo.bar.aColor', color)

          color = atom.config.get('foo.bar.aColor')
          expect(color.toHexString()).toBe '#ff0000'
          expect(color.toRGBAString()).toBe 'rgba(255, 0, 0, 1)'

          color.red = 11
          color.green = 11
          color.blue = 124
          color.alpha = 1
          atom.config.set('foo.bar.aColor', color)

          color = atom.config.get('foo.bar.aColor')
          expect(color.toHexString()).toBe '#0b0b7c'
          expect(color.toRGBAString()).toBe 'rgba(11, 11, 124, 1)'

        it 'coerces various types to a color object', ->
          atom.config.set('foo.bar.aColor', 'red')
          expect(atom.config.get('foo.bar.aColor')).toEqual {red: 255, green: 0, blue: 0, alpha: 1}
          atom.config.set('foo.bar.aColor', '#020')
          expect(atom.config.get('foo.bar.aColor')).toEqual {red: 0, green: 34, blue: 0, alpha: 1}
          atom.config.set('foo.bar.aColor', '#abcdef')
          expect(atom.config.get('foo.bar.aColor')).toEqual {red: 171, green: 205, blue: 239, alpha: 1}
          atom.config.set('foo.bar.aColor', 'rgb(1,2,3)')
          expect(atom.config.get('foo.bar.aColor')).toEqual {red: 1, green: 2, blue: 3, alpha: 1}
          atom.config.set('foo.bar.aColor', 'rgba(4,5,6,.7)')
          expect(atom.config.get('foo.bar.aColor')).toEqual {red: 4, green: 5, blue: 6, alpha: .7}
          atom.config.set('foo.bar.aColor', 'hsl(120,100%,50%)')
          expect(atom.config.get('foo.bar.aColor')).toEqual {red: 0, green: 255, blue: 0, alpha: 1}
          atom.config.set('foo.bar.aColor', 'hsla(120,100%,50%,0.3)')
          expect(atom.config.get('foo.bar.aColor')).toEqual {red: 0, green: 255, blue: 0, alpha: .3}
          atom.config.set('foo.bar.aColor', {red: 100, green: 255, blue: 2, alpha: .5})
          expect(atom.config.get('foo.bar.aColor')).toEqual {red: 100, green: 255, blue: 2, alpha: .5}
          atom.config.set('foo.bar.aColor', {red: 255})
          expect(atom.config.get('foo.bar.aColor')).toEqual {red: 255, green: 0, blue: 0, alpha: 1}
          atom.config.set('foo.bar.aColor', {red: 1000})
          expect(atom.config.get('foo.bar.aColor')).toEqual {red: 255, green: 0, blue: 0, alpha: 1}
          atom.config.set('foo.bar.aColor', {red: 'dark'})
          expect(atom.config.get('foo.bar.aColor')).toEqual {red: 0, green: 0, blue: 0, alpha: 1}

        it 'reverts back to the default value when undefined is passed to set', ->
          atom.config.set('foo.bar.aColor', undefined)
          expect(atom.config.get('foo.bar.aColor')).toEqual {red: 255, green: 255, blue: 255, alpha: 1}

        it 'will not set non-colors', ->
          atom.config.set('foo.bar.aColor', null)
          expect(atom.config.get('foo.bar.aColor')).toEqual {red: 255, green: 255, blue: 255, alpha: 1}

          atom.config.set('foo.bar.aColor', 'nope')
          expect(atom.config.get('foo.bar.aColor')).toEqual {red: 255, green: 255, blue: 255, alpha: 1}

          atom.config.set('foo.bar.aColor', 30)
          expect(atom.config.get('foo.bar.aColor')).toEqual {red: 255, green: 255, blue: 255, alpha: 1}

          atom.config.set('foo.bar.aColor', false)
          expect(atom.config.get('foo.bar.aColor')).toEqual {red: 255, green: 255, blue: 255, alpha: 1}

        it "returns a clone of the Color when returned in a parent object", ->
          color1 = atom.config.get('foo.bar').aColor
          color2 = atom.config.get('foo.bar').aColor
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

          atom.config.setSchema('foo.bar', schema)

        it 'will only set a string when the string is in the enum values', ->
          expect(atom.config.set('foo.bar.str', 'nope')).toBe false
          expect(atom.config.get('foo.bar.str')).toBe 'ok'

          expect(atom.config.set('foo.bar.str', 'one')).toBe true
          expect(atom.config.get('foo.bar.str')).toBe 'one'

        it 'will only set an integer when the integer is in the enum values', ->
          expect(atom.config.set('foo.bar.int', '400')).toBe false
          expect(atom.config.get('foo.bar.int')).toBe 2

          expect(atom.config.set('foo.bar.int', '3')).toBe true
          expect(atom.config.get('foo.bar.int')).toBe 3

        it 'will only set an array when the array values are in the enum values', ->
          expect(atom.config.set('foo.bar.arr', ['one', 'five'])).toBe true
          expect(atom.config.get('foo.bar.arr')).toEqual ['one']

          expect(atom.config.set('foo.bar.arr', ['two', 'three'])).toBe true
          expect(atom.config.get('foo.bar.arr')).toEqual ['two', 'three']

        it 'will honor the enum when specified as an array', ->
          expect(atom.config.set('foo.bar.str_options', 'one')).toBe true
          expect(atom.config.get('foo.bar.str_options')).toEqual 'one'

          expect(atom.config.set('foo.bar.str_options', 'two')).toBe true
          expect(atom.config.get('foo.bar.str_options')).toEqual 'two'

          expect(atom.config.set('foo.bar.str_options', 'One')).toBe false
          expect(atom.config.get('foo.bar.str_options')).toEqual 'two'

  describe "when .set/.unset is called prior to .loadUserConfig", ->
    beforeEach ->
      atom.config.settingsLoaded = false
      fs.writeFileSync atom.config.configFilePath, """
        '*':
          foo:
            bar: 'baz'
          do:
            ray: 'me'
      """

    it "ensures that early set and unset calls are replayed after the config is loaded from disk", ->
      atom.config.unset 'foo.bar'
      atom.config.set 'foo.qux', 'boo'

      expect(atom.config.get('foo.bar')).toBeUndefined()
      expect(atom.config.get('foo.qux')).toBe 'boo'
      expect(atom.config.get('do.ray')).toBeUndefined()

      advanceClock 100
      expect(atom.config.save).not.toHaveBeenCalled()

      atom.config.loadUserConfig()

      advanceClock 100
      waitsFor -> atom.config.save.callCount > 0

      runs ->
        expect(atom.config.get('foo.bar')).toBeUndefined()
        expect(atom.config.get('foo.qux')).toBe 'boo'
        expect(atom.config.get('do.ray')).toBe 'me'
