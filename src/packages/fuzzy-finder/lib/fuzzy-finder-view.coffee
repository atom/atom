{View, $$} = require 'space-pen'
SelectList = require 'select-list'
_ = require 'underscore'
$ = require 'jquery'
humanize = require 'humanize-plus'
fsUtils = require 'fs-utils'
path = require 'path'
LoadPathsTask = require './load-paths-task'
Point = require 'point'

module.exports =
class FuzzyFinderView extends SelectList
  filenameRegex: /[\w\.\-\/\\]+/

  @viewClass: ->
    [super, 'fuzzy-finder', 'overlay', 'from-top'].join(' ')

  allowActiveEditorChange: null
  maxItems: 10
  projectPaths: null
  reloadProjectPaths: true
  filterKey: 'projectRelativePath'

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

  itemForElement: ({filePath, projectRelativePath}) ->
    $$ ->
      @li class: 'two-lines', =>
        if git?
          status = git.statuses[filePath]
          if git.isStatusNew(status)
            @div class: 'status new'
          else if git.isStatusModified(status)
            @div class: 'status modified'

        ext = path.extname(filePath)
        if fsUtils.isReadmePath(filePath)
          typeClass = 'readme-name'
        else if fsUtils.isCompressedExtension(ext)
          typeClass = 'compressed-name'
        else if fsUtils.isImageExtension(ext)
          typeClass = 'image-name'
        else if fsUtils.isPdfExtension(ext)
          typeClass = 'pdf-name'
        else if fsUtils.isBinaryExtension(ext)
          typeClass = 'binary-name'
        else
          typeClass = 'text-name'

        @div path.basename(filePath), class: "primary-line file #{typeClass}"
        @div projectRelativePath, class: 'secondary-line path'

  openPath: (filePath, lineNumber) ->
    return unless filePath

    rootView.open(filePath, {@allowActiveEditorChange})
    @moveToLine(lineNumber)

  moveToLine: (lineNumber=-1) ->
    return unless lineNumber >= 0

    if editor = rootView.getActiveView()
      position = new Point(lineNumber)
      editor.scrollToBufferPosition(position, center: true)
      editor.setCursorBufferPosition(position)
      editor.moveCursorToFirstCharacterOfLine()

  splitOpenPath: (fn) ->
    {filePath} = @getSelectedElement()
    return unless filePath

    lineNumber = @getLineNumber()
    if pane = rootView.getActivePane()
      fn(pane, project.open(filePath))
      @moveToLine(lineNumber)
    else
      @openPath(filePath, lineNumber)

  confirmed : ({filePath}) ->
    return unless filePath

    if fsUtils.isFileSync(filePath)
      lineNumber = @getLineNumber()
      @cancel()
      @openPath(filePath, lineNumber)
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

  getFilterQuery: ->
    query = super
    colon = query.indexOf(':')
    if colon is -1
      query
    else
      query[0...colon]

  getLineNumber: ->
    query = @miniEditor.getText()
    colon = query.indexOf(':')
    if colon is -1
      -1
    else
      parseInt(query[colon+1..]) - 1

  setArray: (paths) ->
    projectRelativePaths = paths.map (filePath) ->
      projectRelativePath = project.relativize(filePath)
      {filePath, projectRelativePath}

    super(projectRelativePaths)

  populateGitStatusPaths: ->
    paths = []
    paths.push(filePath) for filePath, status of git.statuses when fsUtils.isFileSync(filePath)

    @setArray(paths)

  populateProjectPaths: (options = {}) ->
    if @projectPaths?
      listedItems =
        if options.filter?
          @projectPaths.filter (filePath) ->
            filePath.indexOf(options.filter) >= 0
        else
          @projectPaths
      @setArray(listedItems)
      options.done(listedItems) if options.done?
    else
      @setLoading("Indexing project...")
      @loadingBadge.text("")

    if @reloadProjectPaths
      @loadPathsTask?.abort()
      callback = (paths) =>
        @projectPaths = paths
        @reloadProjectPaths = false
        @populateProjectPaths(options)
      @loadPathsTask = new LoadPathsTask(callback)
      @loadPathsTask.on 'paths-loaded', (paths) =>
        @loadingBadge.text(humanize.intcomma(paths.length))
      @loadPathsTask.start()

  populateOpenBufferPaths: ->
    editSessions = project.getEditSessions().filter (editSession) ->
      editSession.getPath()?

    editSessions = _.sortBy editSessions, (editSession) =>
      if editSession is rootView.getActivePaneItem()
        0
      else
        -(editSession.lastOpened or 1)

    @paths = []
    @paths.push(editSession.getPath()) for editSession in editSessions

    @setArray(_.uniq(@paths))

  detach: ->
    super

    @loadPathsTask?.abort()

  attach: ->
    super

    rootView.append(this)
    @miniEditor.focus()
