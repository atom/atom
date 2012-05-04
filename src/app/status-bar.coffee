{View} = require 'space-pen'

module.exports =
class StatusBar extends View
  @activate: (rootView) ->
    requireStylesheet 'status-bar.css'

    for editor in rootView.editors()
      @appendToEditorPane(rootView, editor) if rootView.parents('html').length

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
    @updatePathText()
    @editor.on 'editor-path-change', => @updatePathText()

    @updateCursorPositionText()
    @editor.on 'cursor-move', => @updateCursorPositionText()

  updatePathText: ->
    path = @editor.buffer.path
    if path
      @currentPath.text(@rootView.project.relativize(path))
    else
      @currentPath.text('untitled')

  updateCursorPositionText: ->
    { row, column } = @editor.getCursorBufferPosition()
    @cursorPosition.text("#{row + 1},#{column + 1}")

