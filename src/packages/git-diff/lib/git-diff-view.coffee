_ = require 'underscore'

module.exports =
class GitDiffView
  diffs: null
  editor: null

  constructor: (@editor) ->
    @gutter = @editor.gutter
    @diffs = {}

    @editor.on 'editor:path-changed', => @subscribeToBuffer()
    @editor.on 'editor:display-updated', => @renderDiffs()
    git.on 'statuses-changed', =>
      @diffs = {}
      @scheduleDiffs()
    git.on 'status-changed', (path) =>
      delete @diffs[path]
      @scheduleDiffs() if path is @editor.getPath()

    @subscribeToBuffer()

  subscribeToBuffer: ->
    if @buffer?
      @removeDiffs()
      delete @diffs[@buffer.getPath()] if @buffer.destroyed
      @buffer.off '.git-diff'
      @buffer = null

    if @buffer = @editor.getBuffer()
      @scheduleDiffs() unless @diffs[@buffer.getPath()]?
      @buffer.on 'contents-modified.git-diff', =>
        @generateDiffs()
        @renderDiffs()

  scheduleDiffs: ->
    _.nextTick =>
      @generateDiffs()
      @renderDiffs()

  generateDiffs: ->
    if path = @buffer.getPath()
      @diffs[path] = git?.getLineDiffs(path, @buffer.getText())

  removeDiffs: ->
    if @gutter.hasGitLineDiffs
      @gutter.find('.line-number').removeClass('git-line-added git-line-modified git-line-removed')
      @gutter.hasGitLineDiffs = false

  renderDiffs: ->
    return unless @gutter.isVisible()

    @removeDiffs()

    hunks = @diffs[@editor.getPath()] ? []
    linesHighlighted = 0
    for hunk in hunks
      if hunk.oldLines is 0 and hunk.newLines > 0
        for row in [hunk.newStart...hunk.newStart + hunk.newLines]
          linesHighlighted += @gutter.find(".line-number[lineNumber=#{row - 1}]").addClass('git-line-added').length
      else if hunk.newLines is 0 and hunk.oldLines > 0
        linesHighlighted += @gutter.find(".line-number[lineNumber=#{hunk.newStart - 1}]").addClass('git-line-removed').length
      else
        for row in [hunk.newStart...hunk.newStart + hunk.newLines]
          linesHighlighted += @gutter.find(".line-number[lineNumber=#{row - 1}]").addClass('git-line-modified').length
    @gutter.hasGitLineDiffs = linesHighlighted > 0
