{View, $$} = require 'space-pen'
SelectList = require 'select-list'
_ = require 'underscore'
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
    rootView.eachEditor (editor) ->
      editor.activeEditSession.lastOpened = (new Date) - 1
      editor.on 'editor:active-edit-session-changed', (e, editSession, index) ->
        editSession.lastOpened = (new Date) - 1

    @miniEditor.command 'editor:split-left', =>
      @splitOpenPath (editor, session) -> editor.splitLeft(session)
    @miniEditor.command 'editor:split-right', =>
      @splitOpenPath (editor, session) -> editor.splitRight(session)
    @miniEditor.command 'editor:split-down', =>
      @splitOpenPath (editor, session) -> editor.splitDown(session)
    @miniEditor.command 'editor:split-up', =>
      @splitOpenPath (editor, session) -> editor.splitUp(session)

  itemForElement: (path) ->
    $$ ->
      @li =>
        typeClass = null
        repo = project.repo
        if repo?
          status = project.repo?.statuses[project.resolve(path)]
          if repo.isStatusNew(status)
            typeClass = 'new'
          else if repo.isStatusModified(status)
            typeClass = 'modified'

        unless typeClass
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

    editor = rootView.getActiveEditor()
    if editor
      fn(editor, project.buildEditSessionForPath(path))
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

  findUnderCursor: ->
    if @hasParent()
      @cancel()
    else
      return unless project.getPath()?
      @allowActiveEditorChange = false
      editor = rootView.getActiveEditor()
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
      if editSession is rootView.getActiveEditSession()
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
