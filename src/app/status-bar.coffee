{View} = require 'space-pen'

module.exports =
class StatusBar extends View
  @activate: (rootView) ->
    requireStylesheet 'status-bar.css'

    for editor in rootView.getEditors()
      @appendToEditorPane(rootView, editor) if rootView.parents('html').length

    rootView.on 'editor-open', (e, editor) =>
      @appendToEditorPane(rootView, editor)

  @appendToEditorPane: (rootView, editor) ->
    if pane = editor.pane()
      pane.append(new StatusBar(rootView, editor))

  @content: ->
    @div class: 'status-bar', =>
      @div class: 'file-info', =>
        @div class: 'current-path', outlet: 'currentPath'
        @div class: 'buffer-modified', outlet: 'bufferModified'
      @div class: 'cursor-position', outlet: 'cursorPosition'

  initialize: (@rootView, @editor) ->
    @updatePathText()
    @editor.on 'editor-path-change', =>
      @subscribeToBuffer()
      @updatePathText()

    @updateCursorPositionText()
    @editor.on 'cursor-move', => @updateCursorPositionText()

    @subscribeToBuffer()

  subscribeToBuffer: ->
    @buffer?.off '.status-bar'
    @buffer = @editor.getBuffer()
    @buffer.on 'change.status-bar', => @updateBufferModifiedText()
    @buffer.on 'after-save.status-bar', => @updateBufferModifiedText()
    @updateBufferModifiedText()

  updateBufferModifiedText: ->
    if @buffer.isModified() and @buffer.contentDifferentOnDisk()
      @bufferModified.text('*')
    else
      @bufferModified.text('')

  updatePathText: ->
    path = @editor.getPath()
    if path
      @currentPath.text(@rootView.project.relativize(path))
    else
      @currentPath.text('untitled')

  updateCursorPositionText: ->
    { row, column } = @editor.getCursorBufferPosition()
    @cursorPosition.text("#{row + 1},#{column + 1}")
