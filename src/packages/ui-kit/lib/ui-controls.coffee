{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs-utils'

class UIControl extends View
  @controlContent: ->
  @controlClass: ""
  @content: ->
    @div class: "ui-control #{@controlClass}", => @controlContent()
  initialize: ->
    @parentView = null
  inView: -> @parentView?
  setTitle: (title) ->
    @controlElement?.text(title)


class UIButton extends UIControl
  @controlContent: ->
    @button outlet:"controlElement"
  @controlClass: "button"
  initialize: (options={}) ->
    @title = options.title
    @setTitle(@title)
    super

class UITextField extends UIControl
  @controlContent: ->
    @input outlet:"controlElement"
  @controlClass: "text-field"

module.exports =
  button: UIButton
  textField: UITextField