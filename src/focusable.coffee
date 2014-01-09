Mixin = require 'mixto'

module.exports =
class Focusable extends Mixin
  @included: ->
    @property 'focusContext'
    @behavior 'focused', ->
      @$focusContext
        .flatMapLatest((context) -> context?.$focusedObject)
        .map((focusedObject) => focusedObject is this)
        .distinctUntilChanged()

  focus: ->
    throw new Error("Object must be assigned a focusContext to be focus") unless @focusContext
    @focusContext.focusedObject = this

  blur: ->
    throw new Error("Object must be assigned a focusContext to be blurred") unless @focusContext
    @focusContext.focusedObject = null if @focused
