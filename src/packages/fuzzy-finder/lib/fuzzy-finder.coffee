_ = nodeRequire 'underscore'

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
    rootView.command 'fuzzy-finder:toggle-git-status-finder', =>
      @createView().toggleGitFinder()

    if project.getPath()?
      LoadPathsTask = require 'fuzzy-finder/lib/load-paths-task'
      @loadPathsTask = new LoadPathsTask((paths) => @projectPaths = paths)
      @loadPathsTask.start()

    for editSession in project.getEditSessions()
      editSession.lastOpened = state[editSession.getPath()]

  deactivate: ->
    @loadPathsTask?.abort()
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
