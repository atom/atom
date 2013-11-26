{Subscriber} = require 'emissary'
Mixin = require 'mixto'
FocusManager = require './focus-manager'

module.exports =
class Focusable extends Mixin
  Subscriber.includeInto(this)

  @included: ->
    @properties
      focused: false
      focusManager: -> new FocusManager

    @behavior 'focusedDocument', ->
      @$focusManager.flatMapLatest (manager) -> manager.$focusedDocument

  manageFocus: ->
    @subscribe @$focusedDocument, 'value', (focusedDocument) =>
      @focused = this is focusedDocument

    @subscribe @$focused, 'value', (focused) =>
      if focused
        @focusManager.focusedDocument = this
      else if @focusManager.focusedDocument is this
        @focusManager.focusedDocument = null

  setFocused: (@focused) ->

  # Override this if this object has focusable children
  hasFocus: ->
    @focused
