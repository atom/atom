cloneObject = (object) ->
  clone = {}
  clone[key] = value for key, value of object
  clone

module.exports =
class BlockDecorationsComponent
  constructor: (@views, @domElementPool) ->
    @domNode = @domElementPool.buildElement("div")
    @newState = null
    @oldState = null
    @blockDecorationNodesById = {}

  getDomNode: ->
    @domNode

  updateSync: (state) ->
    @newState = state.content
    @oldState ?= {blockDecorations: {}}

    for id, blockDecorationState of @newState.blockDecorations
      if @oldState.blockDecorations.hasOwnProperty(id)
        @updateBlockDecorationNode(id)
      else
        @createAndAppendBlockDecorationNode(id)

      @oldState.blockDecorations[id] = cloneObject(blockDecorationState)

  createAndAppendBlockDecorationNode: (id) ->
    blockDecorationState = @newState.blockDecorations[id]
    blockDecorationNode = @views.getView(blockDecorationState.decoration.getProperties().item)
    blockDecorationNode.classList.add("block-decoration-row-#{blockDecorationState.screenRow}")

    @domNode.appendChild(blockDecorationNode)

    @blockDecorationNodesById[id] = blockDecorationNode

  updateBlockDecorationNode: (id) ->
    newBlockDecorationState = @newState.blockDecorations[id]
    oldBlockDecorationState = @oldState.blockDecorations[id]
    blockDecorationNode = @blockDecorationNodesById[id]

    if newBlockDecorationState.screenRow isnt oldBlockDecorationState.screenRow
      blockDecorationNode.classList.remove("block-decoration-row-#{oldBlockDecorationState.screenRow}")
      blockDecorationNode.classList.add("block-decoration-row-#{newBlockDecorationState.screenRow}")
