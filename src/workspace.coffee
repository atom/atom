{remove, last} = require 'underscore-plus'
{Model} = require 'theorist'
Q = require 'q'
Serializable = require 'serializable'
Delegator = require 'delegato'
PaneContainer = require './pane-container'
Pane = require './pane'

# Public: Represents the view state of the entire window, including the panes at
# the center and panels around the periphery. You can access the singleton
# instance via `atom.workspace`.
module.exports =
class Workspace extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @delegatesProperty 'activePane', 'activePaneItem', toProperty: 'paneContainer'
  @delegatesMethod 'getPanes', 'saveAll', 'activateNextPane', 'activatePreviousPane',
    toProperty: 'paneContainer'

  @properties
    paneContainer: -> new PaneContainer
    fullScreen: false
    destroyedItemUris: -> []

  # Private:
  constructor: ->
    super
    @subscribe @paneContainer, 'item-destroyed', @onPaneItemDestroyed

  # Private: Called by the Serializable mixin during deserialization
  deserializeParams: (params) ->
    params.paneContainer = PaneContainer.deserialize(params.paneContainer)
    params

  # Private: Called by the Serializable mixin during serialization.
  serializeParams: ->
    paneContainer: @paneContainer.serialize()
    fullScreen: atom.isFullScreen()

  # Private: Open ~/.atom/user.less or ~/.atom/user.css
  openUserStylesheet: ->
    @open(atom.themes.getUserStylesheetPath())

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

  # Private: Only used in specs
  openSync: (uri, {changeFocus, initialLine, pane, split}={}) ->
    changeFocus ?= true
    pane ?= @activePane
    uri = atom.project.relativize(uri)

    if pane
      if uri
        paneItem = pane.itemForUri(uri) ? atom.project.openSync(uri, {initialLine})
      else
        paneItem = atom.project.openSync()

      if split == 'right'
        panes = @getPanes()
        if panes.length == 1
          pane = panes[0].splitRight()
        else
          pane = last(panes)
      else if split == 'left'
        pane = @getPanes()[0]

      pane.activateItem(paneItem)
    else
      paneItem = atom.project.openSync(uri, {initialLine})
      pane = new Pane(items: [paneItem])
      @paneContainer.root = pane

    @itemOpened(paneItem)

    pane.activate() if changeFocus
    paneItem

  # Public: Synchronously open an editor for the given URI or activate an existing
  # editor in any pane if one already exists.
  openSingletonSync: (uri, {changeFocus, initialLine, split}={}) ->
    changeFocus ?= true
    uri = atom.project.relativize(uri)
    pane = @paneContainer.paneForUri(uri)

    if pane
      paneItem = pane.itemForUri(uri)
      pane.activateItem(paneItem)
      pane.activate() if changeFocus
      paneItem
    else
      @openSync(uri, {changeFocus, initialLine, split})

  # Public: Reopens the last-closed item uri if it hasn't already been reopened.
  reopenItemSync: ->
    if uri = @destroyedItemUris.pop()
      @openSync(uri)

  # Public: save the active item.
  saveActivePaneItem: ->
    @activePane?.saveActiveItem()

  # Public: save the active item as.
  saveActivePaneItemAs: ->
    @activePane?.saveActiveItemAs()

  # Public: destroy/close the active item.
  destroyActivePaneItem: ->
    @activePane?.destroyActiveItem()

  # Public: destroy/close the active pane.
  destroyActivePane: ->
    @activePane?.destroy()

  # Private: Removes the item's uri from the list of potential items to reopen.
  itemOpened: (item) ->
    if uri = item.getUri?()
      remove(@destroyedItemUris, uri)

  # Private: Adds the destroyed item's uri to the list of items to reopen.
  onPaneItemDestroyed: (item) =>
    if uri = item.getUri?()
      @destroyedItemUris.push(uri)

  # Private: Called by Model superclass when destroyed
  destroyed: ->
    @paneContainer.destroy()
