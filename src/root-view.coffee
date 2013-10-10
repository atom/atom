{fs} = require 'atom'
ipc = require 'ipc'
path = require 'path'
Q = require 'q'
$ = require './jquery-extensions'
{$$, View} = require './space-pen-extensions'
fsUtils = require './fs-utils'
_ = require './underscore-extensions'
telepath = require 'telepath'
Editor = require './editor'
Pane = require './pane'
PaneColumn = require './pane-column'
PaneRow = require './pane-row'
PaneContainer = require './pane-container'
EditSession = require './edit-session'

# Public: The container for the entire Atom application.
#
# ## Commands
#
#  * `application:about` - Opens the about dialog.
#  * `application:show-settings` - Opens the preference pane in the currently
#    focused editor.
#  * `application:quit` - Quits the entire application.
#  * `application:hide` - Hides the entire application.
#  * `application:hide-other-applications` - Hides other applications
#    running on the system.
#  * `application:unhide-other-applications` - Shows other applications
#    that were previously hidden.
#  * `application:new-window` - Opens a new {AtomWindow} with no {Project}
#    path.
#  * `application:new-file` - Creates a new file within the focused window.
#    Note: only one new file may exist within an {AtomWindow} at a time.
#  * `application:open` - Prompts the user for a path to open in a new {AtomWindow}
#  * `application:minimize` - Minimizes the currently focused {AtomWindow}
#  * `application:zoom` - Expands the window to fill the screen or returns it to
#    it's original unzoomed size.
#  * `application:bring-all-windows-to-front` - Brings all {AtomWindow}s to the
#    the front.
#
module.exports =
class RootView extends View
  registerDeserializers(this, Pane, PaneRow, PaneColumn, Editor)

  @version: 1

  @configDefaults:
    autosave: false
    ignoredNames: [".git", ".svn", ".DS_Store"]
    excludeVcsIgnoredPaths: true
    disabledPackages: []
    themes: ['atom-dark-ui', 'atom-dark-syntax']
    projectHome: path.join(atom.getHomeDirPath(), 'github')

  @acceptsDocuments: true

  # Private:
  @content: (state) ->
    @div id: 'root-view', =>
      @div id: 'horizontal', outlet: 'horizontal', =>
        @div id: 'vertical', outlet: 'vertical', =>
          @div outlet: 'panes'

  # Private:
  @deserialize: (state) ->
    new RootView(state)

  # Private:
  initialize: (state={}) ->
    @prepend($$ -> @div class: 'dev-mode') if atom.getLoadSettings().devMode

    if state instanceof telepath.Document
      @state = state
      panes = deserialize(state.get('panes'))
    else
      panes = new PaneContainer
      @state = site.createDocument
        deserializer: @constructor.name
        version: @constructor.version
        panes: panes.getState()

    @panes.replaceWith(panes)
    @panes = panes
    @updateTitle()

    @on 'focus', (e) => @handleFocus(e)
    @subscribe $(window), 'focus', (e) =>
      @handleFocus(e) if document.activeElement is document.body

    project.on 'path-changed', => @updateTitle()
    @on 'pane-container:active-pane-item-changed', => @updateTitle()
    @on 'pane:active-item-title-changed', '.active.pane', => @updateTitle()

    @command 'application:about', -> ipc.sendChannel('command', 'application:about')
    @command 'application:run-all-specs', -> ipc.sendChannel('command', 'application:run-all-specs')
    @command 'application:run-benchmarks', -> ipc.sendChannel('command', 'application:run-benchmarks')
    @command 'application:show-settings', -> ipc.sendChannel('command', 'application:show-settings')
    @command 'application:quit', -> ipc.sendChannel('command', 'application:quit')
    @command 'application:hide', -> ipc.sendChannel('command', 'application:hide')
    @command 'application:hide-other-applications', -> ipc.sendChannel('command', 'application:hide-other-applications')
    @command 'application:unhide-all-applications', -> ipc.sendChannel('command', 'application:unhide-all-applications')
    @command 'application:new-window', -> ipc.sendChannel('command', 'application:new-window')
    @command 'application:new-file', -> ipc.sendChannel('command', 'application:new-file')
    @command 'application:open', -> ipc.sendChannel('command', 'application:open')
    @command 'application:open-dev', -> ipc.sendChannel('command', 'application:open-dev')
    @command 'application:minimize', -> ipc.sendChannel('command', 'application:minimize')
    @command 'application:zoom', -> ipc.sendChannel('command', 'application:zoom')
    @command 'application:bring-all-windows-to-front', -> ipc.sendChannel('command', 'application:bring-all-windows-to-front')

    @command 'window:run-package-specs', => ipc.sendChannel('run-package-specs', path.join(project.getPath(), 'spec'))
    @command 'window:increase-font-size', =>
      config.set("editor.fontSize", config.get("editor.fontSize") + 1)

    @command 'window:decrease-font-size', =>
      fontSize = config.get "editor.fontSize"
      config.set("editor.fontSize", fontSize - 1) if fontSize > 1

    @command 'window:focus-next-pane', => @focusNextPane()
    @command 'window:focus-previous-pane', => @focusPreviousPane()
    @command 'window:save-all', => @saveAll()
    @command 'window:toggle-invisibles', =>
      config.set("editor.showInvisibles", !config.get("editor.showInvisibles"))
    @command 'window:toggle-ignored-files', =>
      config.set("core.hideGitIgnoredFiles", not config.core.hideGitIgnoredFiles)

    @command 'window:toggle-auto-indent', =>
      config.set("editor.autoIndent", !config.get("editor.autoIndent"))

    @command 'pane:reopen-closed-item', =>
      @panes.reopenItem()

    if @state.get('fullScreen')
      _.nextTick => atom.setFullScreen(true)

  # Private:
  serialize: ->
    state = @state.clone()
    state.set('panes', @panes.serialize())
    state.set('fullScreen', atom.isFullScreen())
    state

  # Private:
  getState: -> @state

  # Private:
  handleFocus: (e) ->
    if @getActivePane()
      @getActivePane().focus()
      false
    else
      @updateTitle()
      focusableChild = this.find("[tabindex=-1]:visible:first")
      if focusableChild.length
        focusableChild.focus()
        false
      else
        true

  # Private:
  afterAttach: (onDom) ->
    @focus() if onDom

  # Public: Shows a dialog asking if the pane was _really_ meant to be closed.
  confirmClose: ->
    @panes.confirmClose()

  # Public: Asynchronously opens a given a filepath in Atom.
  #
  # * filePath: A file path
  # * options
  #   + initialLine: The buffer line number to open to.
  #
  # Returns a promise that resolves to the {EditSession} for the file URI.
  openAsync: (filePath, options={}) ->
    absoluteFilePath = filePath
    filePath = project.relativize(filePath)
    initialLine = options.initialLine
    activePane = @getActivePane()

    editSession = activePane.itemForUri(filePath) if activePane and filePath
    promise = project.openAsync(filePath, {initialLine}) if not editSession

    fileSize = 0
    fileSize = fs.statSync(absoluteFilePath).size if fs.exists(absoluteFilePath)

    Q(editSession ? promise)
      .then (editSession) =>
        if not activePane
          activePane = new Pane(editSession)
          @panes.setRoot(activePane)

        activePane.showItem(editSession)
        activePane.focus()
      .progress (value) =>
        console.log "#{filepath} read #{100 * (value / fileSize)}"

  # Private: DEPRECATED Synchronously Opens a given a filepath in Atom.
  open: (filePath, options = {}) ->
    console.warn("RootView::open is deprecated")
    changeFocus = options.changeFocus ? true
    initialLine = options.initialLine
    filePath = project.relativize(filePath)
    if activePane = @getActivePane()
      if filePath
        editSession = activePane.itemForUri(filePath) ? project.open(filePath, {initialLine})
      else
        editSession = project.open()
      activePane.showItem(editSession)
    else
      editSession = project.open(filePath, {initialLine})
      activePane = new Pane(editSession)
      @panes.setRoot(activePane)

    activePane.focus() if changeFocus
    editSession

  # Public: Updates the application's title, based on whichever file is open.
  updateTitle: ->
    if projectPath = project.getPath()
      if item = @getActivePaneItem()
        @setTitle("#{item.getTitle?() ? 'untitled'} - #{projectPath}")
      else
        @setTitle(projectPath)
    else
      @setTitle('untitled')

  # Public: Sets the application's title.
  setTitle: (title) ->
    document.title = title

  # Private: Returns an Array of  all of the application's {Editor}s.
  getEditors: ->
    @panes.find('.pane > .item-views > .editor').map(-> $(this).view()).toArray()

  # Private: Retrieves all of the modified buffers that are open and unsaved.
  #
  # Returns an {Array} of {TextBuffer}s.
  getModifiedBuffers: ->
    modifiedBuffers = []
    for pane in @getPanes()
      for item in pane.getItems() when item instanceof EditSession
        modifiedBuffers.push item.buffer if item.buffer.isModified()
    modifiedBuffers

  # Private: Retrieves all of the paths to open files.
  #
  # Returns an {Array} of {String}s.
  getOpenBufferPaths: ->
    _.uniq(_.flatten(@getEditors().map (editor) -> editor.getOpenBufferPaths()))

  # Public: Returns the currently focused {Pane}.
  getActivePane: ->
    @panes.getActivePane()

  # Public: Returns the currently focused item from within the focused {Pane}
  getActivePaneItem: ->
    @panes.getActivePaneItem()

  # Public: Returns the view of the currently focused item.
  getActiveView: ->
    @panes.getActiveView()

  # Public: Focuses the previous pane by id.
  focusPreviousPane: -> @panes.focusPreviousPane()

  # Public: Focuses the next pane by id.
  focusNextPane: -> @panes.focusNextPane()

  # Public:
  #
  # FIXME: Difference between active and focused pane?
  getFocusedPane: -> @panes.getFocusedPane()

  # Public: Saves all of the open items within panes.
  saveAll: ->
    @panes.saveAll()

  # Public: Fires a callback on each open {Pane}.
  eachPane: (callback) ->
    @panes.eachPane(callback)

  # Public: Returns an Array of all open {Pane}s.
  getPanes: ->
    @panes.getPanes()

  # Public: Return the id of the given a {Pane}
  indexOfPane: (pane) ->
    @panes.indexOfPane(pane)

  # Private: Fires a callback on each open {Editor}.
  eachEditor: (callback) ->
    callback(editor) for editor in @getEditors()
    attachedCallback = (e, editor) -> callback(editor)
    @on('editor:attached', attachedCallback)
    off: => @off('editor:attached', attachedCallback)

  # Public: Fires a callback on each open {EditSession}.
  eachEditSession: (callback) ->
    project.eachEditSession(callback)

  # Private: Fires a callback on each open {TextBuffer}.
  eachBuffer: (callback) ->
    project.eachBuffer(callback)

  # Private: Destroys everything.
  remove: ->
    editor.remove() for editor in @getEditors()
    project?.destroy()
    super
