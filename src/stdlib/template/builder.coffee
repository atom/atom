_ = require 'underscore'
OpenTag = require 'template/open-tag'
CloseTag = require 'template/close-tag'

module.exports =
class Builder
  constructor: ->
    @reset()

  toHtml: ->
    _.map(@document, (x) -> x.toHtml()).join('')

  tag: (name, args...) ->
    options = @extractOptions(args)
    @openTag(name)
    options.content?()
    @closeTag(name)

  extractOptions: (args) ->
    options = {}
    for arg in args
      options.content = arg if _.isFunction(arg)
    options

  openTag: (name) ->
    @document.push(new OpenTag(name))

  closeTag: (name) ->
    @document.push(new CloseTag(name))

  reset: ->
    @document = []

