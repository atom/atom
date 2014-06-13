_ = require 'underscore-plus'

module.exports =
class Decoration
  constructor: (@marker, properties) ->
    _.extend(this, properties)

  getScreenRange: ->
    @marker?.getScreenRange()

  isValid: ->
    @marker?.isValid()

  isType: (decorationType) ->
    return true unless @type
    decorationType is @type
