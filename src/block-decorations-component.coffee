cloneObject = (object) ->
  clone = {}
  clone[key] = value for key, value of object
  clone

module.exports =
class BlockDecorationsComponent
  constructor: (@container, @views, @presenter, @domElementPool) ->
    @newState = null
    @oldState = null
    @blockDecorationNodesById = {}

  updateSync: (state) ->
    @newState = state.content
    @oldState ?= {blockDecorations: {}}

    for id, blockDecorationState of @oldState.blockDecorations
      unless @newState.blockDecorations.hasOwnProperty(id)
        @blockDecorationNodesById[id].remove()
        delete @blockDecorationNodesById[id]
        delete @oldState.blockDecorations[id]

    for id, blockDecorationState of @newState.blockDecorations
      if @oldState.blockDecorations.hasOwnProperty(id)
        @updateBlockDecorationNode(id)
      else
        @createAndAppendBlockDecorationNode(id)

      @oldState.blockDecorations[id] = cloneObject(blockDecorationState)

  measureBlockDecorations: ->
    for decorationId, blockDecorationNode of @blockDecorationNodesById
      decoration = @newState.blockDecorations[decorationId].decoration
      @presenter.setBlockDecorationDimensions(
        decoration,
        blockDecorationNode.offsetWidth,
        blockDecorationNode.offsetHeight
      )

  createAndAppendBlockDecorationNode: (id) ->
    blockDecorationState = @newState.blockDecorations[id]
    blockDecorationNode = @views.getView(blockDecorationState.decoration.getProperties().item)
    blockDecorationNode.classList.add("block-decoration-row-#{blockDecorationState.screenRow}")

    @container.appendChild(blockDecorationNode)

    @blockDecorationNodesById[id] = blockDecorationNode

  updateBlockDecorationNode: (id) ->
    newBlockDecorationState = @newState.blockDecorations[id]
    oldBlockDecorationState = @oldState.blockDecorations[id]
    blockDecorationNode = @blockDecorationNodesById[id]

    if newBlockDecorationState.screenRow isnt oldBlockDecorationState.screenRow
      blockDecorationNode.classList.remove("block-decoration-row-#{oldBlockDecorationState.screenRow}")
      blockDecorationNode.classList.add("block-decoration-row-#{newBlockDecorationState.screenRow}")
