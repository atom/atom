_ = require 'underscore'
{View, $$} = require 'space-pen'
$ = require 'jquery'

module.exports =
class StatusBarView extends View
  @activate: ->
    rootView.eachEditor (editor) =>
      @appendToEditorPane(rootView, editor) if editor.attached

  @appendToEditorPane: (rootView, editor) ->
    if pane = editor.pane()
      pane.append(new StatusBarView(rootView, editor))

  @content: ->
    @div class: 'status-bar', =>
      @span class: 'git-branch', outlet: 'branchArea', =>
        @span class: 'octicons branch-icon'
        @span class: 'branch-label', outlet: 'branchLabel'
        @span class: 'octicons commits-ahead-label', outlet: 'commitsAhead'
        @span class: 'octicons commits-behind-label', outlet: 'commitsBehind'
        @span class: 'git-status', outlet: 'gitStatusIcon'
      @span class: 'file-info', =>
        @span class: 'current-path', outlet: 'currentPath'
        @span class: 'buffer-modified', outlet: 'bufferModified'
      @span class: 'cursor-position', outlet: 'cursorPosition'
      @span class: 'grammar-name', outlet: 'grammarName'

  initialize: (rootView, @editor) ->
    @updatePathText()
    @editor.on 'editor:path-changed', =>
      @subscribeToBuffer()
      @updatePathText()

    @updateCursorPositionText()
    @subscribe @editor, 'cursor:moved', => @updateCursorPositionText()
    @subscribe @grammarName, 'click', => @editor.trigger 'editor:select-grammar'
    @subscribe @editor, 'editor:grammar-changed', => @updateGrammarText()
    if git?
      @subscribe git, 'status-changed', (path, status) =>
        @updateStatusBar() if path is @buffer?.getPath()
      @subscribe git, 'statuses-changed', =>
        @updateStatusBar()

    @subscribeToBuffer()

  subscribeToBuffer: ->
    @buffer?.off '.status-bar'
    @buffer = @editor.getBuffer()
    @buffer.on 'modified-status-changed.status-bar', (isModified) => @updateBufferHasModifiedText(isModified)
    @buffer.on 'saved.status-bar', => @updateStatusBar()
    @updateStatusBar()

  updateStatusBar: ->
    @updateGrammarText()
    @updateBranchText()
    @updateBufferHasModifiedText(@buffer.isModified())
    @updateStatusText()

  updateGrammarText: ->
    @grammarName.text(@editor.getGrammar().name)

  updateBufferHasModifiedText: (isModified)->
    if isModified
      @bufferModified.text('*') unless @isModified
      @isModified = true
    else
      @bufferModified.text('') if @isModified
      @isModified = false

  updateBranchText: ->
    path = @editor.getPath()
    @branchArea.hide()
    return unless path

    head = git?.getShortHead() or ''
    @branchLabel.text(head)
    @branchArea.show() if head

  updateStatusText: ->
    path = @editor.getPath()
    @gitStatusIcon.removeClass()
    return unless path

    @gitStatusIcon.addClass('git-status octicons')
    return unless git?

    if git.upstream.ahead > 0
      @commitsAhead.text(git.upstream.ahead).show()
    else
      @commitsAhead.hide()

    if git.upstream.behind > 0
      @commitsBehind.text(git.upstream.behind).show()
    else
      @commitsBehind.hide()

    status = git.statuses[path]
    if git.isStatusModified(status)
      @gitStatusIcon.addClass('modified-status-icon')
      stats = git.getDiffStats(path)
      if stats.added and stats.deleted
        @gitStatusIcon.text("+#{stats.added},-#{stats.deleted}")
      else if stats.added
        @gitStatusIcon.text("+#{stats.added}")
      else if stats.deleted
        @gitStatusIcon.text("-#{stats.deleted}")
      else
        @gitStatusIcon.text('')
    else if git.isStatusNew(status)
      @gitStatusIcon.addClass('new-status-icon')
      @gitStatusIcon.text("+#{@buffer.getLineCount()}")

  updatePathText: ->
    if path = @editor.getPath()
      @currentPath.text(project.relativize(path))
    else
      @currentPath.text('untitled')

  updateCursorPositionText: ->
    { row, column } = @editor.getCursorBufferPosition()
    @cursorPosition.text("#{row + 1},#{column + 1}")
