cloneObject = (object) ->
  clone = {}
  clone[key] = value for key, value of object
  clone

module.exports =
class TiledComponent
  componentsByTileId: {}

  updateSync: (state) ->
    @newState = state.content
    @oldState ?= @buildEmptyState()

    if @newState.scrollHeight isnt @oldState.scrollHeight
      @domNode.style.height = @newState.scrollHeight + 'px'
      @oldState.scrollHeight = @newState.scrollHeight

    if @newState.backgroundColor isnt @oldState.backgroundColor
      @domNode.style.backgroundColor = @newState.backgroundColor
      @oldState.backgroundColor = @newState.backgroundColor

    if @newState.scrollWidth isnt @oldState.scrollWidth
      @domNode.style.width = @newState.scrollWidth + 'px'
      @oldState.scrollWidth = @newState.scrollWidth

    @removeTileNodes() if @shouldRecreateAllTilesOnUpdate()
    @updateTileNodes()

    @afterUpdateSync(state)

  removeTileNodes: ->
    @removeTileNode(id) for id of @oldState.tiles
    return

  removeTileNode: (id) ->
    node = @componentsByTileId[id].getDomNode()

    node.remove()
    delete @componentsByTileId[id]
    delete @oldState.tiles[id]

  updateTileNodes: ->
    for id of @oldState.tiles
      unless @newState.tiles.hasOwnProperty(id)
        @removeTileNode(id)

    for id, tileState of @newState.tiles
      if @oldState.tiles.hasOwnProperty(id)
        component = @componentsByTileId[id]
      else
        component = @componentsByTileId[id] = @buildComponentForTile(id)

        @domNode.appendChild(component.getDomNode())
        @oldState.tiles[id] = cloneObject(tileState)

      component.updateSync(@newState)

    return
