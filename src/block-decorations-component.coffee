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
    @domNode = @domElementPool.buildElement("content")
    @domNode.setAttribute("select", ".atom--invisible-block-decoration")
    @domNode.style.visibility = "hidden"
    @domNode.style.position = "absolute"

  getDomNode: ->
    @domNode

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
    unless blockDecorationState.isVisible
      blockDecorationNode.classList.add("atom--invisible-block-decoration")

    @container.appendChild(blockDecorationNode)

    @blockDecorationNodesById[id] = blockDecorationNode

  updateBlockDecorationNode: (id) ->
    newBlockDecorationState = @newState.blockDecorations[id]
    oldBlockDecorationState = @oldState.blockDecorations[id]
    blockDecorationNode = @blockDecorationNodesById[id]

    if newBlockDecorationState.isVisible and not oldBlockDecorationState.isVisible
      blockDecorationNode.classList.remove("atom--invisible-block-decoration")
    else if not newBlockDecorationState.isVisible and oldBlockDecorationState.isVisible
      blockDecorationNode.classList.add("atom--invisible-block-decoration")

    if newBlockDecorationState.screenRow isnt oldBlockDecorationState.screenRow
      blockDecorationNode.classList.remove("block-decoration-row-#{oldBlockDecorationState.screenRow}")
      blockDecorationNode.classList.add("block-decoration-row-#{newBlockDecorationState.screenRow}")
