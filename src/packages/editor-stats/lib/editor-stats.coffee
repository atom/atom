StatsTracker = require './stats-tracker'

module.exports =
  stats: null
  editorStatsView: null

  activate: ->
    @stats = new StatsTracker()
    rootView.command 'editor-stats:toggle', => @createView().toggle(@stats)

  deactivate: ->
    @editorStatsView = null
    @stats = null

  createView: ->
    unless @editorStatsView
      EditorStatsView  = require 'editor-stats/lib/editor-stats-view'
      @editorStatsView = new EditorStatsView()
    @editorStatsView
