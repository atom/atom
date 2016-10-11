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

    for id of @oldState.blockDecorations
      unless @newState.blockDecorations.hasOwnProperty(id)
        blockDecorationNode = @blockDecorationNodesById[id]
        blockDecorationNode.previousSibling.remove()
        blockDecorationNode.nextSibling.remove()
        blockDecorationNode.remove()
        delete @blockDecorationNodesById[id]
        delete @oldState.blockDecorations[id]

    for id of @newState.blockDecorations
      if @oldState.blockDecorations.hasOwnProperty(id)
        @updateBlockDecorationNode(id)
      else
        @oldState.blockDecorations[id] = {}
        @createAndAppendBlockDecorationNode(id)

  measureBlockDecorations: ->
    for decorationId, blockDecorationNode of @blockDecorationNodesById
      decoration = @newState.blockDecorations[decorationId].decoration
      topRuler = blockDecorationNode.previousSibling
      bottomRuler = blockDecorationNode.nextSibling

      width = blockDecorationNode.offsetWidth
      height = bottomRuler.offsetTop - topRuler.offsetTop
      @presenter.setBlockDecorationDimensions(decoration, width, height)

  createAndAppendBlockDecorationNode: (id) ->
    blockDecorationState = @newState.blockDecorations[id]
    blockDecorationClass = "atom--block-decoration-#{id}"
    topRuler = document.createElement("div")
    blockDecorationNode = @views.getView(blockDecorationState.decoration.getProperties().item)
    bottomRuler = document.createElement("div")
    topRuler.classList.add(blockDecorationClass)
    blockDecorationNode.classList.add(blockDecorationClass)
    bottomRuler.classList.add(blockDecorationClass)

    @container.appendChild(topRuler)
    @container.appendChild(blockDecorationNode)
    @container.appendChild(bottomRuler)

    @blockDecorationNodesById[id] = blockDecorationNode
    @updateBlockDecorationNode(id)

  updateBlockDecorationNode: (id) ->
    newBlockDecorationState = @newState.blockDecorations[id]
    oldBlockDecorationState = @oldState.blockDecorations[id]
    blockDecorationNode = @blockDecorationNodesById[id]

    if newBlockDecorationState.isVisible
      blockDecorationNode.previousSibling.classList.remove("atom--invisible-block-decoration")
      blockDecorationNode.classList.remove("atom--invisible-block-decoration")
      blockDecorationNode.nextSibling.classList.remove("atom--invisible-block-decoration")
    else
      blockDecorationNode.previousSibling.classList.add("atom--invisible-block-decoration")
      blockDecorationNode.classList.add("atom--invisible-block-decoration")
      blockDecorationNode.nextSibling.classList.add("atom--invisible-block-decoration")

    if oldBlockDecorationState.screenRow isnt newBlockDecorationState.screenRow
      blockDecorationNode.dataset.screenRow = newBlockDecorationState.screenRow
      oldBlockDecorationState.screenRow = newBlockDecorationState.screenRow
