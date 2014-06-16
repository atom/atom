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
    if _.isArray(@type)
      decorationType in @type
    else
      decorationType is @type

  toObject: ->
    copy = {}
    copy.valid = @isValid()
    copy.screenRange = @getScreenRange().copy()

    for key, value of this
      copy[key] = value if @hasOwnProperty(key)

    copy
