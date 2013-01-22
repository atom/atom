DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class Tree extends DeferredAtomPackage

  loadEvents: [
    'tree-view:toggle'
    'tree-view:reveal-active-file'
  ]

  instanceClass: 'tree-view/src/tree-view'

  activate: (rootView, state) ->
    super

    if state
      @getInstance().attach() if state.attached
    else if rootView.project.getPath() and not rootView.pathToOpenIsFile
      @getInstance().attach()

  onLoadEvent: (event, instance) ->
    switch event.type
      when 'tree-view:toggle'
        instance.toggle()
      when 'tree-view:reveal-active-file'
        instance.revealActiveFile()
