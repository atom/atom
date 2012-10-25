{View} = require 'space-pen'
_ = require 'underscore'
Git = require 'git'

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
      @div class: 'cursor-position', =>
        @span outlet: 'branchArea', =>
          @span '\uf020', class: 'octicons'
          @span class: 'branch-label', outlet: 'branchLabel'
        @span outlet: 'cursorPosition'

  initialize: (@rootView, @editor) ->
    @updatePathText()
    @editor.on 'editor-path-change', =>
      @subscribeToBuffer()
      @updatePathText()

    @updateBranchText()
    @updateCursorPositionText()
    @editor.on 'cursor-move', => _.defer => @updateCursorPositionText()

    @subscribeToBuffer()

  subscribeToBuffer: ->
    @buffer?.off '.status-bar'
    @buffer = @editor.getBuffer()
    @buffer.on 'change.status-bar', => _.defer => @updateBufferModifiedText()
    @buffer.on 'after-save.status-bar', => _.defer =>
      @updateBranchText()
      @updateBufferModifiedText()
    @updateBranchText()
    @updateBufferModifiedText()

  updateBufferModifiedText: ->
    if @buffer.isModified()
      @bufferModified.text('*')
    else
      @bufferModified.text('')

  updateBranchText: ->
    if path = @editor.getPath()
      @head = new Git(path).getShortHead()
    else
      @head = null

    if @head
      @branchArea.show()
      @branchLabel.text(@head)
    else
      @branchArea.hide()

  updatePathText: ->
    if path = @editor.getPath()
      @currentPath.text(@rootView.project.relativize(path))
    else
      @currentPath.text('untitled')

  updateCursorPositionText: ->
    { row, column } = @editor.getCursorBufferPosition()
    @cursorPosition.text("#{row + 1},#{column + 1}")
