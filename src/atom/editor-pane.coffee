$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'
Pane = require 'pane'

ace = require 'ace/ace'

module.exports =
class EditorPane extends Pane
  position: 'main'
  editor: null

  show: ->
    super

    return if @ace
    @ace = ace.edit @paneID

    # Resize editor when panes are added/removed
    el = document.body
    el.addEventListener 'DOMNodeInsertedIntoDocument', => @resize()
    el.addEventListener 'DOMNodeRemovedFromDocument', => @resize()

  remove: ->
    @pane?.remove()

  resize: (timeout=1) ->
    setTimeout =>
      @ace.focus()
      @ace.resize()
    , timeout
