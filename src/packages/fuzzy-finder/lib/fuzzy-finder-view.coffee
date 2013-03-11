{View, $$} = require 'space-pen'
SelectList = require 'select-list'
_ = nodeRequire 'underscore'
$ = require 'jquery'
fs = require 'fs'
LoadPathsTask = require './load-paths-task'

module.exports =
class FuzzyFinderView extends SelectList
  filenameRegex: /[\w\.\-\/\\]+/

  @viewClass: ->
    [super, 'fuzzy-finder', 'overlay', 'from-top'].join(' ')

  allowActiveEditorChange: null
  maxItems: 10
  projectPaths: null
  reloadProjectPaths: true

  initialize: ->
    super

    @subscribe $(window), 'focus', => @reloadProjectPaths = true
    @observeConfig 'fuzzy-finder.ignoredNames', => @reloadProjectPaths = true
    rootView.eachPane (pane) ->
      pane.activeItem.lastOpened = (new Date) - 1
      pane.on 'pane:active-item-changed', (e, item) -> item.lastOpened = (new Date) - 1

    @miniEditor.command 'pane:split-left', =>
      @splitOpenPath (pane, session) -> pane.splitLeft(session)
    @miniEditor.command 'pane:split-right', =>
      @splitOpenPath (pane, session) -> pane.splitRight(session)
    @miniEditor.command 'pane:split-down', =>
      @splitOpenPath (pane, session) -> pane.splitDown(session)
    @miniEditor.command 'pane:split-up', =>
      @splitOpenPath (pane, session) -> pane.splitUp(session)

  itemForElement: (path) ->
    $$ ->
      @li =>
        if git?
          status = git.statuses[project.resolve(path)]
          if git.isStatusNew(status)
            @div class: 'status new'
          else if git.isStatusModified(status)
            @div class: 'status modified'

        ext = fs.extension(path)
        if fs.isReadmePath(path)
          typeClass = 'readme-name'
        else if fs.isCompressedExtension(ext)
          typeClass = 'compressed-name'
        else if fs.isImageExtension(ext)
          typeClass = 'image-name'
        else if fs.isPdfExtension(ext)
          typeClass = 'pdf-name'
        else if fs.isBinaryExtension(ext)
          typeClass = 'binary-name'
        else
          typeClass = 'text-name'

        @span fs.base(path), class: "file label #{typeClass}"
        if folder = fs.directory(path)
          @span " - #{folder}/", class: 'directory'

  openPath: (path) ->
    rootView.open(path, {@allowActiveEditorChange}) if path

  splitOpenPath: (fn) ->
    path = @getSelectedElement()
    return unless path
    if pane = rootView.getActivePane()
      fn(pane, project.buildEditSession(path))
    else
      @openPath(path)

  confirmed : (path) ->
    return unless path.length
    if fs.isFile(project.resolve(path))
      @cancel()
      @openPath(path)
    else
      @setError('Selected path does not exist')
      setTimeout((=> @setError()), 2000)

  toggleFileFinder: ->
    if @hasParent()
      @cancel()
    else
      return unless project.getPath()?
      @allowActiveEditorChange = false
      @populateProjectPaths()
      @attach()

  toggleBufferFinder: ->
    if @hasParent()
      @cancel()
    else
      @allowActiveEditorChange = true
      @populateOpenBufferPaths()
      @attach() if @paths?.length

  toggleGitFinder: ->
    if @hasParent()
      @cancel()
    else
      return unless project.getPath()? and git?
      @allowActiveEditorChange = false
      @populateGitStatusPaths()
      @attach()

  findUnderCursor: ->
    if @hasParent()
      @cancel()
    else
      return unless project.getPath()?
      @allowActiveEditorChange = false
      editor = rootView.getActiveView()
      currentWord = editor.getWordUnderCursor(wordRegex: @filenameRegex)

      if currentWord.length == 0
        @attach()
        @setError("The cursor is not over a filename")
      else
        @populateProjectPaths filter: currentWord, done: (paths) =>
          if paths.length == 0
            @attach()
            @setError("No files match '#{currentWord}'")
          else if paths.length == 1
            rootView.open(paths[0])
          else
            @attach()
            @miniEditor.setText(currentWord)

  populateGitStatusPaths: ->
    projectRelativePaths = []
    for path, status of git.statuses
      continue unless fs.isFile(path)
      projectRelativePaths.push(project.relativize(path))
    @setArray(projectRelativePaths)

  populateProjectPaths: (options = {}) ->
    if @projectPaths?.length > 0
      listedItems =
        if options.filter?
          @projectPaths.filter (path) ->
            path.indexOf(options.filter) >= 0
        else
          @projectPaths
      @setArray(listedItems)
      options.done(listedItems) if options.done?
    else
      @setLoading("Indexing...")

    if @reloadProjectPaths
      @loadPathsTask?.abort()
      callback = (paths) =>
        @projectPaths = paths
        @reloadProjectPaths = false
        listedItems =
          if options.filter?
            @projectPaths.filter (path) ->
              path.indexOf(options.filter) >= 0
          else
            @projectPaths

        @setArray(listedItems)
        options.done(listedItems) if options.done?
      @loadPathsTask = new LoadPathsTask(callback)
      @loadPathsTask.start()

  populateOpenBufferPaths: ->
    editSessions = project.getEditSessions().filter (editSession)->
      editSession.getPath()?

    editSessions = _.sortBy editSessions, (editSession) =>
      if editSession is rootView.getActivePaneItem()
        0
      else
        -(editSession.lastOpened or 1)

    @paths = _.map editSessions, (editSession) ->
      project.relativize editSession.getPath()

    @setArray(@paths)

  getOpenedPaths: ->
    paths = {}
    for editSession in project.getEditSessions()
      path = editSession.getPath()
      paths[path] = editSession.lastOpened if path?
    paths

  detach: ->
    super

    @loadPathsTask?.abort()

  attach: ->
    super

    rootView.append(this)
    @miniEditor.focus()
