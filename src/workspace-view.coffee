ipc = require 'ipc'
path = require 'path'
Q = require 'q'
_ = require 'underscore-plus'
Delegator = require 'delegato'
{deprecate, logDeprecationWarnings} = require 'grim'
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

# Public: The top-level view for the entire window. An instance of this class is
# available via the `atom.workspaceView` global.
#
# It is backed by a model object, an instance of {Workspace}, which is available
# via the `atom.workspace` global or {::getModel}. You should prefer to interact
# with the model object when possible, but it won't always be possible with the
# current API.
#
# ## Adding Perimiter Panels
#
# Use the following methods if possible to attach panels to the perimiter of the
# workspace rather than manipulating the DOM directly to better insulate you to
# changes in the workspace markup:
#
# * {::prependToTop}
# * {::appendToTop}
# * {::prependToBottom}
# * {::appendToBottom}
# * {::prependToLeft}
# * {::appendToLeft}
# * {::prependToRight}
# * {::appendToRight}
#
# ## Requiring in package specs
#
# If you need a `WorkspaceView` instance to test your package, require it via
# the built-in `atom` module.
#
# ```coffee
#   {WorkspaceView} = require 'atom'
# ```
#
# You can assign it to the `atom.workspaceView` global in the spec or just use
# it as a local, depending on what you're trying to accomplish. Building the
# `WorkspaceView` is currently expensive, so you should try build a {Workspace}
# instead if possible.
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
    useReactEditor: false

  @content: ->
    @div class: 'workspace', tabindex: -1, =>
      @div class: 'horizontal', outlet: 'horizontal', =>
        @div class: 'vertical', outlet: 'vertical', =>
          @div class: 'panes', outlet: 'panes'

  initialize: (@model) ->
    @model = atom.workspace ? new Workspace unless @model?

    panes = new PaneContainerView(@model.paneContainer)
    @panes.replaceWith(panes)
    @panes = panes

    @subscribe @model, 'uri-opened', => @trigger 'uri-opened'

    @subscribe scrollbarStyle, (style) =>
      @removeClass('scrollbars-visible-always scrollbars-visible-when-scrolling')
      switch style
        when 'legacy'
          @addClass("scrollbars-visible-always")
        when 'overlay'
          @addClass("scrollbars-visible-when-scrolling")

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
    @command 'application:open-file', -> ipc.sendChannel('command', 'application:open-file')
    @command 'application:open-folder', -> ipc.sendChannel('command', 'application:open-folder')
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
    @command 'window:toggle-invisibles', -> atom.config.toggle("editor.showInvisibles")
    @command 'window:log-deprecation-warnings', -> logDeprecationWarnings()

    @command 'window:toggle-auto-indent', =>
      atom.config.toggle("editor.autoIndent")

    @command 'pane:reopen-closed-item', => @reopenItemSync()

    @command 'core:close', => if @getModel().getActivePaneItem()? then @destroyActivePaneItem() else @destroyActivePane()
    @command 'core:save', => @saveActivePaneItem()
    @command 'core:save-as', => @saveActivePaneItemAs()

  # Public: Get the underlying model object.
  #
  # Returns a {Workspace}.
  getModel: -> @model

  # Public: Install the Atom shell commands on the user's system.
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
    if @getActivePaneView()
      @getActivePaneView().focus()
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

  # Prompts to save all unsaved items
  confirmClose: ->
    @panes.confirmClose()

  # Updates the application's title, based on whichever file is open.
  updateTitle: ->
    if projectPath = atom.project.getPath()
      if item = @getModel().getActivePaneItem()
        @setTitle("#{item.getTitle?() ? 'untitled'} - #{projectPath}")
      else
        @setTitle(projectPath)
    else
      @setTitle('untitled')

  # Sets the application's title.
  setTitle: (title) ->
    document.title = title

  # Get all editor views.
  #
  # You should prefer {Workspace::getEditors} unless you absolutely need access
  # to the view objects. Also consider using {::eachEditorView}, which will call
  # a callback for all current and *future* editor views.
  #
  # Returns an {Array} of {EditorView}s.
  getEditorViews: ->
    @panes.find('.pane > .item-views > .editor').map(-> $(this).view()).toArray()

  # Public: Prepend an element or view to the panels at the top of the
  # workspace.
  prependToTop: (element) ->
    @vertical.prepend(element)

  # Public: Append an element or view to the panels at the top of the workspace.
  appendToTop: (element) ->
    @panes.before(element)

  # Public: Prepend an element or view to the panels at the bottom of the
  # workspace.
  prependToBottom: (element) ->
    @panes.after(element)

  # Public: Append an element or view to the panels at the bottom of the
  # workspace.
  appendToBottom: (element) ->
    @vertical.append(element)

  # Public: Prepend an element or view to the panels at the left of the
  # workspace.
  prependToLeft: (element) ->
    @horizontal.prepend(element)

  # Public: Append an element or view to the panels at the left of the
  # workspace.
  appendToLeft: (element) ->
    @vertical.before(element)

  # Public: Prepend an element or view to the panels at the right of the
  # workspace.
  prependToRight: (element) ->
    @vertical.after(element)

  # Public: Append an element or view to the panels at the right of the
  # workspace.
  appendToRight: (element) ->
    @horizontal.append(element)

  # Public: Get the active pane view.
  #
  # Prefer {Workspace::getActivePane} if you don't actually need access to the
  # view.
  #
  # Returns a {PaneView}.
  getActivePaneView: ->
    @panes.getActivePaneView()

  # Public: Get the view associated with the active pane item.
  #
  # Returns a view.
  getActiveView: ->
    @panes.getActiveView()

  # Focus the previous pane by id.
  focusPreviousPaneView: -> @model.activatePreviousPane()

  # Focus the next pane by id.
  focusNextPaneView: -> @model.activateNextPane()

  # Public: Focus the pane directly above the active pane.
  focusPaneViewAbove: -> @panes.focusPaneViewAbove()

  # Public: Focus the pane directly below the active pane.
  focusPaneViewBelow: -> @panes.focusPaneViewBelow()

  # Public: Focus the pane directly to the left of the active pane.
  focusPaneViewOnLeft: -> @panes.focusPaneViewOnLeft()

  # Public: Focus the pane directly to the right of the active pane.
  focusPaneViewOnRight: -> @panes.focusPaneViewOnRight()

  # Public: Register a function to be called for every current and future
  # pane view in the workspace.
  #
  # callback - A {Function} with a {PaneView} as its only argument.
  #
  # Returns a subscription object with an `.off` method that you can call to
  # unregister the callback.
  eachPaneView: (callback) ->
    @panes.eachPaneView(callback)

  # Public: Get all existing pane views.
  #
  # Prefer {Workspace::getPanes} if you don't need access to the view objects.
  # Also consider using {::eachPaneView} if you want to register a callback for
  # all current and *future* pane views.
  #
  # Returns an Array of all open {PaneView}s.
  getPaneViews: ->
    @panes.getPaneViews()

  # Public: Register a function to be called for every current and future
  # editor view in the workspace.
  #
  # callback - A {Function} with an {EditorView} as its only argument.
  #
  # Returns a subscription object with an `.off` method that you can call to
  # unregister the callback.
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
    deprecate("Use WorkspaceView::eachPaneView instead")
    @eachPaneView(callback)

  # Deprecated
  getPanes: ->
    deprecate("Use WorkspaceView::getPaneViews instead")
    @getPaneViews()

  # Deprecated
  getActivePane: ->
    deprecate("Use WorkspaceView::getActivePaneView instead")
    @getActivePaneView()

  # Deprecated: Call {Workspace::getActivePaneItem} instead.
  getActivePaneItem: ->
    deprecate("Use Workspace::getActivePaneItem instead")
    @model.activePaneItem
