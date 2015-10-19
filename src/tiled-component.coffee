{values} = require 'underscore-plus'

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
    @removeTileNode(tileRow) for tileRow of @oldState.tiles
    return

  removeTileNode: (tileRow) ->
    @componentsByTileId[tileRow].destroy()
    delete @componentsByTileId[tileRow]
    delete @oldState.tiles[tileRow]

  updateTileNodes: ->
    @componentsByTileId ?= {}

    for tileRow of @oldState.tiles
      unless @newState.tiles.hasOwnProperty(tileRow)
        @removeTileNode(tileRow)

    for tileRow, tileState of @newState.tiles
      if @oldState.tiles.hasOwnProperty(tileRow)
        component = @componentsByTileId[tileRow]
      else
        component = @componentsByTileId[tileRow] = @buildComponentForTile(tileRow)

        @getTilesNode().appendChild(component.getDomNode())
        @oldState.tiles[tileRow] = cloneObject(tileState)

      component.updateSync(@newState)

    return

  getComponentForTile: (tileRow) ->
    @componentsByTileId[tileRow]

  getTiles: ->
    values(@componentsByTileId).map (component) -> component.getDomNode()
