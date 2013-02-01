DeferredAtomPackage = require 'deferred-atom-package'
Stats = require './src/stats'

module.exports =
class EditorStats extends DeferredAtomPackage
  loadEvents: ['editor-stats:toggle']
  instanceClass: 'editor-stats/src/editor-stats-view'
  stats: new Stats

  activate: (rootView) ->
    super

    rootView.on 'keydown', => @stats.track()
    rootView.on 'mouseup', => @stats.track()

  onLoadEvent: (event, instance) -> instance.toggle(@stats)
