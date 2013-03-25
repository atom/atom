{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs-utils'

module.exports =
class UIView extends View
  @content: ->
    @div class:"ui-view", =>
      @div class: 'close-icon', outlet:"closeIcon"
      @div class:"header", outlet:"header"
      @div class:"content", outlet:"content"
      @div class:"footer", outlet:"footer"
  initialize: (options={position:"full"}) ->
    @title = ""
    @visible = false
    if options.position == "dialog"
      @addClass("dialog")
    @closeIcon.on 'click', => @close()
  setTitle: (@title) ->
    @header.empty().append($("<h2>").text(@title))
  addSubview: (view) ->
    view.parentView = this
    @content.append(view)
  addToPane: (pane) ->
  addToRootView: ->
    rootView.append(this)
    @visible = true
  runModalDialog: (callback) ->
    @addToRootView()
    @addClass("modal")
    @modalCallback = callback
  close: (value=true) ->
    @modalCallback?(value)
    @modalCallback = null
    @visible = false
    @remove()