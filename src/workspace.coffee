{remove} = require 'underscore-plus'
{Model} = require 'theorist'
Serializable = require 'serializable'
PaneContainer = require './pane-container'

module.exports =
class Workspace extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

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

  # Private: Removes the item's uri from the list of potential items to reopen.
  itemOpened: (item) ->
    if uri = item.getUri?()
      remove(@destroyedItemUris, uri)

  # Private: Adds the destroyed item's uri to the list of items to reopen.
  onPaneItemDestroyed: (item) =>
    if uri = item.getUri?()
      @destroyedItemUris.push(uri)
