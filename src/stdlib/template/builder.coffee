_ = require 'underscore'
OpenTag = require 'template/open-tag'
CloseTag = require 'template/close-tag'

module.exports =
class Builder
  constructor: ->
    @reset()

  toHtml: ->
    _.map(@document, (x) -> x.toHtml()).join('')

  tag: (name) ->
    @openTag(name)
    @closeTag(name)

  openTag: (name) ->
    @document.push(new OpenTag(name))

  closeTag: (name) ->
    @document.push(new CloseTag(name))

  reset: ->
    @document = []

