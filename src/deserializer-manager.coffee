{Document} = require 'telepath'

# Public: Manages the deserializers used for serialized state
module.exports =
class DeserializerManager
  constructor: ->
    @deserializers = {}
    @deferredDeserializers = {}

  # Public: Register the given class(es) as deserializers.
  add: (klasses...) ->
    @deserializers[klass.name] = klass for klass in klasses

  # Public: Add a deferred deserializer for the given class name.
  addDeferred: (name, fn) ->
    @deferredDeserializers[name] = fn

  # Public: Remove the given class(es) as deserializers.
  remove: (klasses...) ->
    delete @deserializers[klass.name] for klass in klasses

  # Public: Deserialize the state and params.
  deserialize: (state, params) ->
    return unless state?

    if deserializer = @get(state)
      stateVersion = state.get?('version') ? state.version
      return if deserializer.version? and deserializer.version isnt stateVersion
      if (state instanceof Document) and not deserializer.acceptsDocuments
        state = state.toObject()
      deserializer.deserialize(state, params)
    else
      console.warn "No deserializer found for", state

  # Private: Get the deserializer for the state.
  get: (state) ->
    return unless state?

    name = state.get?('deserializer') ? state.deserializer
    if @deferredDeserializers[name]
      @deferredDeserializers[name]()
      delete @deferredDeserializers[name]

    @deserializers[name]
