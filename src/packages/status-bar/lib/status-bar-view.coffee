_ = require 'underscore'
{View, $$} = require 'space-pen'
$ = require 'jquery'

module.exports =
class StatusBarView extends View
  @activate: ->
    rootView.eachPane (pane) =>
      pane.append(new StatusBarView(rootView, pane))

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

  initialize: (rootView, @pane) ->
    @updatePathText()
    @subscribe @pane, 'pane:active-item-changed', =>
      @subscribeToBuffer()
      @updatePathText()
    @subscribe @pane, 'pane:active-item-title-changed', =>
      @updatePathText()

    @subscribe @pane, 'cursor:moved', => @updateCursorPositionText()
    @subscribe @grammarName, 'click', => @pane.activeView.trigger 'grammar-selector:show'
    @subscribe @pane, 'editor:grammar-changed', => @updateGrammarText()

    repo = project.getRepo()
    if repo?
      @subscribe repo, 'status-changed', (path, status) =>
        @updateStatusBar() if path is @getActiveItemPath()
      @subscribe repo, 'statuses-changed', @updateStatusBar

    @subscribeToBuffer()

  beforeRemove: ->
    @unsubscribeFromBuffer()

  getActiveItemPath: ->
    @pane.activeItem?.getPath?()

  unsubscribeFromBuffer: ->
    if @buffer?
      @buffer.off 'modified-status-changed', @updateBufferHasModifiedText
      @buffer.off 'saved', @updateStatusBar
      @buffer = null

  subscribeToBuffer: ->
    @unsubscribeFromBuffer()
    if @buffer = @pane.activeItem.getBuffer?()
      @buffer.on 'modified-status-changed', @updateBufferHasModifiedText
      @buffer.on 'saved', @updateStatusBar

    @updateStatusBar()

  updateStatusBar: =>
    @updateGrammarText()
    @updateBranchText()
    @updateBufferHasModifiedText(@buffer?.isModified())
    @updateStatusText()
    @updateCursorPositionText()

  updateGrammarText: ->
    grammar = @pane.activeView.getGrammar?()
    if not grammar? or grammar is syntax.nullGrammar
      @grammarName.hide()
    else
      @grammarName.text(grammar.name).show()

  updateBufferHasModifiedText: (isModified) =>
    if isModified
      @bufferModified.text('*') unless @isModified
      @isModified = true
    else
      @bufferModified.text('') if @isModified
      @isModified = false

  updateBranchText: ->
    @branchArea.hide()
    return unless project.contains(@getActiveItemPath())

    head = project.getRepo()?.getShortHead() or ''
    @branchLabel.text(head)
    @branchArea.show() if head

  updateStatusText: ->
    itemPath = @getActiveItemPath()
    @gitStatusIcon.removeClass()
    return unless project.contains(itemPath)

    @gitStatusIcon.addClass('git-status octicons')
    repo = project.getRepo()
    return unless repo?

    if repo.upstream.ahead > 0
      @commitsAhead.text(repo.upstream.ahead).show()
    else
      @commitsAhead.hide()

    if repo.upstream.behind > 0
      @commitsBehind.text(repo.upstream.behind).show()
    else
      @commitsBehind.hide()

    status = repo.statuses[itemPath]
    if repo.isStatusModified(status)
      @gitStatusIcon.addClass('modified-status-icon')
      stats = repo.getDiffStats(itemPath)
      if stats.added and stats.deleted
        @gitStatusIcon.text("+#{stats.added},-#{stats.deleted}")
      else if stats.added
        @gitStatusIcon.text("+#{stats.added}")
      else if stats.deleted
        @gitStatusIcon.text("-#{stats.deleted}")
      else
        @gitStatusIcon.text('')
    else if repo.isStatusNew(status)
      @gitStatusIcon.addClass('new-status-icon')
      if @buffer?
        @gitStatusIcon.text("+#{@buffer.getLineCount()}")
      else
        @gitStatusIcon.text('')
    else if repo.isPathIgnored(itemPath)
      @gitStatusIcon.addClass('ignored-status-icon')
      @gitStatusIcon.text('')

  updatePathText: ->
    if path = @getActiveItemPath()
      @currentPath.text(project.relativize(path)).show()
    else if title = @pane.activeItem.getTitle?()
      @currentPath.text(title).show()
    else
      @currentPath.hide()

  updateCursorPositionText: ->
    if position = @pane.activeView.getCursorBufferPosition?()
      @cursorPosition.text("#{position.row + 1},#{position.column + 1}").show()
    else
      @cursorPosition.hide()
