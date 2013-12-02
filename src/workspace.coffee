{Model} = require 'telepath'
Q = require 'q'

PaneContainer = require './pane-container'

module.exports =
class Workspace extends Model
  @properties
    project: null
    paneContainer: -> new PaneContainer

  @relatesToMany 'editors', ->
    @paneItems.where (item) -> item.constructor.name is 'Editor'

  @delegates 'activePane', 'getActivePane', 'activePaneItem', 'getActivePaneItem',
            'getPanes', 'panes', 'paneItems', 'getPaneItems', to: 'paneContainer'

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

  everyEditor: (fn) ->
    @editors.onEach(fn)
