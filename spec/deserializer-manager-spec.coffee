DeserializerManager = require '../src/deserializer-manager'

describe "DeserializerManager", ->
  manager = null

  class Foo
    @deserialize: ({name}) -> new Foo(name)
    constructor: (@name) ->

  beforeEach ->
    manager = new DeserializerManager

  describe "::add(deserializer)", ->
    it "returns a disposable that can be used to remove the manager", ->
      disposable = manager.add(Foo)
      expect(manager.deserialize({deserializer: 'Foo', name: 'Bar'})).toBeDefined()
      disposable.dispose()
      spyOn(console, 'warn')
      expect(manager.deserialize({deserializer: 'Foo', name: 'Bar'})).toBeUndefined()

  describe "::deserialize(state)", ->
    beforeEach ->
      manager.add(Foo)

    it "calls deserialize on the manager for the given state object, or returns undefined if one can't be found", ->
      spyOn(console, 'warn')
      object = manager.deserialize({deserializer: 'Foo', name: 'Bar'})
      expect(object.name).toBe 'Bar'
      expect(manager.deserialize({deserializer: 'Bogus'})).toBeUndefined()

    describe "when the manager has a version", ->
      beforeEach ->
        Foo.version = 2

      describe "when the deserialized state has a matching version", ->
        it "attempts to deserialize the state", ->
          object = manager.deserialize({deserializer: 'Foo', version: 2, name: 'Bar'})
          expect(object.name).toBe 'Bar'

      describe "when the deserialized state has a non-matching version", ->
        it "returns undefined", ->
          expect(manager.deserialize({deserializer: 'Foo', version: 3, name: 'Bar'})).toBeUndefined()
          expect(manager.deserialize({deserializer: 'Foo', version: 1, name: 'Bar'})).toBeUndefined()
          expect(manager.deserialize({deserializer: 'Foo', name: 'Bar'})).toBeUndefined()
