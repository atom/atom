$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'
Pane = require 'pane'

ace = require 'ace/ace'

module.exports =
class EditorPane extends Pane
  id: null
  html: null
  position: 'main'
  editor: null

  constructor: ->
    @id = _.uniqueId 'editor-'
    @html = $ "<div id='#{@id}'></div>"

  show: ->
    super

    return if @ace
    @ace = ace.edit @id

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
