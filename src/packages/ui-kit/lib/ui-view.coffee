{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs-utils'

module.exports =
class UIView extends View
  @content: ->
    @div class:"ui-view", =>
      @input class: 'hidden-input', outlet: 'hiddenInput'
      @div class: 'close-icon', outlet:"closeIcon"
      @div class:"header", outlet:"header"
      @div class:"content", outlet:"content"
      @div class:"footer", outlet:"footer"
  initialize: (options={position:"full"}) ->
    @title = ""
    @visible = false
    @on 'focus', =>
      @hiddenInput.focus()
      false
    if options.position == "dialog"
      @addClass("dialog")
    @closeIcon.on 'click', => @close()
    @command 'ui-view:default-button', =>
      @find("button.default").click()
    @command 'ui-view:cancel-button', =>
      @close(false)
  setTitle: (@title) ->
    @header.empty().append($("<h2>").text(@title))
  addSubview: (view) ->
    view.parentView = this
    v = if view.content? then view.content else view
    @content.append(v)
  addToPane: (pane) ->
  addToRootView: ->
    rootView.append(this)
    @focus()
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