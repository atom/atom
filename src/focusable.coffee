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
    unless @focused
      @suppressBlur =>
        @focusContext.focusedObject = this

  blur: ->
    throw new Error("Object must be assigned a focusContext to be blurred") unless @focusContext
    if @focused and not @focusContext.isBlurSuppressed()
      @focusContext.focusedObject = null

  suppressBlur: (fn) ->
    if @focusContext?
      @focusContext.suppressBlur(fn)
    else
      fn()
