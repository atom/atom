{Subscriber} = require 'emissary'
Mixin = require 'mixto'

module.exports =
class Focusable extends Mixin
  Subscriber.includeInto(this)

  @included: ->
    @properties
      focused: false
      focusManager: null

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
