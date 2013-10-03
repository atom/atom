DeserializerManager = require '../src/deserializer-manager'

describe ".deserialize(state)", ->
  deserializer = null

  class Foo
    @deserialize: ({name}) -> new Foo(name)
    constructor: (@name) ->

  beforeEach ->
    deserializer = new DeserializerManager()
    deserializer.add(Foo)

  it "calls deserialize on the deserializer for the given state object, or returns undefined if one can't be found", ->
    spyOn(console, 'warn')
    object = deserializer.deserialize({ deserializer: 'Foo', name: 'Bar' })
    expect(object.name).toBe 'Bar'
    expect(deserializer.deserialize({ deserializer: 'Bogus' })).toBeUndefined()

  describe "when the deserializer has a version", ->
    beforeEach ->
      Foo.version = 2

    describe "when the deserialized state has a matching version", ->
      it "attempts to deserialize the state", ->
        object = deserializer.deserialize({ deserializer: 'Foo', version: 2, name: 'Bar' })
        expect(object.name).toBe 'Bar'

    describe "when the deserialized state has a non-matching version", ->
      it "returns undefined", ->
        expect(deserializer.deserialize({ deserializer: 'Foo', version: 3, name: 'Bar' })).toBeUndefined()
        expect(deserializer.deserialize({ deserializer: 'Foo', version: 1, name: 'Bar' })).toBeUndefined()
        expect(deserializer.deserialize({ deserializer: 'Foo', name: 'Bar' })).toBeUndefined()
