_ = require 'underscore-plus'

HighlightsComponent = require './highlights-component'
TokenIterator = require './token-iterator'
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
TokenTextEscapeRegex = /[&"'<>]/g
MaxTokenLength = 20000

cloneObject = (object) ->
  clone = {}
  clone[key] = value for key, value of object
  clone

module.exports =
class LinesTileComponent
  constructor: ({@presenter, @id, @domElementPool, @assert}) ->
    @tokenIterator = new TokenIterator
    @measuredLines = new Set
    @lineNodesByLineId = {}
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}
    @domNode = @domElementPool.build("div")
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
    delete @lineNodesByLineId[id]
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

  findNodeNextTo: (node) ->
    for nextNode, index in @domNode.children
      continue if index is 0 # skips highlights node
      return nextNode if @screenRowForNode(node) < @screenRowForNode(nextNode)
    return

  screenRowForNode: (node) -> parseInt(node.dataset.screenRow)

  buildLineNode: (id) ->
    {width} = @newState
    {screenRow, tokens, text, top, lineEnding, fold, isSoftWrapped, indentLevel, decorationClasses} = @newTileState.lines[id]

    lineNode = @domElementPool.build("div", "line")
    lineNode.dataset.screenRow = screenRow

    if decorationClasses?
      for decorationClass in decorationClasses
        lineNode.classList.add(decorationClass)

    if text is ""
      @setEmptyLineInnerNodes(id, lineNode)
    else
      @setLineInnerNodes(id, lineNode)

    lineNode.appendChild(@domElementPool.build("span", "fold-marker")) if fold
    lineNode

  setEmptyLineInnerNodes: (id, lineNode) ->
    {indentGuidesVisible} = @newState
    {indentLevel, tabLength, endOfLineInvisibles} = @newTileState.lines[id]

    if indentGuidesVisible and indentLevel > 0
      invisibleIndex = 0
      for i in [0...indentLevel]
        indentGuide = @domElementPool.build("span", "indent-guide")
        for j in [0...tabLength]
          if invisible = endOfLineInvisibles?[invisibleIndex++]
            indentGuide.appendChild(
              @domElementPool.build("span", "invisible-character", invisible)
            )
          else
            indentGuide.insertAdjacentText("beforeend", " ")
        lineNode.appendChild(indentGuide)

      while invisibleIndex < endOfLineInvisibles?.length
        invisible = endOfLineInvisibles[invisibleIndex++]
        lineNode.appendChild(
          @domElementPool.build("span", "invisible-character", invisible)
        )
    else
      unless @appendEndOfLineNodes(id, lineNode)
        lineNode.textContent = "\u00a0"

  setLineInnerNodes: (id, lineNode) ->
    lineState = @newTileState.lines[id]
    {firstNonWhitespaceIndex, firstTrailingWhitespaceIndex, invisibles} = lineState
    lineIsWhitespaceOnly = firstTrailingWhitespaceIndex is 0

    @tokenIterator.reset(lineState)
    openScopeNode = lineNode

    while @tokenIterator.next()
      for scope in @tokenIterator.getScopeEnds()
        openScopeNode = openScopeNode.parentElement

      for scope in @tokenIterator.getScopeStarts()
        newScopeNode = @domElementPool.build("span", scope.replace(/\.+/g, ' '))
        openScopeNode.appendChild(newScopeNode)
        openScopeNode = newScopeNode

      tokenStart = @tokenIterator.getScreenStart()
      tokenEnd = @tokenIterator.getScreenEnd()
      tokenText = @tokenIterator.getText()
      isHardTab = @tokenIterator.isHardTab()

      if hasLeadingWhitespace = tokenStart < firstNonWhitespaceIndex
        tokenFirstNonWhitespaceIndex = firstNonWhitespaceIndex - tokenStart
      else
        tokenFirstNonWhitespaceIndex = null

      if hasTrailingWhitespace = tokenEnd > firstTrailingWhitespaceIndex
        tokenFirstTrailingWhitespaceIndex = Math.max(0, firstTrailingWhitespaceIndex - tokenStart)
      else
        tokenFirstTrailingWhitespaceIndex = null

      hasIndentGuide =
        @newState.indentGuidesVisible and
          (hasLeadingWhitespace or lineIsWhitespaceOnly)

      hasInvisibleCharacters =
        (invisibles?.tab and isHardTab) or
          (invisibles?.space and (hasLeadingWhitespace or hasTrailingWhitespace))

      @appendTokenNodes(tokenText, isHardTab, tokenFirstNonWhitespaceIndex, tokenFirstTrailingWhitespaceIndex, hasIndentGuide, hasInvisibleCharacters, openScopeNode)

    @appendEndOfLineNodes(id, lineNode)

  appendTokenNodes: (tokenText, isHardTab, firstNonWhitespaceIndex, firstTrailingWhitespaceIndex, hasIndentGuide, hasInvisibleCharacters, scopeNode) ->
    if isHardTab
      hardTabNode = @domElementPool.build("span", "hard-tab", tokenText)
      hardTabNode.classList.add("leading-whitespace") if firstNonWhitespaceIndex?
      hardTabNode.classList.add("trailing-whitespace") if firstTrailingWhitespaceIndex?
      hardTabNode.classList.add("indent-guide") if hasIndentGuide
      hardTabNode.classList.add("invisible-character") if hasInvisibleCharacters

      scopeNode.appendChild(hardTabNode)
    else
      startIndex = 0
      endIndex = tokenText.length

      leadingWhitespaceNode = null
      trailingWhitespaceNode = null

      if firstNonWhitespaceIndex?
        leadingWhitespaceNode = @domElementPool.build(
          "span",
          "leading-whitespace",
          tokenText.substring(0, firstNonWhitespaceIndex)
        )
        leadingWhitespaceNode.classList.add("indent-guide") if hasIndentGuide
        leadingWhitespaceNode.classList.add("invisible-character") if hasInvisibleCharacters

        startIndex = firstNonWhitespaceIndex

      if firstTrailingWhitespaceIndex?
        tokenIsOnlyWhitespace = firstTrailingWhitespaceIndex is 0

        trailingWhitespaceNode = @domElementPool.build(
          "span",
          "trailing-whitespace",
          tokenText.substring(firstTrailingWhitespaceIndex)
        )
        trailingWhitespaceNode.classList.add("indent-guide") if hasIndentGuide and not firstNonWhitespaceIndex? and tokenIsOnlyWhitespace
        trailingWhitespaceNode.classList.add("invisible-character") if hasInvisibleCharacters

        endIndex = firstTrailingWhitespaceIndex

      scopeNode.appendChild(leadingWhitespaceNode) if leadingWhitespaceNode?

      if tokenText.length > MaxTokenLength
        while startIndex < endIndex
          text = @sliceText(tokenText, startIndex, startIndex + MaxTokenLength)
          scopeNode.appendChild(@domElementPool.build("span", null, text))
          startIndex += MaxTokenLength
      else
        scopeNode.insertAdjacentText("beforeend", @sliceText(tokenText, startIndex, endIndex))

      scopeNode.appendChild(trailingWhitespaceNode) if trailingWhitespaceNode?

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
        lineNode.appendChild(
          @domElementPool.build("span", "invisible-character", invisible)
        )

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

    if newLineState.screenRow isnt oldLineState.screenRow
      lineNode.dataset.screenRow = newLineState.screenRow
      oldLineState.screenRow = newLineState.screenRow
      @lineIdsByScreenRow[newLineState.screenRow] = id

  lineNodeForScreenRow: (screenRow) ->
    @lineNodesByLineId[@lineIdsByScreenRow[screenRow]]

  measureCharactersInNewLines: ->
    for id, lineState of @oldTileState.lines
      unless @measuredLines.has(id)
        lineNode = @lineNodesByLineId[id]
        @measureCharactersInLine(id, lineState, lineNode)
    return

  measureCharactersInLine: (lineId, tokenizedLine, lineNode) ->
    rangeForMeasurement = null
    iterator = null
    charIndex = 0

    @tokenIterator.reset(tokenizedLine)
    while @tokenIterator.next()
      scopes = @tokenIterator.getScopes()
      text = @tokenIterator.getText()
      charWidths = @presenter.getScopedCharacterWidths(scopes)

      textIndex = 0
      while textIndex < text.length
        if @tokenIterator.isPairedCharacter()
          char = text
          charLength = 2
          textIndex += 2
        else
          char = text[textIndex]
          charLength = 1
          textIndex++

        unless charWidths[char]?
          unless textNode?
            rangeForMeasurement ?= document.createRange()
            iterator =  document.createNodeIterator(lineNode, NodeFilter.SHOW_TEXT, AcceptFilter)
            textNode = iterator.nextNode()
            textNodeLength = textNode.textContent.length
            textNodeIndex = 0
            nextTextNodeIndex = textNodeLength

          while nextTextNodeIndex <= charIndex
            textNode = iterator.nextNode()
            textNodeLength = textNode.textContent.length
            textNodeIndex = nextTextNodeIndex
            nextTextNodeIndex = textNodeIndex + textNodeLength

          i = charIndex - textNodeIndex
          rangeForMeasurement.setStart(textNode, i)

          if i + charLength <= textNodeLength
            rangeForMeasurement.setEnd(textNode, i + charLength)
          else
            rangeForMeasurement.setEnd(textNode, textNodeLength)
            @assert false, "Expected index to be less than the length of text node while measuring", (error) =>
              editor = @presenter.model
              screenRow = tokenizedLine.screenRow
              bufferRow = editor.bufferRowForScreenRow(screenRow)

              error.metadata = {
                grammarScopeName: editor.getGrammar().scopeName
                screenRow: screenRow
                bufferRow: bufferRow
                softWrapped: editor.isSoftWrapped()
                softTabs: editor.getSoftTabs()
                i: i
                charLength: charLength
                textNodeLength: textNode.length
              }
              error.privateMetadataDescription = "The contents of line #{bufferRow + 1}."
              error.privateMetadata = {
                lineText: editor.lineTextForBufferRow(bufferRow)
              }
              error.privateMetadataRequestName = "measured-line-text"

          charWidth = rangeForMeasurement.getBoundingClientRect().width
          @presenter.setScopedCharacterWidth(scopes, char, charWidth)

        charIndex += charLength

    @measuredLines.add(lineId)

  clearMeasurements: ->
    @measuredLines.clear()
