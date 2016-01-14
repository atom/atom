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

  getDomNode: ->
    @domNode

  updateSync: (state) ->
    @newState = state.content
    @oldState ?= {blockDecorations: {}, width: 0}

    if @newState.width isnt @oldState.width
      @domNode.style.width = @newState.width + "px"
      @oldState.width = @newState.width

    for id, blockDecorationState of @oldState.blockDecorations
      unless @newState.blockDecorations.hasOwnProperty(id)
        @blockDecorationNodesById[id].remove()
        delete @blockDecorationNodesById[id]
        delete @oldState.blockDecorations[id]

    for id, blockDecorationState of @newState.blockDecorations
      if @oldState.blockDecorations.hasOwnProperty(id)
        @updateBlockDecorationNode(id)
      else
        @oldState.blockDecorations[id] = {}
        @createAndAppendBlockDecorationNode(id)

  measureBlockDecorations: ->
    for decorationId, blockDecorationNode of @blockDecorationNodesById
      style = getComputedStyle(blockDecorationNode)
      decoration = @newState.blockDecorations[decorationId].decoration
      marginBottom = parseInt(style.marginBottom) ? 0
      marginTop = parseInt(style.marginTop) ? 0
      @presenter.setBlockDecorationDimensions(
        decoration,
        blockDecorationNode.offsetWidth,
        blockDecorationNode.offsetHeight + marginTop + marginBottom
      )

  createAndAppendBlockDecorationNode: (id) ->
    blockDecorationState = @newState.blockDecorations[id]
    blockDecorationNode = @views.getView(blockDecorationState.decoration.getProperties().item)
    blockDecorationNode.id = "atom--block-decoration-#{id}"
    @container.appendChild(blockDecorationNode)
    @blockDecorationNodesById[id] = blockDecorationNode
    @updateBlockDecorationNode(id)

  updateBlockDecorationNode: (id) ->
    newBlockDecorationState = @newState.blockDecorations[id]
    oldBlockDecorationState = @oldState.blockDecorations[id]
    blockDecorationNode = @blockDecorationNodesById[id]

    if newBlockDecorationState.isVisible
      blockDecorationNode.classList.remove("atom--invisible-block-decoration")
    else
      blockDecorationNode.classList.add("atom--invisible-block-decoration")

    if oldBlockDecorationState.screenRow isnt newBlockDecorationState.screenRow
      blockDecorationNode.dataset.screenRow = newBlockDecorationState.screenRow
      oldBlockDecorationState.screenRow = newBlockDecorationState.screenRow
