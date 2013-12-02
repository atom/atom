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
             to: 'paneContainer'

  # Deprecated: Use properties instead
  @delegates 'getPanes', 'getActivePane', 'getPaneItems', 'getActivePaneItem',
             to: 'paneContainer'

  attached: ->
    @manageFocus()
    @paneContainer = new PaneContainer({@focusManager})
    @subscribe @$focused, 'value', (focused) => @activePane.setFocused(true) if focused

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
        @activePane.setActiveItem(editor)
        @activePane.focused = true if changeFocus
        editor
      .catch (error) ->
        console.error(error.stack ? error)

  openSync: (uri, {changeFocus, initialLine, split}={}) ->
    uri = @project.relativize(uri)
    editor = @activePane.itemForUri(uri) if uri?
    editor ?= @project.openSync(uri, {initialLine})
    @activePane.setActiveItem(editor)
    @activePane.focused = true if changeFocus ? true
    editor

  openSingletonSync: (uri, options={}) ->
    if uri? and pane = @paneContainer.paneForUri(@project.relativize(uri))
      @paneContainer.activePane = pane
    @openSync(uri, options)

  everyEditor: (fn) ->
    @editors.onEach(fn)
