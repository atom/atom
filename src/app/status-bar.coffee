{View} = require 'space-pen'

module.exports =
class StatusBar extends View
  @initialize: (rootView) ->
    for editor in rootView.editors()
      @appendToEditorPane(rootView, editor)

    rootView.on 'editor-open', (e, editor) =>
      @appendToEditorPane(rootView, editor)

  @appendToEditorPane: (rootView, editor) ->
    if pane = editor.pane()
      pane.append(new StatusBar(rootView, editor))

  @content: ->
    @div class: 'status-bar', =>
      @div class: 'current-path', outlet: 'currentPath'
      @div class: 'cursor-position', outlet: 'cursorPosition'

  initialize: (@rootView, @editor) ->
    path = @editor.buffer.path
    if path
      @currentPath.text(@rootView.project.relativize(path))
    else
      @currentPath.text('untitled')

    position = @editor.getCursorBufferPosition()
    @cursorPosition.text("#{position.row},#{position.column}")
