$ = require 'jquery'

Pane = require 'pane'

module.exports = 
class EditorPane extends Pane
  position: 'main'

  html: $ '<div id="editor"></div>'

  # You know what I don't like? This constructor.
  constructor: (@window, @editor) ->
    super @window

    # Resize editor when panes are added/removed
    el = document.body
    el.addEventListener 'DOMNodeInsertedIntoDocument', => @resize()
    el.addEventListener 'DOMNodeRemovedFromDocument', => @resize()

  resize: (timeout=1) ->
    setTimeout =>
      @editor.ace.focus()
      @editor.ace.resize()
    , timeout
