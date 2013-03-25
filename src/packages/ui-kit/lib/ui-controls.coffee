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
  initialize: (options={}) ->
    @parentView = null
    @action = options.action
  inView: -> @parentView?
  setTitle: (title) ->
    @controlElement?.text(title)


class UIButton extends UIControl
  @controlContent: ->
    @button outlet:"controlElement"
  @controlClass: "button"
  initialize: (options={}) ->
    super
    @title = options.title
    @default = options.default
    @cancel = options.cancel
    @setTitle(@title)
    if @action?
      @controlElement.on 'click', => @action.apply(this)
    if @default == true
      @controlElement.addClass("default")
    if @cancel == true
      @controlElement.addClass("cancel")

class UITextField extends UIControl
  @controlContent: ->
    @input outlet:"controlElement"
  @controlClass: "text-field"
  initialize: (options={}) ->
    super
    @on 'focus', =>
      @controlElement.focus()
      false

module.exports =
  button: UIButton
  textField: UITextField