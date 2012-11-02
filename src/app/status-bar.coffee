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
        @span '\uf252', class: 'octicons git-status', outlet: 'gitStatusIcon'
        @span class: 'current-path', outlet: 'currentPath'
        @span class: 'buffer-modified', outlet: 'bufferModified'
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

    @updateCursorPositionText()
    @editor.on 'cursor-move', => _.defer => @updateCursorPositionText()

    @subscribeToBuffer()

  subscribeToBuffer: ->
    @buffer?.off '.status-bar'
    @buffer = @editor.getBuffer()
    @buffer.on 'change.status-bar', => _.defer => @updateBufferModifiedText()
    @buffer.on 'after-save.status-bar', => _.defer => @updateStatusBar()
    @updateStatusBar()

  updateStatusBar: ->
    @updateBranchText()
    @updateBufferModifiedText()
    @updateStatusText()

  updateBufferModifiedText: ->
    if @buffer.isModified()
      @bufferModified.text('*')
    else
      @bufferModified.text('')

  updateBranchText: ->
    if path = @editor.getPath()
      @head = new Git(path).getShortHead()
    else
      @head = ''

    @branchLabel.text(@head)
    if @head
      @branchArea.show()
    else
      @branchArea.hide()

  updateStatusText: ->
    if path = @editor.getPath()
      modified = new Git(path).isModified(path)

    if modified
      @gitStatusIcon.show()
    else
      @gitStatusIcon.hide()

  updatePathText: ->
    if path = @editor.getPath()
      @currentPath.text(@rootView.project.relativize(path))
    else
      @currentPath.text('untitled')

  updateCursorPositionText: ->
    { row, column } = @editor.getCursorBufferPosition()
    @cursorPosition.text("#{row + 1},#{column + 1}")
