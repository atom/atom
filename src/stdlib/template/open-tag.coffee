_ = require 'underscore'

module.exports =
class OpenTag
  constructor: (@name, @attributes) ->

  toHtml: ->
    "<#{@name}#{@attributesHtml()}>"

  attributesHtml: ->
    s = _.map(@attributes, (value, key) -> "#{key}=\"#{value}\"").join(' ')
    if s == "" then "" else " " + s
