DeferredAtomPackage = require 'deferred-atom-package'

module.exports =
class FuzzyFinder extends DeferredAtomPackage
  loadEvents: [
    'fuzzy-finder:toggle-file-finder'
    'fuzzy-finder:toggle-buffer-finder'
    'fuzzy-finder:find-under-cursor'
  ]

  instanceClass: 'fuzzy-finder/src/fuzzy-finder-view'

  activate: (rootView) ->
    super

    if rootView.project.getPath()?
      callback = (paths) => @projectPaths = paths
      LoadPathsTask = require 'fuzzy-finder/src/load-paths-task'
      new LoadPathsTask(rootView, callback).start()

  onLoadEvent: (event, instance) ->
    if @projectPaths? and not instance.projectPaths?
      instance.projectPaths = @projectPaths
      instance.reloadProjectPaths = false

    switch event.type
      when 'fuzzy-finder:toggle-file-finder'
        instance.toggleFileFinder()
      when 'fuzzy-finder:toggle-buffer-finder'
        instance.toggleBufferFinder()
      when 'fuzzy-finder:find-under-cursor'
        instance.findUnderCursor()
