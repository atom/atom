_ = require 'underscore'
{View, $$} = require 'space-pen'
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
        @span class: 'current-path', outlet: 'currentPath'
        @span class: 'buffer-modified', outlet: 'bufferModified'
      @div class: 'cursor-position', =>
        @span class: 'octicons', outlet: 'gitStatusIcon'
        @span outlet: 'branchArea', =>
          @span '\uf020', class: 'octicons'
          @span class: 'branch-label', outlet: 'branchLabel'
        @span outlet: 'cursorPosition'

  git: null

  initialize: (@rootView, @editor) ->
    @updatePathText()
    @editor.on 'editor-path-change', =>
      @subscribeToBuffer()
      @updatePathText()

    @updateCursorPositionText()
    @editor.on 'cursor-move', => _.delay (=> @updateCursorPositionText()), 50

    @subscribeToBuffer()

  subscribeToBuffer: ->
    @buffer?.off '.status-bar'
    @buffer = @editor.getBuffer()
    if path = @editor.getPath()
      @git = new Git(path)
    @buffer.on 'change.status-bar', => _.delay (=> @updateBufferModifiedText()), 50
    @buffer.on 'after-save.status-bar', => _.delay (=> @updateStatusBar()), 50
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
    path = @editor.getPath()
    @branchArea.hide()
    return unless path

    head = @git.getShortHead()
    @branchLabel.text(head)
    @branchArea.show() if head

  updateStatusText: ->
    path = @editor.getPath()
    @gitStatusIcon.empty()
    return unless path

    if @git.isPathModified(path)
      @gitStatusIcon.append $$ -> @span '\uf26d', class: 'modified-status-icon'
    else if @git.isPathNew(path)
      @gitStatusIcon.append $$ -> @span '\uf26b', class: 'new-status-icon'


  updatePathText: ->
    if path = @editor.getPath()
      @currentPath.text(@rootView.project.relativize(path))
    else
      @currentPath.text('untitled')

  updateCursorPositionText: ->
    { row, column } = @editor.getCursorBufferPosition()
    @cursorPosition.text("#{row + 1},#{column + 1}")
