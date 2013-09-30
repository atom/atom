{Document} = require 'telepath'

module.exports =
class DeserializerManager
  constructor: ->
    @deserializers = {}
    @deferredDeserializers = {}

  registerDeserializer: (klasses...) ->
    @deserializers[klass.name] = klass for klass in klasses

  registerDeferredDeserializer: (name, fn) ->
    @deferredDeserializers[name] = fn

  unregisterDeserializer: (klasses...) ->
    delete @deserializers[klass.name] for klass in klasses

  deserialize: (state, params) ->
    return unless state?

    if deserializer = @getDeserializer(state)
      stateVersion = state.get?('version') ? state.version
      return if deserializer.version? and deserializer.version isnt stateVersion
      if (state instanceof Document) and not deserializer.acceptsDocuments
        state = state.toObject()
      deserializer.deserialize(state, params)
    else
      console.warn "No deserializer found for", state

  getDeserializer: (state) ->
    return unless state?

    name = state.get?('deserializer') ? state.deserializer
    if @deferredDeserializers[name]
      @deferredDeserializers[name]()
      delete @deferredDeserializers[name]

    @deserializers[name]
