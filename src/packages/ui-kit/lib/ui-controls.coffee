{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs-utils'

class UIControl extends View
  @controlContent: ->
  @content: ->
    @div class: "ui-control", => @controlContent()


class UIButton extends UIControl
  @controlContent: ->
    @button outlet:"controlElement"

class UITextField extends UIControl

module.exports =
  button: UIButton
  textField: UITextField