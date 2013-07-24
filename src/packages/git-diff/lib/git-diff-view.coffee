_ = require 'underscore'
Subscriber = require 'subscriber'

module.exports =
class GitDiffView
  constructor: (@editor) ->
    @gutter = @editor.gutter
    @diffs = {}

    @subscribe @editor, 'editor:path-changed', @subscribeToBuffer
    @subscribe @editor, 'editor:display-updated', @renderDiffs
    @subscribe project.getRepo(), 'statuses-changed', =>
      @diffs = {}
      @scheduleUpdate()
    @subscribe project.getRepo(), 'status-changed', (path) =>
      delete @diffs[path]
      @scheduleUpdate() if path is @editor.getPath()

    @subscribeToBuffer()

    @subscribe @editor, 'editor:will-be-removed', =>
      @unsubscribe()
      @unsubscribeFromBuffer()

  unsubscribeFromBuffer: ->
    if @buffer?
      @removeDiffs()
      delete @diffs[@buffer.getPath()] if @buffer.destroyed
      @buffer.off 'contents-modified', @updateDiffs
      @buffer = null

  subscribeToBuffer: =>
    @unsubscribeFromBuffer()

    if @buffer = @editor.getBuffer()
      @scheduleUpdate() unless @diffs[@buffer.getPath()]?
      @buffer.on 'contents-modified', @updateDiffs

  scheduleUpdate: ->
    _.nextTick(@updateDiffs)

  updateDiffs: =>
    return unless @buffer?
    @generateDiffs()
    @renderDiffs()

  generateDiffs: ->
    if path = @buffer.getPath()
      @diffs[path] = project.getRepo()?.getLineDiffs(path, @buffer.getText())

  removeDiffs: =>
    if @gutter.hasGitLineDiffs
      @gutter.find('.line-number').removeClass('git-line-added git-line-modified git-line-removed')
      @gutter.hasGitLineDiffs = false

  renderDiffs: =>
    return unless @gutter.isVisible()

    @removeDiffs()

    hunks = @diffs[@editor.getPath()] ? []
    linesHighlighted = 0
    for {oldStart, newStart, oldLines, newLines} in hunks
      if oldLines is 0 and newLines > 0
        for row in [newStart...newStart + newLines]
          linesHighlighted += @gutter.find(".line-number[lineNumber=#{row - 1}]").addClass('git-line-added').length
      else if newLines is 0 and oldLines > 0
        linesHighlighted += @gutter.find(".line-number[lineNumber=#{newStart - 1}]").addClass('git-line-removed').length
      else
        for row in [newStart...newStart + newLines]
          linesHighlighted += @gutter.find(".line-number[lineNumber=#{row - 1}]").addClass('git-line-modified').length
    @gutter.hasGitLineDiffs = linesHighlighted > 0

_.extend GitDiffView.prototype, Subscriber
