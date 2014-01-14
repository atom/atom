{remove} = require 'underscore-plus'
{Model} = require 'theorist'
Q = require 'q'
Serializable = require 'serializable'
Delegator = require 'delegato'
PaneContainer = require './pane-container'
Pane = require './pane'

module.exports =
class Workspace extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @delegatesProperty 'activePane', toProperty: 'paneContainer'

  @properties
    paneContainer: -> new PaneContainer
    fullScreen: false
    destroyedItemUris: -> []

  constructor: ->
    super
    @subscribe @paneContainer, 'item-destroyed', @onPaneItemDestroyed

  deserializeParams: (params) ->
    params.paneContainer = PaneContainer.deserialize(params.paneContainer)
    params

  serializeParams: ->
    paneContainer: @paneContainer.serialize()
    fullScreen: atom.isFullScreen()

  # Public: Asynchronously opens a given a filepath in Atom.
  #
  # * filePath: A file path
  # * options
  #   + initialLine: The buffer line number to open to.
  #
  # Returns a promise that resolves to the {Editor} for the file URI.
  open: (filePath, options={}) ->
    changeFocus = options.changeFocus ? true
    filePath = atom.project.resolve(filePath)
    initialLine = options.initialLine
    activePane = @activePane

    editor = activePane.itemForUri(atom.project.relativize(filePath)) if activePane and filePath
    promise = atom.project.open(filePath, {initialLine}) if not editor

    Q(editor ? promise)
      .then (editor) =>
        if not activePane
          activePane = new Pane(items: [editor])
          @paneContainer.root = activePane

        @itemOpened(editor)
        activePane.activateItem(editor)
        activePane.activate() if changeFocus
        @emit "uri-opened"
        editor
      .catch (error) ->
        console.error(error.stack ? error)

  # Private: Removes the item's uri from the list of potential items to reopen.
  itemOpened: (item) ->
    if uri = item.getUri?()
      remove(@destroyedItemUris, uri)

  # Private: Adds the destroyed item's uri to the list of items to reopen.
  onPaneItemDestroyed: (item) =>
    if uri = item.getUri?()
      @destroyedItemUris.push(uri)
