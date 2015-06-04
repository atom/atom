cloneObject = (object) ->
  clone = {}
  clone[key] = value for key, value of object
  clone

module.exports =
class TiledComponent
  updateSync: (state) ->
    @newState = @getNewState(state)
    @oldState ?= @buildEmptyState()

    @beforeUpdateSync?(state)

    @removeTileNodes() if @shouldRecreateAllTilesOnUpdate?()
    @updateTileNodes()

    @afterUpdateSync?(state)

  removeTileNodes: ->
    @removeTileNode(id) for id of @oldState.tiles
    return

  removeTileNode: (id) ->
    node = @componentsByTileId[id].getDomNode()

    node.remove()
    delete @componentsByTileId[id]
    delete @oldState.tiles[id]

  updateTileNodes: ->
    @componentsByTileId ?= {}

    for id of @oldState.tiles
      unless @newState.tiles.hasOwnProperty(id)
        @removeTileNode(id)

    for id, tileState of @newState.tiles
      if @oldState.tiles.hasOwnProperty(id)
        component = @componentsByTileId[id]
      else
        component = @componentsByTileId[id] = @buildComponentForTile(id)

        @getTilesNode().appendChild(component.getDomNode())
        @oldState.tiles[id] = cloneObject(tileState)

      component.updateSync(@newState)

    return
