ipc = require 'ipc'
path = require 'path'
Q = require 'q'
_ = require 'underscore-plus'
Delegator = require 'delegato'
scrollbarStyle = require 'scrollbar-style'
{$, $$, View} = require './space-pen-extensions'
fs = require 'fs-plus'
Workspace = require './workspace'
CommandInstaller = require './command-installer'
EditorView = require './editor-view'
PaneView = require './pane-view'
PaneColumnView = require './pane-column-view'
PaneRowView = require './pane-row-view'
PaneContainerView = require './pane-container-view'
Editor = require './editor'

# Public: The container for the entire Atom application.
#
# An instance of this class is always available as the `atom.workspaceView`
# global.
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
# ## Requiring in package specs
#
# ```coffee
#   {WorkspaceView} = require 'atom'
# ```
module.exports =
class WorkspaceView extends View
  Delegator.includeInto(this)

  @delegatesProperty 'fullScreen', 'destroyedItemUris', toProperty: 'model'
  @delegatesMethods 'open', 'openSync', 'reopenItemSync',
    'saveActivePaneItem', 'saveActivePaneItemAs', 'saveAll', 'destroyActivePaneItem',
    'destroyActivePane', 'increaseFontSize', 'decreaseFontSize', toProperty: 'model'

  @version: 4

  @configDefaults:
    ignoredNames: [".git", ".svn", ".DS_Store"]
    excludeVcsIgnoredPaths: true
    disabledPackages: []
    themes: ['atom-dark-ui', 'atom-dark-syntax']
    projectHome: path.join(fs.getHomeDirectory(), 'github')
    audioBeep: true
    destroyEmptyPanes: true

  @content: ->
    @div class: 'workspace', tabindex: -1, =>
      @div class: 'horizontal', outlet: 'horizontal', =>
        @div class: 'vertical', outlet: 'vertical', =>
          @div class: 'panes', outlet: 'panes'

  initialize: (@model) ->
    @model ?= new Workspace

    panes = new PaneContainerView(@model.paneContainer)
    @panes.replaceWith(panes)
    @panes = panes

    @subscribe @model, 'uri-opened', => @trigger 'uri-opened'

    @subscribe scrollbarStyle.onValue (style) =>
      @removeClass('scrollbar-style-legacy')
      @removeClass('scrollbar-style-overlay')
      @addClass("scrollbar-style-#{style}")

    @updateTitle()

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
    @command 'application:open-your-config', -> ipc.sendChannel('command', 'application:open-your-config')
    @command 'application:open-your-init-script', -> ipc.sendChannel('command', 'application:open-your-init-script')
    @command 'application:open-your-keymap', -> ipc.sendChannel('command', 'application:open-your-keymap')
    @command 'application:open-your-snippets', -> ipc.sendChannel('command', 'application:open-your-snippets')
    @command 'application:open-your-stylesheet', -> ipc.sendChannel('command', 'application:open-your-stylesheet')
    @command 'application:open-license', => @model.openLicense()

    @command 'window:install-shell-commands', => @installShellCommands()

    @command 'window:run-package-specs', => ipc.sendChannel('run-package-specs', path.join(atom.project.getPath(), 'spec'))
    @command 'window:increase-font-size', => @increaseFontSize()
    @command 'window:decrease-font-size', => @decreaseFontSize()
    @command 'window:reset-font-size', => @model.resetFontSize()

    @command 'window:focus-next-pane', => @focusNextPaneView()
    @command 'window:focus-previous-pane', => @focusPreviousPaneView()
    @command 'window:focus-pane-above', => @focusPaneViewAbove()
    @command 'window:focus-pane-below', => @focusPaneViewBelow()
    @command 'window:focus-pane-on-left', => @focusPaneViewOnLeft()
    @command 'window:focus-pane-on-right', => @focusPaneViewOnRight()
    @command 'window:save-all', => @saveAll()
    @command 'window:toggle-invisibles', =>
      atom.config.toggle("editor.showInvisibles")

    @command 'window:toggle-auto-indent', =>
      atom.config.toggle("editor.autoIndent")

    @command 'pane:reopen-closed-item', => @reopenItemSync()

    @command 'core:close', => if @getActivePaneItem()? then @destroyActivePaneItem() else @destroyActivePane()
    @command 'core:save', => @saveActivePaneItem()
    @command 'core:save-as', => @saveActivePaneItemAs()

  installShellCommands: ->
    showErrorDialog = (error) ->
      installDirectory = CommandInstaller.getInstallDirectory()
      atom.confirm
        message: "Failed to install shell commands"
        detailedMessage: error.message

    resourcePath = atom.getLoadSettings().resourcePath
    CommandInstaller.installAtomCommand resourcePath, true, (error) =>
      if error?
        showErrorDialog(error)
      else
        CommandInstaller.installApmCommand resourcePath, true, (error) =>
          if error?
            showErrorDialog(error)
          else
            atom.confirm
              message: "Commands installed."
              detailedMessage: "The shell commands `atom` and `apm` are installed."

  handleFocus: ->
    if @getActivePane()
      @getActivePane().focus()
      false
    else
      @updateTitle()
      focusableChild = @find("[tabindex=-1]:visible:first")
      if focusableChild.length
        focusableChild.focus()
        false
      else
        $(document.body).focus()
        true

  afterAttach: (onDom) ->
    @focus() if onDom

  # Public: Shows a dialog asking if the pane was _really_ meant to be closed.
  confirmClose: ->
    @panes.confirmClose()

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

  # Returns an Array of  all of the application's {EditorView}s.
  getEditorViews: ->
    @panes.find('.pane > .item-views > .editor').map(-> $(this).view()).toArray()

  # Public: Prepends the element to the top of the window.
  prependToTop: (element) ->
    @vertical.prepend(element)

  # Public: Appends the element to the top of the window.
  appendToTop: (element) ->
    @panes.before(element)

  # Public: Prepends the element to the bottom of the window.
  prependToBottom: (element) ->
    @panes.after(element)

  # Public: Appends the element to bottom of the window.
  appendToBottom: (element) ->
    @vertical.append(element)

  # Public: Prepends the element to the left side of the window.
  prependToLeft: (element) ->
    @horizontal.prepend(element)

  # Public: Appends the element to the left side of the window.
  appendToLeft: (element) ->
    @vertical.before(element)

  # Public: Prepends the element to the right side of the window.
  prependToRight: (element) ->
    @vertical.after(element)

  # Public: Appends the element to the right side of the window.
  appendToRight: (element) ->
    @horizontal.append(element)

  # Public: Returns the currently focused {PaneView}.
  getActivePaneView: ->
    @panes.getActivePane()

  # Public: Returns the currently focused item from within the focused {PaneView}
  getActivePaneItem: ->
    @model.activePaneItem

  # Public: Returns the view of the currently focused item.
  getActiveView: ->
    @panes.getActiveView()

  # Public: Focuses the previous pane by id.
  focusPreviousPaneView: -> @model.activatePreviousPane()

  # Public: Focuses the next pane by id.
  focusNextPaneView: -> @model.activateNextPane()

  # Public: Focuses the pane directly above the active pane.
  focusPaneViewAbove: -> @panes.focusPaneViewAbove()

  # Public: Focuses the pane directly below the active pane.
  focusPaneViewBelow: -> @panes.focusPaneViewBelow()

  # Public: Focuses the pane directly to the left of the active pane.
  focusPaneViewOnLeft: -> @panes.focusPaneViewOnLeft()

  # Public: Focuses the pane directly to the right of the active pane.
  focusPaneViewOnRight: -> @panes.focusPaneViewOnRight()

  # Public: Fires a callback on each open {PaneView}.
  eachPaneView: (callback) ->
    @panes.eachPaneView(callback)

  # Returns an Array of all open {PaneView}s.
  getPaneViews: ->
    @panes.getPanes()

  # Public: Fires a callback on each open {EditorView}.
  eachEditorView: (callback) ->
    callback(editor) for editor in @getEditorViews()
    attachedCallback = (e, editor) -> callback(editor)
    @on('editor:attached', attachedCallback)
    off: => @off('editor:attached', attachedCallback)

  # Called by SpacePen
  beforeRemove: ->
    @model.destroy()

  # Deprecated
  eachPane: (callback) ->
    @eachPaneView(callback)

  # Deprecated
  getPanes: ->
    @getPaneViews()

  # Deprecated
  getActivePane: ->
    @getActivePaneView()
