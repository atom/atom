_ = require 'underscore-plus'

IdCounter = 1

module.exports =
class Decoration
  @isType: (decoration, decorationType) ->
    if _.isArray(decoration.type)
      decorationType in decoration.type
    else
      decorationType is decoration.type

  constructor: (@marker, properties) ->
    @id = IdCounter++
    _.extend(this, properties)

  getScreenRange: ->
    @marker?.getScreenRange()

  isValid: ->
    @marker?.isValid()

  isType: (decorationType) ->
    Decoration.isType(this, decorationType)

  toObject: ->
    copy = {}
    copy.id = @id
    copy.valid = @isValid()
    copy.screenRange = @getScreenRange().copy()

    for key, value of this
      copy[key] = value if @hasOwnProperty(key)

    copy
