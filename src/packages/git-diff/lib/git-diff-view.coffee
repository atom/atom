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
    @gutter.find('.line-number').removeClass('git-line-added git-line-modified git-line-removed')

  renderDiffs: ->
    return unless @gutter.isVisible()

    @removeDiffs()

    hunks = @diffs[@editor.getPath()] ? []
    for hunk in hunks
      if hunk.oldLines is 0 and hunk.newLines > 0
        for row in [hunk.newStart...hunk.newStart + hunk.newLines]
          @gutter.find(".line-number[lineNumber=#{row - 1}]").addClass('git-line-added')
      else if hunk.newLines is 0 and hunk.oldLines > 0
        @gutter.find(".line-number[lineNumber=#{hunk.newStart - 1}]").addClass('git-line-removed')
      else
        for row in [hunk.newStart...hunk.newStart + hunk.newLines]
          @gutter.find(".line-number[lineNumber=#{row - 1}]").addClass('git-line-modified')
