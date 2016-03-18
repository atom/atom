_ = require 'underscore-plus'

HighlightsComponent = require './highlights-component'
TokenIterator = require './token-iterator'
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
TokenTextEscapeRegex = /[&"'<>]/g
NBSPCharacter = '\u00a0'
MaxTokenLength = 20000

cloneObject = (object) ->
  clone = {}
  clone[key] = value for key, value of object
  clone

module.exports =
class LinesTileComponent
  constructor: ({@presenter, @id, @domElementPool, @assert, grammars}) ->
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

    @removeLineNodes() unless @oldState.indentGuidesVisible is @newState.indentGuidesVisible
    @updateLineNodes()

    @highlightsComponent.updateSync(@newTileState)

    @oldState.indentGuidesVisible = @newState.indentGuidesVisible

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

    precedingBlockDecorationsSelector = newLineState.precedingBlockDecorations.map((d) -> "#atom--block-decoration-#{d.id}").join(',')

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

    followingBlockDecorationsSelector = newLineState.followingBlockDecorations.map((d) -> "#atom--block-decoration-#{d.id}").join(',')

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
    {screenRow, decorationClasses} = @newTileState.lines[id]

    lineNode = @domElementPool.buildElement("div", "line")
    lineNode.dataset.screenRow = screenRow

    if decorationClasses?
      for decorationClass in decorationClasses
        lineNode.classList.add(decorationClass)

    @currentLineTextNodes = []
    # if words.length is 0
    #   @setEmptyLineInnerNodes(id, lineNode)

    @setLineInnerNodes(id, lineNode)
    @textNodesByLineId[id] = @currentLineTextNodes

    # lineNode.appendChild(@domElementPool.buildElement("span", "fold-marker")) if fold
    lineNode

  setEmptyLineInnerNodes: (id, lineNode) ->
    {indentGuidesVisible} = @newState
    {indentLevel, tabLength, endOfLineInvisibles} = @newTileState.lines[id]

    if indentGuidesVisible and indentLevel > 0
      invisibleIndex = 0
      for i in [0...indentLevel]
        indentGuide = @domElementPool.buildElement("span", "indent-guide")
        for j in [0...tabLength]
          if invisible = endOfLineInvisibles?[invisibleIndex++]
            invisibleSpan = @domElementPool.buildElement("span", "invisible-character")
            textNode = @domElementPool.buildText(invisible)
            invisibleSpan.appendChild(textNode)
            indentGuide.appendChild(invisibleSpan)

            @currentLineTextNodes.push(textNode)
          else
            textNode = @domElementPool.buildText(" ")
            indentGuide.appendChild(textNode)

            @currentLineTextNodes.push(textNode)
        lineNode.appendChild(indentGuide)

      while invisibleIndex < endOfLineInvisibles?.length
        invisible = endOfLineInvisibles[invisibleIndex++]
        invisibleSpan = @domElementPool.buildElement("span", "invisible-character")
        textNode = @domElementPool.buildText(invisible)
        invisibleSpan.appendChild(textNode)
        lineNode.appendChild(invisibleSpan)

        @currentLineTextNodes.push(textNode)
    else
      unless @appendEndOfLineNodes(id, lineNode)
        textNode = @domElementPool.buildText("\u00a0")
        lineNode.appendChild(textNode)

        @currentLineTextNodes.push(textNode)

  setLineInnerNodes: (id, lineNode) ->
    {lineText, tagCodes} = @newTileState.lines[id]

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
        textNode = @domElementPool.buildText(lineText.substr(startIndex, tagCode).replace(/\s/g, NBSPCharacter))
        startIndex += tagCode
        openScopeNode.appendChild(textNode)
        @currentLineTextNodes.push(textNode)

    if startIndex is 0
      textNode = @domElementPool.buildText(NBSPCharacter)
      lineNode.appendChild(textNode)
      @currentLineTextNodes.push(textNode)

  appendTokenNodes: (tokenText, isHardTab, firstNonWhitespaceIndex, firstTrailingWhitespaceIndex, hasIndentGuide, hasInvisibleCharacters, scopeNode) ->
    if isHardTab
      textNode = @domElementPool.buildText(tokenText)
      hardTabNode = @domElementPool.buildElement("span", "hard-tab")
      hardTabNode.classList.add("leading-whitespace") if firstNonWhitespaceIndex?
      hardTabNode.classList.add("trailing-whitespace") if firstTrailingWhitespaceIndex?
      hardTabNode.classList.add("indent-guide") if hasIndentGuide
      hardTabNode.classList.add("invisible-character") if hasInvisibleCharacters
      hardTabNode.appendChild(textNode)

      scopeNode.appendChild(hardTabNode)
      @currentLineTextNodes.push(textNode)
    else
      startIndex = 0
      endIndex = tokenText.length

      leadingWhitespaceNode = null
      leadingWhitespaceTextNode = null
      trailingWhitespaceNode = null
      trailingWhitespaceTextNode = null

      if firstNonWhitespaceIndex?
        leadingWhitespaceTextNode =
          @domElementPool.buildText(tokenText.substring(0, firstNonWhitespaceIndex))
        leadingWhitespaceNode = @domElementPool.buildElement("span", "leading-whitespace")
        leadingWhitespaceNode.classList.add("indent-guide") if hasIndentGuide
        leadingWhitespaceNode.classList.add("invisible-character") if hasInvisibleCharacters
        leadingWhitespaceNode.appendChild(leadingWhitespaceTextNode)

        startIndex = firstNonWhitespaceIndex

      if firstTrailingWhitespaceIndex?
        tokenIsOnlyWhitespace = firstTrailingWhitespaceIndex is 0

        trailingWhitespaceTextNode =
          @domElementPool.buildText(tokenText.substring(firstTrailingWhitespaceIndex))
        trailingWhitespaceNode = @domElementPool.buildElement("span", "trailing-whitespace")
        trailingWhitespaceNode.classList.add("indent-guide") if hasIndentGuide and not firstNonWhitespaceIndex? and tokenIsOnlyWhitespace
        trailingWhitespaceNode.classList.add("invisible-character") if hasInvisibleCharacters
        trailingWhitespaceNode.appendChild(trailingWhitespaceTextNode)

        endIndex = firstTrailingWhitespaceIndex

      if leadingWhitespaceNode?
        scopeNode.appendChild(leadingWhitespaceNode)
        @currentLineTextNodes.push(leadingWhitespaceTextNode)

      if tokenText.length > MaxTokenLength
        while startIndex < endIndex
          textNode = @domElementPool.buildText(
            @sliceText(tokenText, startIndex, startIndex + MaxTokenLength)
          )
          textSpan = @domElementPool.buildElement("span")

          textSpan.appendChild(textNode)
          scopeNode.appendChild(textSpan)
          startIndex += MaxTokenLength
          @currentLineTextNodes.push(textNode)
      else
        textNode = @domElementPool.buildText(@sliceText(tokenText, startIndex, endIndex))
        scopeNode.appendChild(textNode)
        @currentLineTextNodes.push(textNode)

      if trailingWhitespaceNode?
        scopeNode.appendChild(trailingWhitespaceNode)
        @currentLineTextNodes.push(trailingWhitespaceTextNode)

  sliceText: (tokenText, startIndex, endIndex) ->
    if startIndex? and endIndex? and startIndex > 0 or endIndex < tokenText.length
      tokenText = tokenText.slice(startIndex, endIndex)
    tokenText

  appendEndOfLineNodes: (id, lineNode) ->
    {endOfLineInvisibles} = @newTileState.lines[id]

    hasInvisibles = false
    if endOfLineInvisibles?
      for invisible in endOfLineInvisibles
        hasInvisibles = true
        invisibleSpan = @domElementPool.buildElement("span", "invisible-character")
        textNode = @domElementPool.buildText(invisible)
        invisibleSpan.appendChild(textNode)
        lineNode.appendChild(invisibleSpan)

        @currentLineTextNodes.push(textNode)

    hasInvisibles

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

  lineNodeForScreenRow: (screenRow) ->
    @lineNodesByLineId[@lineIdsByScreenRow[screenRow]]

  textNodesForScreenRow: (screenRow) ->
    @textNodesByLineId[@lineIdsByScreenRow[screenRow]]?.slice()
