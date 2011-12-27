_ = require 'underscore'
OpenTag = require 'template/open-tag'
CloseTag = require 'template/close-tag'
Text = require 'template/text'

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
    @text(options.text) if options.text
    @closeTag(name)

  extractOptions: (args) ->
    options = {}
    for arg in args
      options.content = arg if _.isFunction(arg)
      options.text = arg if _.isString(arg)
      options.text = arg.toString() if _.isNumber(arg)
    options

  openTag: (name) ->
    @document.push(new OpenTag(name))

  closeTag: (name) ->
    @document.push(new CloseTag(name))

  text: (string) ->
    @document.push(new Text(string))

  reset: ->
    @document = []

