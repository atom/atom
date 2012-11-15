_ = require 'underscore'
{View, $$} = require 'space-pen'

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
        @span class: 'current-path', outlet: 'currentPath'
        @span class: 'buffer-modified', outlet: 'bufferModified'
      @div class: 'cursor-position', =>
        @span class: 'octicons', outlet: 'gitStatusIcon'
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
    @editor.on 'cursor-move', => @updateCursorPositionText()

    @subscribeToBuffer()

  subscribeToBuffer: ->
    @buffer?.off '.status-bar'
    @buffer = @editor.getBuffer()
    @buffer.on 'stopped-changing.status-bar', => @updateBufferModifiedText()
    @buffer.on 'after-save.status-bar', => @updateStatusBar()
    @buffer.on 'git-status-change.status-bar', => @updateStatusBar()
    @updateStatusBar()

  updateStatusBar: ->
    @updateBranchText()
    @updateBufferModifiedText()
    @updateStatusText()

  updateBufferModifiedText: ->
    if @buffer.isModified()
      @bufferModified.text('*') unless @isModified
      @isModified = true
    else
      @bufferModified.text('') if @isModified
      @isModified = false

  updateBranchText: ->
    path = @editor.getPath()
    @branchArea.hide()
    return unless path

    head = @buffer.getGit()?.getShortHead()
    @branchLabel.text(head)
    @branchArea.show() if head

  updateStatusText: ->
    path = @editor.getPath()
    @gitStatusIcon.empty()
    return unless path

    if @buffer.getGit()?.isPathModified(path)
      @gitStatusIcon.append $$ -> @span '\uf26d', class: 'modified-status-icon'
    else if  @buffer.getGit()?.isPathNew(path)
      @gitStatusIcon.append $$ -> @span '\uf26b', class: 'new-status-icon'

  updatePathText: ->
    if path = @editor.getPath()
      @currentPath.text(@rootView.project.relativize(path))
    else
      @currentPath.text('untitled')

  updateCursorPositionText: ->
    { row, column } = @editor.getCursorBufferPosition()
    @cursorPosition.text("#{row + 1},#{column + 1}")
