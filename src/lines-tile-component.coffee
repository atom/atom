_ = require 'underscore-plus'

HighlightsComponent = require './highlights-component'
TokenIterator = require './token-iterator'
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
WrapperDiv = document.createElement('div')
TokenTextEscapeRegex = /[&"'<>]/g
MaxTokenLength = 20000

cloneObject = (object) ->
  clone = {}
  clone[key] = value for key, value of object
  clone

module.exports =
class LinesTileComponent
  constructor: ({@presenter, @id}) ->
    @tokenIterator = new TokenIterator
    @measuredLines = new Set
    @lineNodesByLineId = {}
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}
    @domNode = document.createElement("div")
    @domNode.classList.add("tile")
    @domNode.style.position = "absolute"
    @domNode.style.display = "block"

    @highlightsComponent = new HighlightsComponent
    @domNode.appendChild(@highlightsComponent.getDomNode())

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
    @lineNodesByLineId[id].remove()
    delete @lineNodesByLineId[id]
    delete @lineIdsByScreenRow[@screenRowsByLineId[id]]
    delete @screenRowsByLineId[id]
    delete @oldTileState.lines[id]

  updateLineNodes: ->
    for id of @oldTileState.lines
      unless @newTileState.lines.hasOwnProperty(id)
        @removeLineNode(id)

    newLineIds = null
    newLinesHTML = null

    for id, lineState of @newTileState.lines
      if @oldTileState.lines.hasOwnProperty(id)
        @updateLineNode(id)
      else
        newLineIds ?= []
        newLinesHTML ?= ""
        newLineIds.push(id)
        newLinesHTML += @buildLineHTML(id)
        @screenRowsByLineId[id] = lineState.screenRow
        @lineIdsByScreenRow[lineState.screenRow] = id
        @oldTileState.lines[id] = cloneObject(lineState)

    return unless newLineIds?

    WrapperDiv.innerHTML = newLinesHTML
    newLineNodes = _.toArray(WrapperDiv.children)
    for id, i in newLineIds
      lineNode = newLineNodes[i]
      @lineNodesByLineId[id] = lineNode
      @domNode.appendChild(lineNode)

    return

  buildLineHTML: (id) ->
    {width} = @newState
    {screenRow, tokens, text, top, lineEnding, fold, isSoftWrapped, indentLevel, decorationClasses} = @newTileState.lines[id]

    lineNode = document.createElement("div")
    lineNode.classList.add("line")
    if decorationClasses?
      for decorationClass in decorationClasses
        lineNode.classList.add(decorationClass)

    lineNode.style.position = "absolute"
    lineNode.style.top = top + "px"
    lineNode.style.width = width + "px"
    lineNode.dataset.screenRow = screenRow

    if text is ""
      @appendEmptyLineInnerNodes(id, lineNode)
    else
      @appendLineInnerNodes(id, lineNode)

    if fold
      foldMarker = document.createElement("span")
      foldMarker.classList.add("fold-marker")
      lineNode.appendChild(foldMarker)

    lineNode.outerHTML

  appendEmptyLineInnerNodes: (id, lineNode) ->
    {indentGuidesVisible} = @newState
    {indentLevel, tabLength, endOfLineInvisibles} = @newTileState.lines[id]

    if indentGuidesVisible and indentLevel > 0
      invisibleIndex = 0
      lineHTML = ''
      for i in [0...indentLevel]
        indentGuide = document.createElement("span")
        indentGuide.classList.add("indent-guide")
        for j in [0...tabLength]
          if invisible = endOfLineInvisibles?[invisibleIndex++]
            invisibleCharacter = document.createElement("span")
            invisibleCharacter.classList.add("invisible-character")
            invisibleCharacter.textContent = invisible
            indentGuide.appendChild(invisibleCharacter)
          else
            indentGuide.insertAdjacentText("beforeend", " ")
        lineNode.appendChild(indentGuide)

      while invisibleIndex < endOfLineInvisibles?.length
        invisibleCharacter = document.createElement("span")
        invisibleCharacter.classList.add("invisible-character")
        invisibleCharacter.textContent = endOfLineInvisibles[invisibleIndex++]
        lineNode.appendChild(invisibleCharacter)
    else
      unless @appendEndOfLineNodes(id, lineNode)
        lineNode.insertAdjacentHTML("beforeend", "&nbsp;")

  appendLineInnerNodes: (id, lineNode) ->
    lineState = @newTileState.lines[id]
    {firstNonWhitespaceIndex, firstTrailingWhitespaceIndex, invisibles} = lineState
    lineIsWhitespaceOnly = firstTrailingWhitespaceIndex is 0

    innerHTML = ""
    @tokenIterator.reset(lineState)
    openScopeNode = lineNode

    while @tokenIterator.next()
      for scope in @tokenIterator.getScopeEnds()
        openScopeNode = openScopeNode.parentElement

      for scope in @tokenIterator.getScopeStarts()
        newScopeNode = document.createElement("span")
        newScopeNode.className = scope.replace(/\.+/g, ' ')
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

      @appendToken(openScopeNode, tokenText, isHardTab, tokenFirstNonWhitespaceIndex, tokenFirstTrailingWhitespaceIndex, hasIndentGuide, hasInvisibleCharacters)

    @appendEndOfLineNodes(id, lineNode)

  appendToken: (scopeNode, tokenText, isHardTab, firstNonWhitespaceIndex, firstTrailingWhitespaceIndex, hasIndentGuide, hasInvisibleCharacters) ->
    if isHardTab
      hardTab = document.createElement("span")
      hardTab.classList.add("hard-tab")
      hardTab.classList.add("leading-whitespace") if firstNonWhitespaceIndex?
      hardTab.classList.add("trailing-whitespace") if firstTrailingWhitespaceIndex?
      hardTab.classList.add("indent-guide") if hasIndentGuide
      hardTab.classList.add("invisible-character") if hasInvisibleCharacters
      hardTab.textContent = tokenText

      scopeNode.appendChild(hardTab)
    else
      startIndex = 0
      endIndex = tokenText.length

      leadingWhitespaceNode = null
      trailingWhitespaceNode = null

      if firstNonWhitespaceIndex?
        leadingWhitespaceNode = document.createElement("span")
        leadingWhitespaceNode.classList.add("leading-whitespace")
        leadingWhitespaceNode.classList.add("indent-guide") if hasIndentGuide
        leadingWhitespaceNode.classList.add("invisible-character") if hasInvisibleCharacters
        leadingWhitespaceNode.textContent = tokenText.substring(0, firstNonWhitespaceIndex)

        startIndex = firstNonWhitespaceIndex

      if firstTrailingWhitespaceIndex?
        tokenIsOnlyWhitespace = firstTrailingWhitespaceIndex is 0

        trailingWhitespaceNode = document.createElement("span")
        trailingWhitespaceNode.classList.add("trailing-whitespace")
        trailingWhitespaceNode.classList.add("indent-guide") if hasIndentGuide and not firstNonWhitespaceIndex? and tokenIsOnlyWhitespace
        trailingWhitespaceNode.classList.add("invisible-character") if hasInvisibleCharacters
        trailingWhitespaceNode.textContent = tokenText.substring(firstTrailingWhitespaceIndex)

        endIndex = firstTrailingWhitespaceIndex

      scopeNode.appendChild(leadingWhitespaceNode) if leadingWhitespaceNode?

      if tokenText.length > MaxTokenLength
        while startIndex < endIndex
          tokenNode = document.createElement("span")
          tokenNode.textContent = @sliceText(tokenText, startIndex, startIndex + MaxTokenLength)
          scopeNode.appendChild(tokenNode)
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

        invisibleCharacter = document.createElement("span")
        invisibleCharacter.classList.add("invisible-character")
        invisibleCharacter.textContent = invisible
        lineNode.appendChild(invisibleCharacter)

    hasInvisibles

  updateLineNode: (id) ->
    oldLineState = @oldTileState.lines[id]
    newLineState = @newTileState.lines[id]

    lineNode = @lineNodesByLineId[id]

    if @newState.width isnt @oldState.width
      lineNode.style.width = @newState.width + 'px'

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

    if newLineState.top isnt oldLineState.top
      lineNode.style.top = newLineState.top + 'px'
      oldLineState.top = newLineState.top

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

        continue if char is '\0'

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
            atom.assert false, "Expected index to be less than the length of text node while measuring", (error) =>
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
