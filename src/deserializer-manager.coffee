{Disposable} = require 'event-kit'

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
  constructor: (@atomEnvironment) ->
    @deserializers = {}

  # Public: Register the given class(es) as deserializers.
  #
  # * `deserializers` One or more deserializers to register. A deserializer can
  #   be any object with a `.name` property and a `.deserialize()` method. A
  #   common approach is to register a *constructor* as the deserializer for its
  #   instances by adding a `.deserialize()` class method. When your method is
  #   called, it will be passed serialized state as the first argument and the
  #   {Atom} environment object as the second argument, which is useful if you
  #   wish to avoid referencing the `atom` global.
  add: (deserializers...) ->
    @deserializers[deserializer.name] = deserializer for deserializer in deserializers
    new Disposable =>
      delete @deserializers[deserializer.name] for deserializer in deserializers
      return

  # Public: Deserialize the state and params.
  #
  # * `state` The state {Object} to deserialize.
  deserialize: (state) ->
    return unless state?

    if deserializer = @get(state)
      stateVersion = state.get?('version') ? state.version
      return if deserializer.version? and deserializer.version isnt stateVersion
      deserializer.deserialize(state, @atomEnvironment)
    else
      console.warn "No deserializer found for", state

  # Get the deserializer for the state.
  #
  # * `state` The state {Object} being deserialized.
  get: (state) ->
    return unless state?

    name = state.get?('deserializer') ? state.deserializer
    @deserializers[name]

  clear: ->
    @deserializers = {}
