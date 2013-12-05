ipc = require 'ipc'
{Model} = require 'telepath'
Q = require 'q'

PaneContainer = require './pane-container'
Focusable = require './focusable'

module.exports =
class Workspace extends Model
  Focusable.includeInto(this)

  @properties
    project: null
    paneContainer: null

  @relatesToMany 'editors', ->
    @paneItems.where (item) -> item.constructor.name is 'Editor'

  @behavior 'hasFocus', ->
    @$focused.or(@$focusedPane.isDefined())

  @delegates 'activePane', 'activePaneItem', 'panes', 'paneItems', 'activePaneItems',
             'focusedPane', '$focusedPane', 'focusNextPane', 'focusPreviousPane',
             'promptToSaveItems', to: 'paneContainer'

  # Deprecated: Use properties instead
  @delegates 'getPanes', 'getActivePane', 'getPaneItems', 'getActivePaneItem',
             to: 'paneContainer'

  created: ->
    @paneContainer = new PaneContainer({@focusManager})
    @manageFocus()

  forwardFocus: ->
    @activePane.focus()

  # Public: Asynchronously opens a given a filepath in Atom.
  #
  # * filePath: A file path
  # * options
  #   + initialLine: The buffer line number to open to.
  #
  # Returns a promise that resolves to the {Editor} for the file URI.
  open: (filePath, options={}) ->
    changeFocus = options.changeFocus ? true
    initialLine = options.initialLine

    editor = @activePane.itemForUri(@project.relativize(filePath)) if filePath?
    promise = @project.open(filePath, {initialLine}) unless editor?

    Q(editor ? promise)
      .then (editor) =>
        @activePane.activateItem(editor)
        @activePane.focus() if changeFocus
        editor
      .catch (error) ->
        console.error(error.stack ? error)

  openSync: (uri, {changeFocus, initialLine, split}={}) ->
    uri = @project.relativize(uri)
    editor = @activePane.itemForUri(uri) if uri?
    editor ?= @project.openSync(uri, {initialLine})
    @activePane.activateItem(editor)
    @activePane.focus() if changeFocus ? true
    editor

  openSingletonSync: (uri, options={}) ->
    if uri? and pane = @paneContainer.paneForUri(@project.relativize(uri))
      @paneContainer.activePane = pane
    @openSync(uri, options)

  onEachEditor: (fn) ->
    @editors.onEach(fn)

  showAboutDialog: ->
    ipc.sendChannel('command', 'application:about')

  runAllSpecs: ->
    ipc.sendChannel('command', 'application:run-all-specs')

  runBenchmarks: ->
    ipc.sendChannel('command', 'application:run-benchmarks')

  showSettings: ->
    ipc.sendChannel('command', 'application:show-settings')

  quitApplication: ->
    ipc.sendChannel('command', 'application:quit')

  hideApplication: ->
    ipc.sendChannel('command', 'application:hide')

  hideOtherApplications: ->
    ipc.sendChannel('command', 'application:hide-other-applications')

  unhideAllApplications: ->
    ipc.sendChannel('command', 'application:unhide-all-applications')

  openNewWindow: ->
    ipc.sendChannel('command', 'application:new-window')

  openNewFile: ->
    ipc.sendChannel('command', 'application:new-file')

  showOpenDialog: ->
    ipc.sendChannel('command', 'application:open')

  showOpenDevDialog: ->
    ipc.sendChannel('command', 'application:open-dev')

  minimizeWindow: ->
    ipc.sendChannel('command', 'application:minimize')

  zoomWindow: ->
    ipc.sendChannel('command', 'application:zoom')

  bringAllWindowsToFront: ->
    ipc.sendChannel('command', 'application:bring-all-windows-to-front')

  increaseFontSize: ->
    atom.config.set("editor.fontSize", atom.config.get("editor.fontSize") + 1)

  decreaseFontSize: ->
    fontSize = atom.config.get("editor.fontSize")
    atom.config.set("editor.fontSize", fontSize - 1) if fontSize > 1

  toggleInvisibles: ->
    atom.config.toggle("editor.showInvisibles")

  toggleHideGitIgnoredFiles: ->
    atom.config.toggle("core.hideGitIgnoredFiles")

  toggleAutoIndent: ->
    atom.config.toggle("editor.autoIndent")
