ipc = require 'ipc'
path = require 'path'
Q = require 'q'
{$, $$, View} = require './space-pen-extensions'
Delegator = require 'delegato'
_ = require 'underscore-plus'
fs = require 'fs-plus'
telepath = require 'telepath'
EditorView = require './editor-view'
Pane = require './pane'
Editor = require './editor'
PaneContainerView = require './pane-container-view'
EditorView = require './editor-view'

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
class WorkspaceView extends View
  Delegator.includeInto(this)

  @register PaneContainerView
  @register EditorView

  @configDefaults:
    ignoredNames: [".git", ".svn", ".DS_Store"]
    excludeVcsIgnoredPaths: true
    disabledPackages: []
    themes: ['atom-dark-ui', 'atom-dark-syntax']
    projectHome: path.join(fs.getHomeDirectory(), 'github')
    audioBeep: true

  # Private:
  @content: ->
    @div id: 'workspace', tabindex: -1, =>
      @div id: 'horizontal', outlet: 'horizontal', =>
        @div id: 'vertical', outlet: 'vertical', =>
          @div 'x-bind-component': "paneContainer"

  @delegates 'open', 'openSync', 'openSingletonSync', 'getActivePane', 'getActivePaneItem',
             to: 'model'

  # Private:
  created: ->
    @prepend($$ -> @div class: 'dev-mode') if atom.getLoadSettings().devMode

    # @updateTitle()

    @on 'focus', (e) => @handleFocus(e)
    @subscribe $(window), 'focus', (e) =>
      @handleFocus(e) if document.activeElement is document.body

    atom.project.on 'path-changed', => @updateTitle()
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

    @command 'window:run-package-specs', => ipc.sendChannel('run-package-specs', path.join(atom.project.getPath(), 'spec'))
    @command 'window:increase-font-size', =>
      atom.config.set("editor.fontSize", atom.config.get("editor.fontSize") + 1)

    @command 'window:decrease-font-size', =>
      fontSize = atom.config.get "editor.fontSize"
      atom.config.set("editor.fontSize", fontSize - 1) if fontSize > 1

    @command 'window:focus-next-pane', => @focusNextPane()
    @command 'window:focus-previous-pane', => @focusPreviousPane()
    @command 'window:save-all', => @saveAll()
    @command 'window:toggle-invisibles', =>
      atom.config.toggle("editor.showInvisibles")
    @command 'window:toggle-ignored-files', =>
      atom.config.toggle("core.hideGitIgnoredFiles")

    @command 'window:toggle-auto-indent', =>
      atom.config.toggle("editor.autoIndent")

    @command 'pane:reopen-closed-item', =>
      @model.reopenItem()

  # Private:
  handleFocus: (e) ->
    return
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
        $(document.body).focus()
        true

  # Private:
  afterAttach: (onDom) ->
    @focus() if onDom

  # Public: Shows a dialog asking if the pane was _really_ meant to be closed.
  confirmClose: ->
    @model.confirmClose()

  # Public: Updates the application's title, based on whichever file is open.
  updateTitle: ->
    if projectPath = atom.project.getPath()
      if item = @getActivePaneItem()
        @setTitle("#{item.getTitle?() ? 'untitled'} - #{projectPath}")
      else
        @setTitle(projectPath)
    else
      @setTitle('untitled')

  # Public: Sets the application's title.
  setTitle: (title) ->
    document.title = title

  # Private: Returns an Array of  all of the application's {EditorView}s.
  getEditorViews: ->
    @model.editors.map (editor) => @viewForModel(editor)

  # Private: Retrieves all of the modified buffers that are open and unsaved.
  #
  # Returns an {Array} of {TextBuffer}s.
  getModifiedBuffers: ->
    modifiedBuffers = []
    for pane in @getPanes()
      for item in pane.getItems() when item instanceof Editor
        modifiedBuffers.push item.buffer if item.buffer.isModified()
    modifiedBuffers

  # Private: Retrieves all of the paths to open files.
  #
  # Returns an {Array} of {String}s.
  getOpenBufferPaths: ->
    _.uniq(_.flatten(@getEditorViews().map (editorView) -> editorView.getOpenBufferPaths()))

  # Public: Returns the view of the currently focused item.
  getActiveView: ->
    @viewForModel(@model.activePaneItem)

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

  # Deprecated: Call everyEditorView instead
  eachEditorView: (callback) ->
    @everyEditorView(callback)

  # Public: Fires the callback for every current and future editor {EditorView}.
  everyEditorView: (callback) ->
    @model.everyEditor (editor) => callback(@viewForModel(editor))

  # # Private: Destroys everything.
  # remove: ->
  #   editorView.remove() for editorView in @getEditorViews()
  #   atom.project?.destroy()
  #   super
