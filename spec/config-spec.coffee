path = require 'path'
temp = require 'temp'
CSON = require 'season'
fs = require 'fs-plus'
Grim = require 'grim'

describe "Config", ->
  dotAtomPath = null

  beforeEach ->
    dotAtomPath = temp.path('dot-atom-dir')

  describe ".get(keyPath)", ->
    it "allows a key path's value to be read", ->
      expect(atom.config.set("foo.bar.baz", 42)).toBe true
      expect(atom.config.get("foo.bar.baz")).toBe 42
      expect(atom.config.get("bogus.key.path")).toBeUndefined()

    it "returns a deep clone of the key path's value", ->
      atom.config.set('value', array: [1, b: 2, 3])
      retrievedValue = atom.config.get('value')
      retrievedValue.array[0] = 4
      retrievedValue.array[1].b = 2.1
      expect(atom.config.get('value')).toEqual(array: [1, b: 2, 3])

    it "merges defaults into the returned value if both the assigned value and the default value are objects", ->
      atom.config.setDefaults("foo", a: 1, b: 2)
      atom.config.set("foo", a: 3)
      expect(atom.config.get("foo")).toEqual {a: 3, b: 2}

      atom.config.set("foo", 7)
      expect(atom.config.get("foo")).toBe 7

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

  describe ".set(keyPath, value)", ->
    it "allows a key path's value to be written", ->
      expect(atom.config.set("foo.bar.baz", 42)).toBe true
      expect(atom.config.get("foo.bar.baz")).toBe 42

    it "updates observers and saves when a key path is set", ->
      observeHandler = jasmine.createSpy "observeHandler"
      atom.config.observe "foo.bar.baz", observeHandler
      observeHandler.reset()

      atom.config.set("foo.bar.baz", 42)

      expect(atom.config.save).toHaveBeenCalled()
      expect(observeHandler).toHaveBeenCalledWith 42

    describe "when the value equals the default value", ->
      it "does not store the value in the user's config", ->
        atom.config.setDefaults "foo",
          same: 1
          changes: 1
          sameArray: [1, 2, 3]
          sameObject: {a: 1, b: 2}
          null: null
          undefined: undefined
        expect(atom.config.settings.foo).toBeUndefined()

        atom.config.set('foo.same', 1)
        atom.config.set('foo.changes', 2)
        atom.config.set('foo.sameArray', [1, 2, 3])
        atom.config.set('foo.null', undefined)
        atom.config.set('foo.undefined', null)
        atom.config.set('foo.sameObject', {b: 2, a: 1})

        expect(atom.config.get("foo.same", sources: [atom.config.getUserConfigPath()])).toBeUndefined()

        expect(atom.config.get("foo.changes", sources: [atom.config.getUserConfigPath()])).toBe 2
        atom.config.set('foo.changes', 1)
        expect(atom.config.get("foo.changes", sources: [atom.config.getUserConfigPath()])).toBeUndefined()

  describe ".getDefault(keyPath)", ->
    it "returns a clone of the default value", ->
      atom.config.setDefaults("foo", same: 1, changes: 1)

      spyOn(Grim, 'deprecate')
      expect(atom.config.getDefault('foo.same')).toBe 1
      expect(atom.config.getDefault('foo.changes')).toBe 1
      expect(Grim.deprecate.callCount).toBe 2

      atom.config.set('foo.same', 2)
      atom.config.set('foo.changes', 3)

      expect(atom.config.getDefault('foo.same')).toBe 1
      expect(atom.config.getDefault('foo.changes')).toBe 1
      expect(Grim.deprecate.callCount).toBe 4

      initialDefaultValue = [1, 2, 3]
      atom.config.setDefaults("foo", bar: initialDefaultValue)
      expect(atom.config.getDefault('foo.bar')).toEqual initialDefaultValue
      expect(atom.config.getDefault('foo.bar')).not.toBe initialDefaultValue
      expect(Grim.deprecate.callCount).toBe 6

    describe "when scoped settings are used", ->
      it "returns the global default when no scoped default set", ->
        atom.config.setDefaults("foo", bar: baz: 10)

        spyOn(Grim, 'deprecate')
        expect(atom.config.getDefault('.source.coffee', 'foo.bar.baz')).toBe 10
        expect(Grim.deprecate).toHaveBeenCalled()

      it "returns the scoped settings not including the user's config file", ->
        atom.config.setDefaults("foo", bar: baz: 10)
        atom.config.addScopedSettings("default", ".source.coffee", foo: bar: baz: 42)

        spyOn(Grim, 'deprecate')
        expect(atom.config.getDefault('.source.coffee', 'foo.bar.baz')).toBe 42
        expect(Grim.deprecate.callCount).toBe 1

        atom.config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee')
        expect(atom.config.getDefault('.source.coffee', 'foo.bar.baz')).toBe 42
        expect(Grim.deprecate.callCount).toBe 2

  describe ".isDefault(keyPath)", ->
    it "returns true when the value of the key path is its default value", ->
      atom.config.setDefaults("foo", same: 1, changes: 1)

      spyOn(Grim, 'deprecate')
      expect(atom.config.isDefault('foo.same')).toBe true
      expect(atom.config.isDefault('foo.changes')).toBe true
      expect(Grim.deprecate.callCount).toBe 2

      atom.config.set('foo.same', 1)
      atom.config.set('foo.changes', 3)

      expect(atom.config.isDefault('foo.same')).toBe true
      expect(atom.config.isDefault('foo.changes')).toBe false
      expect(Grim.deprecate.callCount).toBe 4

    describe "when scoped settings are used", ->
      it "returns false when a scoped setting was set by the user", ->
        spyOn(Grim, 'deprecate')
        expect(atom.config.isDefault('.source.coffee', 'foo.bar.baz')).toBe true
        expect(Grim.deprecate.callCount).toBe 1

        atom.config.addScopedSettings("default", ".source.coffee", foo: bar: baz: 42)
        expect(atom.config.isDefault('.source.coffee', 'foo.bar.baz')).toBe true
        expect(Grim.deprecate.callCount).toBe 2

        atom.config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee')
        expect(atom.config.isDefault('.source.coffee', 'foo.bar.baz')).toBe false
        expect(Grim.deprecate.callCount).toBe 3

  describe ".setDefaults(keyPath)", ->
    it "sets a default when the setting's key contains an escaped dot", ->
      atom.config.setDefaults("foo", 'a\\.b': 1, b: 2)
      expect(atom.config.get("foo")).toEqual 'a\\.b': 1, b: 2

  describe ".toggle(keyPath)", ->
    beforeEach ->
      jasmine.snapshotDeprecations()

    afterEach ->
      jasmine.restoreDeprecationsSnapshot()

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

  describe ".unset(keyPath, {scope})", ->
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
      expect(atom.config.save.callCount).toBe 1

    describe "when scoped settings are used", ->
      it "restores the global default when no scoped default set", ->
        atom.config.setDefaults("foo", bar: baz: 10)
        atom.config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee')
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 55

        atom.config.unset('foo.bar.baz', scopeSelector: '.source.coffee')
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 10

      it "restores the scoped default when a scoped default is set", ->
        atom.config.setDefaults("foo", bar: baz: 10)
        atom.config.addScopedSettings("default", ".source.coffee", foo: bar: baz: 42)
        atom.config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee')
        atom.config.set('foo.bar.ok', 100, scopeSelector: '.source.coffee')
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 55

        atom.config.unset('foo.bar.baz', scopeSelector: '.source.coffee')
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 42
        expect(atom.config.get('foo.bar.ok', scope: ['.source.coffee'])).toBe 100

      it "calls ::save()", ->
        atom.config.setDefaults("foo", bar: baz: 10)
        atom.config.addScopedSettings("default", ".source.coffee", foo: bar: baz: 42)
        atom.config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee')
        atom.config.save.reset()

        atom.config.unset('foo.bar.baz', scopeSelector: '.source.coffee')
        expect(atom.config.save.callCount).toBe 1

      it "allows removing settings for a specific source and scope selector", ->
        atom.config.set('foo.bar', 55, scopeSelector: '.source.coffee', source: "source-a")
        atom.config.set('foo.bar', 65, scopeSelector: '.source.coffee', source: "source-b")
        expect(atom.config.get('foo.bar', scope: ['.source.coffee'])).toBe 65

        atom.config.unset('foo.bar', source: "source-b", scopeSelector: ".source.coffee")
        expect(atom.config.get('foo.bar', scope: ['.source.coffee', '.string'])).toBe 55

      it "allows removing all settings for a specific source", ->
        atom.config.set('foo.bar', 55, scopeSelector: '.source.coffee', source: "source-a")
        atom.config.set('foo.bar', 65, scopeSelector: '.source.coffee', source: "source-b")
        atom.config.set('foo.baz', 65, scopeSelector: '.source.coffee', source: "source-b")
        expect(atom.config.get('foo.bar', scope: ['.source.coffee'])).toBe 65

        atom.config.unset(null, source: "source-b", scopeSelector: ".source.coffee")
        expect(atom.config.get('foo.bar', scope: ['.source.coffee', '.string'])).toBe 55
        expect(atom.config.get('foo.baz', scope: ['.source.coffee', '.string'])).toBe undefined

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
        jasmine.unspy atom.config, 'save'

        atom.config.setDefaults("foo", bar: baz: 10)
        atom.config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee')
        atom.config.set('foo.bar.zfoo', 20, scopeSelector: '.source.coffee')
        CSON.writeFileSync.reset()
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 55

        atom.config.unset('foo.bar.baz', scopeSelector: '.source.coffee')
        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 10
        expect(atom.config.get('foo.bar.zfoo', scope: ['.source.coffee'])).toBe 20
        expect(CSON.writeFileSync).toHaveBeenCalled()
        properties = CSON.writeFileSync.mostRecentCall.args[1]
        expect(properties['.coffee.source']).toEqual
          foo:
            bar:
              zfoo: 20

        CSON.writeFileSync.reset()
        atom.config.unset('foo.bar.zfoo', scopeSelector: '.source.coffee')
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

      it "deprecates passing a scope selector as the first argument", ->
        atom.config.setDefaults("foo", bar: baz: 10)
        atom.config.set('foo.bar.baz', 55, scopeSelector: '.source.coffee')

        spyOn(Grim, 'deprecate')
        atom.config.unset('.source.coffee', 'foo.bar.baz')
        expect(Grim.deprecate).toHaveBeenCalled()

        expect(atom.config.get('foo.bar.baz', scope: ['.source.coffee'])).toBe 10

  describe ".getSettings()", ->
    it "returns all settings including defaults", ->
      atom.config.setDefaults("foo", bar: baz: 10)
      atom.config.set("foo.ok", 12)

      jasmine.snapshotDeprecations()
      expect(atom.config.getSettings().foo).toEqual
        ok: 12
        bar:
          baz: 10
      jasmine.restoreDeprecationsSnapshot()

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

  describe ".getPositiveInt(keyPath, defaultValue)", ->
    beforeEach ->
      jasmine.snapshotDeprecations()

    afterEach ->
      jasmine.restoreDeprecationsSnapshot()

    it "returns the proper coerced value", ->
      atom.config.set('editor.preferredLineLength', 0)
      expect(atom.config.getPositiveInt('editor.preferredLineLength', 80)).toBe 1

    it "returns the proper coerced value", ->
      atom.config.set('editor.preferredLineLength', -1234)
      expect(atom.config.getPositiveInt('editor.preferredLineLength', 80)).toBe 1

    it "returns the default value when a string is passed in", ->
      atom.config.set('editor.preferredLineLength', 'abcd')
      expect(atom.config.getPositiveInt('editor.preferredLineLength', 80)).toBe 80

    it "returns the default value when null is passed in", ->
      atom.config.set('editor.preferredLineLength', null)
      expect(atom.config.getPositiveInt('editor.preferredLineLength', 80)).toBe 80

  describe ".save()", ->
    CSON = require 'season'

    beforeEach ->
      spyOn(CSON, 'writeFileSync')
      jasmine.unspy atom.config, 'save'

    it "writes properties from the user config path source to the user config path", ->
      atom.config.configFilePath = "/fake/config/path"
      atom.config.set("a.b.c", 1)
      atom.config.set("a.b.d", 2)
      atom.config.set("x.y.z", 3)
      atom.config.set("x.y.q", 3, source: "/not/user/config")
      atom.config.set('foo.bar', 'ruby', scopeSelector: '.source.ruby')
      atom.config.set('foo.omg', 'wow', scopeSelector: '.source.ruby')
      atom.config.set('foo.bar', 'coffee', scopeSelector: '.source.coffee')

      atom.config.setDefaults("a.b", e: 4, f: 5)

      CSON.writeFileSync.reset()
      atom.config.save()

      expect(CSON.writeFileSync.argsForCall[0][0]).toBe atom.config.getUserConfigPath()
      writtenConfig = CSON.writeFileSync.argsForCall[0][1]
      global.debug = true
      expect(writtenConfig).toEqual
        'global':
          a: b:
            c: 1
            d: 2
          x: y: z: 3
        '.ruby.source':
          foo:
            bar: 'ruby'
            omg: 'wow'
        '.coffee.source':
          foo:
            bar: 'coffee'

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

  describe ".onDidChange(keyPath)", ->
    [observeHandler, observeSubscription] = []

    describe 'when a keyPath is specified', ->
      beforeEach ->
        observeHandler = jasmine.createSpy("observeHandler")
        atom.config.set("foo.bar.baz", "value 1")
        observeSubscription = atom.config.onDidChange "foo.bar.baz", observeHandler

      it "does not fire the given callback with the current value at the keypath", ->
        expect(observeHandler).not.toHaveBeenCalled()

      it "fires the callback every time the observed value changes", ->
        observeHandler.reset() # clear the initial call
        atom.config.set('foo.bar.baz', "value 2")
        expect(observeHandler).toHaveBeenCalledWith({newValue: 'value 2', oldValue: 'value 1'})
        observeHandler.reset()

        atom.config.set('foo.bar.baz', "value 1")
        expect(observeHandler).toHaveBeenCalledWith({newValue: 'value 1', oldValue: 'value 2'})
        observeHandler.reset()

        atom.config.set('foo.bar', {baz: "value 3"})
        expect(observeHandler).toHaveBeenCalledWith({newValue: 'value 3', oldValue: 'value 1'})
        observeHandler.reset()

        atom.config.set('foo.bar', null)
        expect(observeHandler).toHaveBeenCalledWith({newValue: undefined, oldValue: 'value 3'})
        observeHandler.reset()

    describe 'when a keyPath is not specified', ->
      beforeEach ->
        observeHandler = jasmine.createSpy("observeHandler")
        atom.config.set("foo", bar: baz: "value 1")
        observeSubscription = atom.config.onDidChange(observeHandler)

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

  describe ".observe(keyPath)", ->
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
      observeHandler.reset()

      atom.config.set('foo.bar', {baz: "value 3"})
      expect(observeHandler).toHaveBeenCalledWith("value 3")
      observeHandler.reset()

      atom.config.set('foo.bar', null)
      expect(observeHandler).toHaveBeenCalledWith(undefined)
      observeHandler.reset()

      atom.config.set('foo.bar.baz.quux', "value 4")
      expect(observeHandler).toHaveBeenCalledWith({quux: "value 4"})

      atom.config.set('foo.bar.baz.buzz', "value 5")
      expect(observeHandler).toHaveBeenCalledWith({quux: "value 4", buzz: "value 5"})

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

    it "does not fire the callback once the observe subscription is off'ed", ->
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

    describe "observing scoped settings", ->
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

      it "deprecates using a scope descriptor as the first argument", ->
        spyOn(Grim, 'deprecate')
        atom.config.observe([".some.scope"], "foo.bar.baz", observeHandler)
        atom.config.observe([".another.scope"], "foo.bar.baz", otherHandler)
        expect(Grim.deprecate).toHaveBeenCalled()

        atom.config.set('foo.bar.baz', "value 2", scopeSelector: ".some")
        expect(observeHandler).toHaveBeenCalledWith("value 2")
        expect(otherHandler).not.toHaveBeenCalledWith("value 2")

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

  describe ".initializeConfigDirectory()", ->
    beforeEach ->
      if fs.existsSync(dotAtomPath)
        fs.removeSync(dotAtomPath)

      atom.config.configDirPath = dotAtomPath

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
          global:
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
      beforeEach ->
        spyOn(console, 'error')
        spyOn(atom.notifications, 'addError')
        fs.writeFileSync(atom.config.configFilePath, "{{{{{")

      it "logs an error to the console and does not overwrite the config file on a subsequent save", ->
        atom.config.loadUserConfig()
        expect(console.error).toHaveBeenCalled()
        expect(atom.notifications.addError.callCount).toBe 1
        atom.config.set("hair", "blonde") # trigger a save
        expect(atom.config.save).not.toHaveBeenCalled()

    describe "when the config file does not exist", ->
      it "creates it with an empty object", ->
        fs.makeTreeSync(atom.config.configDirPath)
        atom.config.loadUserConfig()
        expect(fs.existsSync(atom.config.configFilePath)).toBe true
        expect(CSON.readFileSync(atom.config.configFilePath)).toEqual {}

    describe "when the config file contains values that do not adhere to the schema", ->
      warnSpy = null
      beforeEach ->
        warnSpy = spyOn console, 'warn'
        fs.writeFileSync atom.config.configFilePath, """
          foo:
            bar: 'baz'
            int: 'bad value'
        """
        atom.config.loadUserConfig()

      it "updates the only the settings that have values matching the schema", ->
        expect(atom.config.get("foo.bar")).toBe 'baz'
        expect(atom.config.get("foo.int")).toBe 12

        expect(warnSpy).toHaveBeenCalled()
        expect(warnSpy.mostRecentCall.args[0]).toContain "foo.int"

  describe ".observeUserConfig()", ->
    updatedHandler = null

    beforeEach ->
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

      atom.config.configDirPath = dotAtomPath
      atom.config.configFilePath = path.join(atom.config.configDirPath, "atom.config.cson")
      expect(fs.existsSync(atom.config.configDirPath)).toBeFalsy()
      fs.writeFileSync atom.config.configFilePath, """
        global:
          foo:
            bar: 'baz'
            scoped: false
        '.source.ruby':
          foo:
            scoped: true
      """
      atom.config.loadUserConfig()
      atom.config.observeUserConfig()
      updatedHandler = jasmine.createSpy("updatedHandler")
      atom.config.onDidChange updatedHandler

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

      it "does not fire a change event for paths that did not change", ->
        atom.config.onDidChange 'foo.bar', noChangeSpy = jasmine.createSpy()

        fs.writeFileSync(atom.config.configFilePath, "foo: { bar: 'baz', baz: 'ok'}")
        waitsFor 'update event', -> updatedHandler.callCount > 0
        runs ->
          expect(noChangeSpy).not.toHaveBeenCalled()
          expect(atom.config.get('foo.bar')).toBe 'baz'
          expect(atom.config.get('foo.baz')).toBe 'ok'

      describe 'when the default value is a complex value', ->
        beforeEach ->
          atom.config.setSchema 'foo.bar',
            type: 'array'
            items:
              type: 'string'
          fs.writeFileSync(atom.config.configFilePath, "foo: { bar: ['baz', 'ok']}")
          waitsFor 'update event', -> updatedHandler.callCount > 0
          runs -> updatedHandler.reset()

        it "does not fire a change event for paths that did not change", ->
          noChangeSpy = jasmine.createSpy()
          atom.config.onDidChange('foo.bar', noChangeSpy)

          fs.writeFileSync(atom.config.configFilePath, "foo: { bar: ['baz', 'ok'], baz: 'another'}")
          waitsFor 'update event', -> updatedHandler.callCount > 0
          runs ->
            expect(noChangeSpy).not.toHaveBeenCalled()
            expect(atom.config.get('foo.bar')).toEqual ['baz', 'ok']
            expect(atom.config.get('foo.baz')).toBe 'another'

      describe 'when scoped settings are used', ->
        it "fires a change event for scoped settings that are removed", ->
          scopedSpy = jasmine.createSpy()
          atom.config.onDidChange('foo.scoped', scope: ['.source.ruby'], scopedSpy)

          fs.writeFileSync atom.config.configFilePath, """
            global:
              foo:
                scoped: false
          """
          waitsFor 'update event', -> updatedHandler.callCount > 0
          runs ->
            expect(scopedSpy).toHaveBeenCalled()
            expect(atom.config.get('foo.scoped', scope: ['.source.ruby'])).toBe false

        it "does not fire a change event for paths that did not change", ->
          noChangeSpy = jasmine.createSpy()
          atom.config.onDidChange('foo.scoped', scope: ['.source.ruby'], noChangeSpy)

          fs.writeFileSync atom.config.configFilePath, """
            global:
              foo:
                bar: 'baz'
            '.source.ruby':
              foo:
                scoped: true
          """
          waitsFor 'update event', -> updatedHandler.callCount > 0
          runs ->
            expect(noChangeSpy).not.toHaveBeenCalled()
            expect(atom.config.get('foo.bar', scope: ['.source.ruby'])).toBe 'baz'
            expect(atom.config.get('foo.scoped', scope: ['.source.ruby'])).toBe true

    describe "when the config file changes to omit a setting with a default", ->
      it "resets the setting back to the default", ->
        fs.writeFileSync(atom.config.configFilePath, "foo: { baz: 'new'}")
        waitsFor 'update event', -> updatedHandler.callCount > 0
        runs ->
          expect(atom.config.get('foo.bar')).toBe 'def'
          expect(atom.config.get('foo.baz')).toBe 'new'

    describe "when the config file changes to be empty", ->
      beforeEach ->
        fs.writeFileSync(atom.config.configFilePath, "")
        waitsFor 'update event', -> updatedHandler.callCount > 0

      it "resets all settings back to the defaults", ->
        expect(updatedHandler.callCount).toBe 1
        expect(atom.config.get('foo.bar')).toBe 'def'
        atom.config.set("hair", "blonde") # trigger a save
        expect(atom.config.save).toHaveBeenCalled()

      describe "when the config file subsequently changes again to contain configuration", ->
        beforeEach ->
          updatedHandler.reset()
          fs.writeFileSync(atom.config.configFilePath, "foo: bar: 'newVal'")
          waitsFor 'update event', -> updatedHandler.callCount > 0

        it "sets the setting to the value specified in the config file", ->
          expect(atom.config.get('foo.bar')).toBe 'newVal'

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
          fs.writeFileSync(atom.config.configFilePath, "foo: bar: 'newVal'")
          waitsFor 'update event', -> updatedHandler.callCount > 0

        it "updates the config data and resumes saving", ->
          atom.config.set("hair", "blonde")
          expect(atom.config.save).toHaveBeenCalled()

  describe "when a schema is specified", ->
    schema = null

    describe '.setSchema(keyPath, schema)', ->
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

      it 'can set a non-object schema', ->
        schema =
          type: 'integer'
          default: 12

        atom.config.setSchema('foo.bar.anInt', schema)
        expect(atom.config.get("foo.bar.anInt")).toBe 12
        expect(atom.config.getSchema('foo.bar.anInt')).toEqual
          type: 'integer'
          default: 12

    describe '.getSchema(keyPath)', ->
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

    describe "when scoped settings are used", ->
      beforeEach ->
        schema =
          type: 'string'
          default: 'ok'
          scopes:
            '.source.js':
              default: 'omg'
        atom.config.setSchema('foo.bar.str', schema)

      it 'it respects the scoped defaults', ->
        expect(atom.config.get('foo.bar.str')).toBe 'ok'
        expect(atom.config.get('foo.bar.str', scope: ['.source.js'])).toBe 'omg'
        expect(atom.config.get('foo.bar.str', scope: ['.source.coffee'])).toBe 'ok'

  describe "scoped settings", ->
    describe ".get(scopeDescriptor, keyPath)", ->
      it "returns the property with the most specific scope selector", ->
        atom.config.addScopedSettings("config", ".source.coffee .string.quoted.double.coffee", foo: bar: baz: 42)
        atom.config.addScopedSettings("config", ".source .string.quoted.double", foo: bar: baz: 22)
        atom.config.addScopedSettings("config", ".source", foo: bar: baz: 11)

        expect(atom.config.get("foo.bar.baz", scope: [".source.coffee", ".string.quoted.double.coffee"])).toBe 42
        expect(atom.config.get("foo.bar.baz", scope: [".source.js", ".string.quoted.double.js"])).toBe 22
        expect(atom.config.get("foo.bar.baz", scope: [".source.js", ".variable.assignment.js"])).toBe 11
        expect(atom.config.get("foo.bar.baz", scope: [".text"])).toBeUndefined()

      it "favors the most recently added properties in the event of a specificity tie", ->
        atom.config.addScopedSettings("config", ".source.coffee .string.quoted.single", foo: bar: baz: 42)
        atom.config.addScopedSettings("config", ".source.coffee .string.quoted.double", foo: bar: baz: 22)

        expect(atom.config.get("foo.bar.baz", scope: [".source.coffee", ".string.quoted.single"])).toBe 42
        expect(atom.config.get("foo.bar.baz", scope: [".source.coffee", ".string.quoted.single.double"])).toBe 22

      describe 'when there are global defaults', ->
        it 'falls back to the global when there is no scoped property specified', ->
          atom.config.setDefaults("foo", hasDefault: 'ok')
          expect(atom.config.get("foo.hasDefault", scope: [".source.coffee", ".string.quoted.single"])).toBe 'ok'

      describe 'setting priority', ->
        describe 'when package settings are added after user settings', ->
          it "returns the user's setting because the user's setting has higher priority", ->
            atom.config.set("foo.bar.baz", 100, scopeSelector: ".source.coffee")
            atom.config.addScopedSettings("some-package", ".source.coffee", foo: bar: baz: 1)
            expect(atom.config.get("foo.bar.baz", scope: [".source.coffee"])).toBe 100

    describe ".set(scope, keyPath, value)", ->
      it "sets the value and overrides the others", ->
        atom.config.addScopedSettings("config", ".source.coffee .string.quoted.double.coffee", foo: bar: baz: 42)
        atom.config.addScopedSettings("config", ".source .string.quoted.double", foo: bar: baz: 22)
        atom.config.addScopedSettings("config", ".source", foo: bar: baz: 11)

        expect(atom.config.get("foo.bar.baz", scope: [".source.coffee", ".string.quoted.double.coffee"])).toBe 42

        expect(atom.config.set("foo.bar.baz", 100, scopeSelector: ".source.coffee .string.quoted.double.coffee")).toBe true
        expect(atom.config.get("foo.bar.baz", scope: [".source.coffee", ".string.quoted.double.coffee"])).toBe 100

    describe ".removeScopedSettingsForName(name)", ->
      it "allows properties to be removed by name", ->
        disposable1 = atom.config.addScopedSettings("a", ".source.coffee .string.quoted.double.coffee", foo: bar: baz: 42)
        disposable2 = atom.config.addScopedSettings("b", ".source .string.quoted.double", foo: bar: baz: 22)

        disposable2.dispose()
        expect(atom.config.get("foo.bar.baz", scope: [".source.js", ".string.quoted.double.js"])).toBeUndefined()
        expect(atom.config.get("foo.bar.baz", scope: [".source.coffee", ".string.quoted.double.coffee"])).toBe 42

    describe ".observe(scopeDescriptor, keyPath)", ->
      it 'calls the supplied callback when the value at the descriptor/keypath changes', ->
        changeSpy = jasmine.createSpy()
        atom.config.observe("foo.bar.baz", scope: [".source.coffee", ".string.quoted.double.coffee"], changeSpy)
        expect(changeSpy).toHaveBeenCalledWith(undefined)
        changeSpy.reset()

        atom.config.set("foo.bar.baz", 12)
        expect(changeSpy).toHaveBeenCalledWith(12)
        changeSpy.reset()

        disposable1 = atom.config.addScopedSettings("a", ".source .string.quoted.double", foo: bar: baz: 22)
        expect(changeSpy).toHaveBeenCalledWith(22)
        changeSpy.reset()

        disposable2 = atom.config.addScopedSettings("b", ".source.coffee .string.quoted.double.coffee", foo: bar: baz: 42)
        expect(changeSpy).toHaveBeenCalledWith(42)
        changeSpy.reset()

        disposable2.dispose()
        expect(changeSpy).toHaveBeenCalledWith(22)
        changeSpy.reset()

        disposable1.dispose()
        expect(changeSpy).toHaveBeenCalledWith(12)
        changeSpy.reset()

        atom.config.set("foo.bar.baz", undefined)
        expect(changeSpy).toHaveBeenCalledWith(undefined)
        changeSpy.reset()

    describe ".onDidChange(scopeDescriptor, keyPath)", ->
      it 'calls the supplied callback when the value at the descriptor/keypath changes', ->
        keyPath = "foo.bar.baz"
        changeSpy = jasmine.createSpy('onDidChange callback')
        atom.config.onDidChange keyPath, scope: [".source.coffee", ".string.quoted.double.coffee"], changeSpy

        atom.config.set("foo.bar.baz", 12)
        expect(changeSpy).toHaveBeenCalledWith({oldValue: undefined, newValue: 12})
        changeSpy.reset()

        disposable1 = atom.config.addScopedSettings("a", ".source .string.quoted.double", foo: bar: baz: 22)
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 12, newValue: 22})
        changeSpy.reset()

        disposable2 = atom.config.addScopedSettings("b", ".source.coffee .string.quoted.double.coffee", foo: bar: baz: 42)
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 22, newValue: 42})
        changeSpy.reset()

        disposable2.dispose()
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 42, newValue: 22})
        changeSpy.reset()

        disposable1.dispose()
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 22, newValue: 12})
        changeSpy.reset()

        atom.config.set("foo.bar.baz", undefined)
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 12, newValue: undefined})
        changeSpy.reset()

      it 'deprecates using a scope descriptor as an optional first argument', ->
        keyPath = "foo.bar.baz"
        spyOn(Grim, 'deprecate')
        atom.config.onDidChange [".source.coffee", ".string.quoted.double.coffee"], keyPath, changeSpy = jasmine.createSpy()
        expect(Grim.deprecate).toHaveBeenCalled()

        atom.config.set("foo.bar.baz", 12)
        expect(changeSpy).toHaveBeenCalledWith({oldValue: undefined, newValue: 12})
        changeSpy.reset()

        disposable1 = atom.config.addScopedSettings("a", ".source .string.quoted.double", foo: bar: baz: 22)
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 12, newValue: 22})
        changeSpy.reset()

        disposable2 = atom.config.addScopedSettings("b", ".source.coffee .string.quoted.double.coffee", foo: bar: baz: 42)
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 22, newValue: 42})
        changeSpy.reset()

        disposable2.dispose()
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 42, newValue: 22})
        changeSpy.reset()

        disposable1.dispose()
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 22, newValue: 12})
        changeSpy.reset()

        atom.config.set("foo.bar.baz", undefined)
        expect(changeSpy).toHaveBeenCalledWith({oldValue: 12, newValue: undefined})
        changeSpy.reset()
