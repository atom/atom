_ = require 'underscore-plus'

HighlightsComponent = require './highlights-component'
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
TokenTextEscapeRegex = /[&"'<>]/g
MaxTokenLength = 20000
ZERO_WIDTH_NBSP = '\ufeff'

cloneObject = (object) ->
  clone = {}
  clone[key] = value for key, value of object
  clone

module.exports =
class LinesTileComponent
  constructor: ({@presenter, @id, @domElementPool, @assert}) ->
    @measuredLines = new Set
    @lineNodesByLineId = {}
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}
    @textNodesByLineId = {}
    @insertionPointsBeforeLineById = {}
    @insertionPointsAfterLineById = {}
    @domNode = @domElementPool.buildElement("div")
    @domNode.style.position = "absolute"
    @domNode.style.display = "block"

    @highlightsComponent = new HighlightsComponent(@domElementPool)
    @domNode.appendChild(@highlightsComponent.getDomNode())

  destroy: ->
    @domElementPool.freeElementAndDescendants(@domNode)

  getDomNode: ->
    @domNode

  updateSync: (state) ->
    @newState = state
    unless @oldState
      @oldState = {tiles: {}}
      @oldState.tiles[@id] = {lines: {}}

    @newTileState = @newState.tiles[@id]
    @oldTileState = @oldState.tiles[@id]

    if @newState.backgroundColor isnt @oldState.backgroundColor
      @domNode.style.backgroundColor = @newState.backgroundColor
      @oldState.backgroundColor = @newState.backgroundColor

    if @newTileState.zIndex isnt @oldTileState.zIndex
      @domNode.style.zIndex = @newTileState.zIndex
      @oldTileState.zIndex = @newTileState.zIndex

    if @newTileState.display isnt @oldTileState.display
      @domNode.style.display = @newTileState.display
      @oldTileState.display = @newTileState.display

    if @newTileState.height isnt @oldTileState.height
      @domNode.style.height = @newTileState.height + 'px'
      @oldTileState.height = @newTileState.height

    if @newState.width isnt @oldState.width
      @domNode.style.width = @newState.width + 'px'
      @oldTileState.width = @newTileState.width

    if @newTileState.top isnt @oldTileState.top or @newTileState.left isnt @oldTileState.left
      @domNode.style['-webkit-transform'] = "translate3d(#{@newTileState.left}px, #{@newTileState.top}px, 0px)"
      @oldTileState.top = @newTileState.top
      @oldTileState.left = @newTileState.left

    @updateLineNodes()

    @highlightsComponent.updateSync(@newTileState)

  removeLineNodes: ->
    @removeLineNode(id) for id of @oldTileState.lines
    return

  removeLineNode: (id) ->
    @domElementPool.freeElementAndDescendants(@lineNodesByLineId[id])
    @removeBlockDecorationInsertionPointBeforeLine(id)
    @removeBlockDecorationInsertionPointAfterLine(id)

    delete @lineNodesByLineId[id]
    delete @textNodesByLineId[id]
    delete @lineIdsByScreenRow[@screenRowsByLineId[id]]
    delete @screenRowsByLineId[id]
    delete @oldTileState.lines[id]

  updateLineNodes: ->
    for id of @oldTileState.lines
      unless @newTileState.lines.hasOwnProperty(id)
        @removeLineNode(id)

    newLineIds = null
    newLineNodes = null

    for id, lineState of @newTileState.lines
      if @oldTileState.lines.hasOwnProperty(id)
        @updateLineNode(id)
      else
        newLineIds ?= []
        newLineNodes ?= []
        newLineIds.push(id)
        newLineNodes.push(@buildLineNode(id))
        @screenRowsByLineId[id] = lineState.screenRow
        @lineIdsByScreenRow[lineState.screenRow] = id
        @oldTileState.lines[id] = cloneObject(lineState)

    return unless newLineIds?

    for id, i in newLineIds
      lineNode = newLineNodes[i]
      @lineNodesByLineId[id] = lineNode
      if nextNode = @findNodeNextTo(lineNode)
        @domNode.insertBefore(lineNode, nextNode)
      else
        @domNode.appendChild(lineNode)

      @insertBlockDecorationInsertionPointBeforeLine(id)
      @insertBlockDecorationInsertionPointAfterLine(id)

  removeBlockDecorationInsertionPointBeforeLine: (id) ->
    if insertionPoint = @insertionPointsBeforeLineById[id]
      @domElementPool.freeElementAndDescendants(insertionPoint)
      delete @insertionPointsBeforeLineById[id]

  insertBlockDecorationInsertionPointBeforeLine: (id) ->
    {hasPrecedingBlockDecorations, screenRow} = @newTileState.lines[id]

    if hasPrecedingBlockDecorations
      lineNode = @lineNodesByLineId[id]
      insertionPoint = @domElementPool.buildElement("content")
      @domNode.insertBefore(insertionPoint, lineNode)
      @insertionPointsBeforeLineById[id] = insertionPoint
      insertionPoint.dataset.screenRow = screenRow
      @updateBlockDecorationInsertionPointBeforeLine(id)

  updateBlockDecorationInsertionPointBeforeLine: (id) ->
    oldLineState = @oldTileState.lines[id]
    newLineState = @newTileState.lines[id]
    insertionPoint = @insertionPointsBeforeLineById[id]
    return unless insertionPoint?

    if newLineState.screenRow isnt oldLineState.screenRow
      insertionPoint.dataset.screenRow = newLineState.screenRow

    precedingBlockDecorationsSelector = newLineState.precedingBlockDecorations.map((d) -> ".atom--block-decoration-#{d.id}").join(',')

    if precedingBlockDecorationsSelector isnt oldLineState.precedingBlockDecorationsSelector
      insertionPoint.setAttribute("select", precedingBlockDecorationsSelector)
      oldLineState.precedingBlockDecorationsSelector = precedingBlockDecorationsSelector

  removeBlockDecorationInsertionPointAfterLine: (id) ->
    if insertionPoint = @insertionPointsAfterLineById[id]
      @domElementPool.freeElementAndDescendants(insertionPoint)
      delete @insertionPointsAfterLineById[id]

  insertBlockDecorationInsertionPointAfterLine: (id) ->
    {hasFollowingBlockDecorations, screenRow} = @newTileState.lines[id]

    if hasFollowingBlockDecorations
      lineNode = @lineNodesByLineId[id]
      insertionPoint = @domElementPool.buildElement("content")
      @domNode.insertBefore(insertionPoint, lineNode.nextSibling)
      @insertionPointsAfterLineById[id] = insertionPoint
      insertionPoint.dataset.screenRow = screenRow
      @updateBlockDecorationInsertionPointAfterLine(id)

  updateBlockDecorationInsertionPointAfterLine: (id) ->
    oldLineState = @oldTileState.lines[id]
    newLineState = @newTileState.lines[id]
    insertionPoint = @insertionPointsAfterLineById[id]
    return unless insertionPoint?

    if newLineState.screenRow isnt oldLineState.screenRow
      insertionPoint.dataset.screenRow = newLineState.screenRow

    followingBlockDecorationsSelector = newLineState.followingBlockDecorations.map((d) -> ".atom--block-decoration-#{d.id}").join(',')

    if followingBlockDecorationsSelector isnt oldLineState.followingBlockDecorationsSelector
      insertionPoint.setAttribute("select", followingBlockDecorationsSelector)
      oldLineState.followingBlockDecorationsSelector = followingBlockDecorationsSelector

  findNodeNextTo: (node) ->
    for nextNode, index in @domNode.children
      continue if index is 0 # skips highlights node
      return nextNode if @screenRowForNode(node) < @screenRowForNode(nextNode)
    return

  screenRowForNode: (node) -> parseInt(node.dataset.screenRow)

  buildLineNode: (id) ->
    {lineText, tagCodes, screenRow, decorationClasses} = @newTileState.lines[id]

    lineNode = @domElementPool.buildElement("div", "line")
    lineNode.dataset.screenRow = screenRow

    if decorationClasses?
      for decorationClass in decorationClasses
        lineNode.classList.add(decorationClass)

    textNodes = []
    lineLength = 0
    startIndex = 0
    openScopeNode = lineNode
    for tagCode in tagCodes when tagCode isnt 0
      if @presenter.isCloseTagCode(tagCode)
        openScopeNode = openScopeNode.parentElement
      else if @presenter.isOpenTagCode(tagCode)
        scope = @presenter.tagForCode(tagCode)
        newScopeNode = @domElementPool.buildElement("span", scope.replace(/\.+/g, ' '))
        openScopeNode.appendChild(newScopeNode)
        openScopeNode = newScopeNode
      else
        textNode = @domElementPool.buildText(lineText.substr(startIndex, tagCode))
        startIndex += tagCode
        openScopeNode.appendChild(textNode)
        textNodes.push(textNode)

    if startIndex is 0
      textNode = @domElementPool.buildText(' ')
      lineNode.appendChild(textNode)
      textNodes.push(textNode)

    if lineText.endsWith(@presenter.displayLayer.foldCharacter)
      # Insert a zero-width non-breaking whitespace, so that
      # LinesYardstick can take the fold-marker::after pseudo-element
      # into account during measurements when such marker is the last
      # character on the line.
      textNode = @domElementPool.buildText(ZERO_WIDTH_NBSP)
      lineNode.appendChild(textNode)
      textNodes.push(textNode)

    @textNodesByLineId[id] = textNodes
    lineNode

  updateLineNode: (id) ->
    oldLineState = @oldTileState.lines[id]
    newLineState = @newTileState.lines[id]

    lineNode = @lineNodesByLineId[id]

    newDecorationClasses = newLineState.decorationClasses
    oldDecorationClasses = oldLineState.decorationClasses

    if oldDecorationClasses?
      for decorationClass in oldDecorationClasses
        unless newDecorationClasses? and decorationClass in newDecorationClasses
          lineNode.classList.remove(decorationClass)

    if newDecorationClasses?
      for decorationClass in newDecorationClasses
        unless oldDecorationClasses? and decorationClass in oldDecorationClasses
          lineNode.classList.add(decorationClass)

    oldLineState.decorationClasses = newLineState.decorationClasses

    if not oldLineState.hasPrecedingBlockDecorations and newLineState.hasPrecedingBlockDecorations
      @insertBlockDecorationInsertionPointBeforeLine(id)
    else if oldLineState.hasPrecedingBlockDecorations and not newLineState.hasPrecedingBlockDecorations
      @removeBlockDecorationInsertionPointBeforeLine(id)

    if not oldLineState.hasFollowingBlockDecorations and newLineState.hasFollowingBlockDecorations
      @insertBlockDecorationInsertionPointAfterLine(id)
    else if oldLineState.hasFollowingBlockDecorations and not newLineState.hasFollowingBlockDecorations
      @removeBlockDecorationInsertionPointAfterLine(id)

    if newLineState.screenRow isnt oldLineState.screenRow
      lineNode.dataset.screenRow = newLineState.screenRow
      @lineIdsByScreenRow[newLineState.screenRow] = id
      @screenRowsByLineId[id] = newLineState.screenRow

    @updateBlockDecorationInsertionPointBeforeLine(id)
    @updateBlockDecorationInsertionPointAfterLine(id)

    oldLineState.screenRow = newLineState.screenRow
    oldLineState.hasPrecedingBlockDecorations = newLineState.hasPrecedingBlockDecorations
    oldLineState.hasFollowingBlockDecorations = newLineState.hasFollowingBlockDecorations

  lineNodeForScreenRow: (screenRow) ->
    @lineNodesByLineId[@lineIdsByScreenRow[screenRow]]

  lineNodeForLineId: (lineId) ->
    @lineNodesByLineId[lineId]

  textNodesForLineId: (lineId) ->
    @textNodesByLineId[lineId].slice()

  lineIdForScreenRow: (screenRow) ->
    @lineIdsByScreenRow[screenRow]

  textNodesForScreenRow: (screenRow) ->
    @textNodesByLineId[@lineIdsByScreenRow[screenRow]]?.slice()
