{setDimensionsAndBackground} = require './gutter-component-helpers'

# This class represents a gutter other than the 'line-numbers' gutter.
# The contents of this gutter may be specified by Decorations.

module.exports =
class CustomGutterComponent

  constructor: ({@gutter, @views}) ->
    @decorationNodesById = {}
    @decorationItemsById = {}
    @visible = true

    @domNode = @views.getView(@gutter)
    @decorationsNode = @domNode.firstChild
    # Clear the contents in case the domNode is being reused.
    @decorationsNode.innerHTML = ''

  getDomNode: ->
    @domNode

  hideNode: ->
    if @visible
      @domNode.style.display = 'none'
      @visible = false

  showNode: ->
    if not @visible
      @domNode.style.removeProperty('display')
      @visible = true

  # `state` is a subset of the TextEditorPresenter state that is specific
  # to this line number gutter.
  updateSync: (state) ->
    @oldDimensionsAndBackgroundState ?= {}
    setDimensionsAndBackground(@oldDimensionsAndBackgroundState, state.styles, @decorationsNode)

    @oldDecorationPositionState ?= {}
    decorationState = state.content

    updatedDecorationIds = new Set
    for decorationId, decorationInfo of decorationState
      updatedDecorationIds.add(decorationId)
      existingDecoration = @decorationNodesById[decorationId]
      if existingDecoration
        @updateDecorationNode(existingDecoration, decorationId, decorationInfo)
      else
        newNode = @buildDecorationNode(decorationId, decorationInfo)
        @decorationNodesById[decorationId] = newNode
        @decorationsNode.appendChild(newNode)

    for decorationId, decorationNode of @decorationNodesById
      if not updatedDecorationIds.has(decorationId)
        decorationNode.remove()
        delete @decorationNodesById[decorationId]
        delete @decorationItemsById[decorationId]
        delete @oldDecorationPositionState[decorationId]

  ###
  Section: Private Methods
  ###

  # Builds and returns an HTMLElement to represent the specified decoration.
  buildDecorationNode: (decorationId, decorationInfo) ->
    @oldDecorationPositionState[decorationId] = {}
    newNode = document.createElement('div')
    newNode.style.position = 'absolute'
    @updateDecorationNode(newNode, decorationId, decorationInfo)
    newNode

  # Updates the existing HTMLNode with the new decoration info. Attempts to
  # minimize changes to the DOM.
  updateDecorationNode: (node, decorationId, newDecorationInfo) ->
    oldPositionState = @oldDecorationPositionState[decorationId]

    if oldPositionState.top isnt newDecorationInfo.top + 'px'
      node.style.top = newDecorationInfo.top + 'px'
      oldPositionState.top = newDecorationInfo.top + 'px'

    if oldPositionState.height isnt newDecorationInfo.height + 'px'
      node.style.height = newDecorationInfo.height + 'px'
      oldPositionState.height = newDecorationInfo.height + 'px'

    if newDecorationInfo.class and not node.classList.contains(newDecorationInfo.class)
      node.className = 'decoration'
      node.classList.add(newDecorationInfo.class)
    else if not newDecorationInfo.class
      node.className = 'decoration'

    @setDecorationItem(newDecorationInfo.item, newDecorationInfo.height, decorationId, node)

  # Sets the decorationItem on the decorationNode.
  # If `decorationItem` is undefined, the decorationNode's child item will be cleared.
  setDecorationItem: (newItem, decorationHeight, decorationId, decorationNode) ->
    if newItem isnt @decorationItemsById[decorationId]
      while decorationNode.firstChild
        decorationNode.removeChild(decorationNode.firstChild)
      delete @decorationItemsById[decorationId]

      if newItem
        newItemNode = null
        if newItem instanceof HTMLElement
          newItemNode = newItem
        else
          newItemNode = newItem.element

        newItemNode.style.height = decorationHeight + 'px'
        decorationNode.appendChild(newItemNode)
        @decorationItemsById[decorationId] = newItem
