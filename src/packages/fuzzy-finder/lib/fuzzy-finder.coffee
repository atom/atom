module.exports =
  projectPaths: null
  fuzzyFinderView: null

  activate: ->
    rootView.command 'fuzzy-finder:toggle-file-finder', =>
      @createView().toggleFileFinder()
    rootView.command 'fuzzy-finder:toggle-buffer-finder', =>
      @createView().toggleBufferFinder()
    rootView.command 'fuzzy-finder:find-under-cursor', =>
      @createView().findUnderCursor()

    if rootView.project.getPath()?
      callback = (paths) => @projectPaths = paths
      LoadPathsTask = require 'fuzzy-finder/lib/load-paths-task'
      new LoadPathsTask(rootView, callback).start()

  deactivate: ->
    @projectPaths = null
    @fuzzyFinderView = null

  createView:  ->
    unless @fuzzyFinderView
      FuzzyFinderView  = require 'fuzzy-finder/lib/fuzzy-finder-view'
      @fuzzyFinderView = new FuzzyFinderView()
      if @projectPaths? and not @fuzzyFinderView.projectPaths?
        @fuzzyFinderView.projectPaths = @projectPaths
        @fuzzyFinderView.reloadProjectPaths = false
    @fuzzyFinderView
