$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'
Pane = require 'pane'

ace = require 'ace/ace'

module.exports =
class EditorPane extends Pane
  html: $ "<div id='ace-editor'></div>"

  position: 'main'

  editor: null

  constructor: ->
    @show()

    @ace = ace.edit 'ace-editor'

    # This stuff should all be grabbed from the .atomicity dir
    @ace.setTheme require "ace/theme/twilight"
    @ace.getSession().setUseSoftTabs true
    @ace.getSession().setTabSize 2
    @ace.setShowInvisibles true
    @ace.setPrintMarginColumn 78

    # Resize editor when panes are added/removed
    el = document.body
    el.addEventListener 'DOMNodeInsertedIntoDocument', => @resize()
    el.addEventListener 'DOMNodeRemovedFromDocument', => @resize()

  resize: (timeout=1) ->
    setTimeout =>
      @ace.focus()
      @ace.resize()
    , timeout
