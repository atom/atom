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
      LoadPathsTask = require 'fuzzy-finder/lib/load-paths-task'
      @loadPathsTask = new LoadPathsTask((paths) => @projectPaths = paths)
      @loadPathsTask.start()

  deactivate: ->
    @loadPathsTask?.terminate()
    @fuzzyFinderView?.cancel()
    @fuzzyFinderView = null
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
