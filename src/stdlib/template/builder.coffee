_ = require 'underscore'
$ = require 'jquery'
OpenTag = require 'template/open-tag'
CloseTag = require 'template/close-tag'
Text = require 'template/text'

module.exports =
class Builder
  constructor: ->
    @reset()

  toHtml: ->
    _.map(@document, (x) -> x.toHtml()).join('')

  toFragment: ->
    $(@toHtml())

  tag: (name, args...) ->
    options = @extractOptions(args)
    @openTag(name, options.attributes)
    options.content?()
    @text(options.text) if options.text
    @closeTag(name)

  extractOptions: (args) ->
    options = {}
    for arg in args
      options.content = arg if _.isFunction(arg)
      options.text = arg if _.isString(arg)
      options.text = arg.toString() if _.isNumber(arg)
      options.attributes = arg if _.isObject(arg)
    options

  openTag: (name, attributes) ->
    @document.push(new OpenTag(name, attributes))

  closeTag: (name) ->
    @document.push(new CloseTag(name))

  text: (string) ->
    @document.push(new Text(string))

  reset: ->
    @document = []

