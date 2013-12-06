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
  @content: (state) ->
    @div class: 'workspace', tabindex: -1, 'x-bind-focus': "focused", =>
      @div class: 'horizontal', outlet: 'horizontal', =>
        @div class: 'vertical', outlet: 'vertical', =>
          @div 'x-bind-component': "paneContainer"

  @delegates 'open', 'openSync', 'openSingletonSync', 'panes', 'activePane', 'activePaneItem',
             to: 'model'

  # Deprecated: Use properties instead.
  @delegates 'getPanes', 'getActivePane', 'getActivePaneItem', to: 'model'

  # Private:
  created: ->
    @prepend($$ -> @div class: 'dev-mode') if atom.getLoadSettings().devMode

    # @updateTitle()
    atom.project.on 'path-changed', => @updateTitle()
    @on 'pane-container:active-pane-item-changed', => @updateTitle()
    @on 'pane:active-item-title-changed', '.active.pane', => @updateTitle()

    @command 'application:about', => @model.showAboutDialog()
    @command 'application:run-all-specs', => @model.runAllSpecs()
    @command 'application:run-benchmarks', => @model.runAllBenchmarks()
    @command 'application:show-settings', => @model.showSettings()
    @command 'application:quit', => @model.quitApplication()
    @command 'application:hide', => @model.hideApplication()
    @command 'application:hide-other-applications', => @model.hideOtherApplications()
    @command 'application:unhide-all-applications', => @model.unhideAllApplications()
    @command 'application:new-window', => @model.openNewWindow()
    @command 'application:new-file', => @model.openNewFile()
    @command 'application:open', => @model.showOpenDialog()
    @command 'application:open-dev', => @model.showOpenDevDialog()
    @command 'application:minimize', => @model.minimizeWindow()
    @command 'application:zoom', => @model.zoomWindow()
    @command 'application:bring-all-windows-to-front', @model.bringAllWindowsToFront()
    @command 'window:run-package-specs', => @model.runPackageSpecs()
    @command 'window:increase-font-size', => @model.increaseFontSize()
    @command 'window:decrease-font-size', => @model.decreaseFontSize()
    @command 'window:focus-next-pane', => @model.focusNextPane()
    @command 'window:focus-previous-pane', => @model.focusPreviousPane()
    @command 'window:save-all', => @model.saveAll()
    @command 'window:toggle-invisibles', => @model.toggleInvisibles()
    @command 'window:toggle-ignored-files', => @model.toggleHideGitIgnoredFiles()
    @command 'window:toggle-auto-indent', => @model.toggleAutoIndent()
    @command 'pane:reopen-closed-item', => @model.reopenPaneItem()

  # Public: Shows a dialog asking if the pane was _really_ meant to be closed.
  promptToSaveItems: ->
    @model.promptToSaveItems()

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

  # Public: Returns the view of the currently focused item.
  getActiveView: ->
    @viewForModel(@model.activePaneItem)

  # Private: Returns an Array of  all of the application's {EditorView}s.
  getEditorViews: ->
    @model.editors.map (editor) => @viewForModel(editor)

  # Deprecated: Call onEachEditorView instead
  eachEditorView: (callback) ->
    @onEachEditorView(callback)

  # Public: Fires the callback for every current and future editor {EditorView}.
  onEachEditorView: (callback) ->
    @model.activePaneItems.onEach (item) =>
      callback(@viewForModel(item)) if item.constructor.name is 'Editor'
