_ = require 'underscore-plus'

module.exports =
class Decoration
  @isType: (decoration, decorationType) ->
    if _.isArray(decoration.type)
      decorationType in decoration.type
    else
      decorationType is decoration.type

  constructor: (@marker, properties) ->
    _.extend(this, properties)

  getScreenRange: ->
    @marker?.getScreenRange()

  isValid: ->
    @marker?.isValid()

  isType: (decorationType) ->
    Decoration.isType(this, decorationType)

  toObject: ->
    copy = {}
    copy.valid = @isValid()
    copy.screenRange = @getScreenRange().copy()

    for key, value of this
      copy[key] = value if @hasOwnProperty(key)

    copy
