# Public: Manages the deserializers used for serialized state
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
  # * `classes` One or more classes to register.
  add: (classes...) ->
    @deserializers[klass.name] = klass for klass in classes

  # Public: Remove the given class(es) as deserializers.
  #
  # * `classes` One or more classes to remove.
  remove: (classes...) ->
    delete @deserializers[name] for {name} in classes

  # Public: Deserialize the state and params.
  #
  # * `state` The state {Object} to deserialize.
  # * `params` The params {Object} to pass as the second arguments to the
  #            deserialize method of the deserializer.
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
