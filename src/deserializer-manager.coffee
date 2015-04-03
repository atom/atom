{Disposable} = require 'event-kit'
Grim = require 'grim'

# Extended: Manages the deserializers used for serialized state
#
# An instance of this class is always available as the `atom.deserializers`
# global.
#
# ## Examples
#
# ```coffee
# class MyPackageView extends View
#   atom.deserializers.add(this)
#
#   @deserialize: (state) ->
#     new MyPackageView(state)
#
#   constructor: (@state) ->
#
#   serialize: ->
#     @state
# ```
module.exports =
class DeserializerManager
  constructor: ->
    @deserializers = {}

  # Public: Register the given class(es) as deserializers.
  #
  # * `deserializers` One or more deserializers to register. A deserializer can
  #   be any object with a `.name` property and a `.deserialize()` method. A
  #   common approach is to register a *constructor* as the deserializer for its
  #   instances by adding a `.deserialize()` class method.
  add: (deserializers...) ->
    @deserializers[deserializer.name] = deserializer for deserializer in deserializers
    new Disposable =>
      delete @deserializers[deserializer.name] for deserializer in deserializers
      return

  # Public: Deserialize the state and params.
  #
  # * `state` The state {Object} to deserialize.
  # * `params` The params {Object} to pass as the second arguments to the
  #   deserialize method of the deserializer.
  deserialize: (state, params) ->
    return unless state?

    if deserializer = @get(state)
      stateVersion = state.get?('version') ? state.version
      return if deserializer.version? and deserializer.version isnt stateVersion
      deserializer.deserialize(state, params)
    else
      console.warn "No deserializer found for", state

  # Get the deserializer for the state.
  #
  # * `state` The state {Object} being deserialized.
  get: (state) ->
    return unless state?

    name = state.get?('deserializer') ? state.deserializer
    @deserializers[name]

if Grim.includeDeprecatedAPIs
  DeserializerManager::remove = (classes...) ->
    Grim.deprecate("Call .dispose() on the Disposable return from ::add instead")
    delete @deserializers[name] for {name} in classes
    return
