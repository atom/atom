{Model} = require 'theorist'

module.exports =
class FocusContext extends Model
  @property 'focusedObject', null

  blurSuppressionCounter: 0

  isBlurSuppressed: ->
    @blurSuppressionCounter > 0

  suppressBlur: (fn) ->
    @blurSuppressionCounter++
    fn()
    @blurSuppressionCounter--
