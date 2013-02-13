_ = require 'underscore'

module.exports =
  projectPaths: null
  fuzzyFinderView: null
  loadPathsTask: null

  activate: (state) ->
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

    for path, lastOpened of state
      session = _.detect rootView.project.getEditSessions(), (editSession) ->
        editSession.getPath() is path
      session?.lastOpened = lastOpened

  deactivate: ->
    @loadPathsTask?.terminate()
    @loadPathsTask = null
    @fuzzyFinderView?.cancel()
    @fuzzyFinderView = null
    @projectPaths = null

  serialize: ->
    @fuzzyFinderView?.getOpenedPaths()

  createView:  ->
    unless @fuzzyFinderView
      FuzzyFinderView  = require 'fuzzy-finder/lib/fuzzy-finder-view'
      @fuzzyFinderView = new FuzzyFinderView()
      if @projectPaths? and not @fuzzyFinderView.projectPaths?
        @fuzzyFinderView.projectPaths = @projectPaths
        @fuzzyFinderView.reloadProjectPaths = false
    @fuzzyFinderView
