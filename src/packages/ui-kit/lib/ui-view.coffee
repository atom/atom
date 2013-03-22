{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs-utils'

module.exports =
class UIView extends View
  @content: ->
    @div class:"ui-view", =>
      @div class:"header"
      @div class:"content", outlet:"content"
      @div class:"footer"
  addSubview: (view) ->
    @content.append(view)
  addToPane: (pane) ->
  addToRootView: ->
  runModalDialog: (callback) ->
  close: ->