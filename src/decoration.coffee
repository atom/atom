_ = require 'underscore-plus'
EmitterMixin = require('emissary').Emitter
{Emitter} = require 'event-kit'
Grim = require 'grim'

idCounter = 0
nextId = -> idCounter++

# Essential: Represents a decoration that follows a {Marker}. A decoration is
# basically a visual representation of a marker. It allows you to add CSS
# classes to line numbers in the gutter, lines, and add selection-line regions
# around marked ranges of text.
#
# {Decoration} objects are not meant to be created directly, but created with
# {TextEditor::decorateMarker}. eg.
#
# ```coffee
# range = editor.getSelectedBufferRange() # any range you like
# marker = editor.markBufferRange(range)
# decoration = editor.decorateMarker(marker, {type: 'line', class: 'my-line-class'})
# ```
#
# Best practice for destorying the decoration is by destroying the {Marker}.
#
# ```coffee
# marker.destroy()
# ```
#
# You should only use {Decoration::destroy} when you still need or do not own
# the marker.
module.exports =
class Decoration
  EmitterMixin.includeInto(this)

  # Private: Check if the `decorationProperties.type` matches `type`
  #
  # * `decorationProperties` {Object} eg. `{type: 'line-number', class: 'my-new-class'}`
  # * `type` {String} type like `'line-number'`, `'line'`, etc. `type` can also
  #   be an {Array} of {String}s, where it will return true if the decoration's
  #   type matches any in the array.
  #
  # Returns {Boolean}
  @isType: (decorationProperties, type) ->
    if _.isArray(decorationProperties.type)
      type in decorationProperties.type
    else
      type is decorationProperties.type

  ###
  Section: Construction and Destruction
  ###

  constructor: (@marker, @displayBuffer, @properties) ->
    @emitter = new Emitter
    @id = nextId()
    @properties.id = @id
    @flashQueue = null
    @destroyed = false

    @markerDestroyDisposable = @marker.onDidDestroy => @destroy()

  # Essential: Destroy this marker.
  #
  # If you own the marker, you should use {Marker::destroy} which will destroy
  # this decoration.
  destroy: ->
    return if @destroyed
    @markerDestroyDisposable.dispose()
    @markerDestroyDisposable = null
    @destroyed = true
    @emit 'destroyed'
    @emitter.emit 'did-destroy'
    @emitter.dispose()

  ###
  Section: Event Subscription
  ###

  # Essential: When the {Decoration} is updated via {Decoration::update}.
  #
  # * `callback` {Function}
  #   * `event` {Object}
  #     * `oldProperties` {Object} the old parameters the decoration used to have
  #     * `newProperties` {Object} the new parameters the decoration now has
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeProperties: (callback) ->
    @emitter.on 'did-change-properties', callback

  # Essential: Invoke the given callback when the {Decoration} is destroyed
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  ###
  Section: Decoration Details
  ###

  # Essential: An id unique across all {Decoration} objects
  getId: -> @id

  # Essential: Returns the marker associated with this {Decoration}
  getMarker: -> @marker

  # Public: Check if this decoration is of type `type`
  #
  # * `type` {String} type like `'line-number'`, `'line'`, etc. `type` can also
  #   be an {Array} of {String}s, where it will return true if the decoration's
  #   type matches any in the array.
  #
  # Returns {Boolean}
  isType: (type) ->
    Decoration.isType(@properties, type)

  ###
  Section: Properties
  ###

  # Essential: Returns the {Decoration}'s properties.
  getProperties: ->
    @properties
  getParams: ->
    Grim.deprecate 'Use Decoration::getProperties instead'
    @getProperties()

  # Essential: Update the marker with new Properties. Allows you to change the decoration's class.
  #
  # ## Examples
  #
  # ```coffee
  # decoration.update({type: 'line-number', class: 'my-new-class'})
  # ```
  #
  # * `newProperties` {Object} eg. `{type: 'line-number', class: 'my-new-class'}`
  setProperties: (newProperties) ->
    return if @destroyed
    oldProperties = @properties
    @properties = newProperties
    @properties.id = @id
    @emit 'updated', {oldParams: oldProperties, newParams: newProperties}
    @emitter.emit 'did-change-properties', {oldProperties, newProperties}
  update: (newProperties) ->
    Grim.deprecate 'Use Decoration::setProperties instead'
    @setProperties(newProperties)

  ###
  Section: Private methods
  ###

  matchesPattern: (decorationPattern) ->
    return false unless decorationPattern?
    for key, value of decorationPattern
      return false if @properties[key] != value
    true

  onDidFlash: (callback) ->
    @emitter.on 'did-flash', callback

  flash: (klass, duration=500) ->
    flashObject = {class: klass, duration}
    @flashQueue ?= []
    @flashQueue.push(flashObject)
    @emit 'flash'
    @emitter.emit 'did-flash'

  consumeNextFlash: ->
    return @flashQueue.shift() if @flashQueue?.length > 0
    null

  on: (eventName) ->
    switch eventName
      when 'updated'
        Grim.deprecate 'Use Decoration::onDidChangeProperties instead'
      when 'destroyed'
        Grim.deprecate 'Use Decoration::onDidDestroy instead'
      when 'flash'
        Grim.deprecate 'Use Decoration::onDidFlash instead'
      else
        Grim.deprecate 'Decoration::on is deprecated. Use event subscription methods instead.'

    EmitterMixin::on.apply(this, arguments)
