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

    classes = ''
    if decorationClasses?
      for decorationClass in decorationClasses
        classes += decorationClass + ' '
    classes += 'line'

    lineHTML = "<div class=\"#{classes}\" style=\"position: absolute; top: #{top}px; width: #{width}px;\" data-screen-row=\"#{screenRow}\">"

    if text is ""
      lineHTML += @buildEmptyLineInnerHTML(id)
    else
      lineHTML += @buildLineInnerHTML(id)

    lineHTML += '<span class="fold-marker"></span>' if fold
    lineHTML += "</div>"
    lineHTML

  buildEmptyLineInnerHTML: (id) ->
    {indentGuidesVisible} = @newState
    {indentLevel, tabLength, endOfLineInvisibles} = @newTileState.lines[id]

    if indentGuidesVisible and indentLevel > 0
      invisibleIndex = 0
      lineHTML = ''
      for i in [0...indentLevel]
        lineHTML += "<span class='indent-guide'>"
        for j in [0...tabLength]
          if invisible = endOfLineInvisibles?[invisibleIndex++]
            lineHTML += "<span class='invisible-character'>#{invisible}</span>"
          else
            lineHTML += ' '
        lineHTML += "</span>"

      while invisibleIndex < endOfLineInvisibles?.length
        lineHTML += "<span class='invisible-character'>#{endOfLineInvisibles[invisibleIndex++]}</span>"

      lineHTML
    else
      @buildEndOfLineHTML(id) or '&nbsp;'

  buildLineInnerHTML: (id) ->
    lineState = @newTileState.lines[id]
    {firstNonWhitespaceIndex, firstTrailingWhitespaceIndex, invisibles} = lineState
    lineIsWhitespaceOnly = firstTrailingWhitespaceIndex is 0

    innerHTML = ""
    @tokenIterator.reset(lineState)

    while @tokenIterator.next()
      for scope in @tokenIterator.getScopeEnds()
        innerHTML += "</span>"

      for scope in @tokenIterator.getScopeStarts()
        innerHTML += "<span class=\"#{scope.replace(/\.+/g, ' ')}\">"

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

      innerHTML += @buildTokenHTML(tokenText, isHardTab, tokenFirstNonWhitespaceIndex, tokenFirstTrailingWhitespaceIndex, hasIndentGuide, hasInvisibleCharacters)

    for scope in @tokenIterator.getScopeEnds()
      innerHTML += "</span>"

    for scope in @tokenIterator.getScopes()
      innerHTML += "</span>"

    innerHTML += @buildEndOfLineHTML(id)
    innerHTML

  buildTokenHTML: (tokenText, isHardTab, firstNonWhitespaceIndex, firstTrailingWhitespaceIndex, hasIndentGuide, hasInvisibleCharacters) ->
    if isHardTab
      classes = 'hard-tab'
      classes += ' leading-whitespace' if firstNonWhitespaceIndex?
      classes += ' trailing-whitespace' if firstTrailingWhitespaceIndex?
      classes += ' indent-guide' if hasIndentGuide
      classes += ' invisible-character' if hasInvisibleCharacters
      return "<span class='#{classes}'>#{@escapeTokenText(tokenText)}</span>"
    else
      startIndex = 0
      endIndex = tokenText.length

      leadingHtml = ''
      trailingHtml = ''

      if firstNonWhitespaceIndex?
        leadingWhitespace = tokenText.substring(0, firstNonWhitespaceIndex)

        classes = 'leading-whitespace'
        classes += ' indent-guide' if hasIndentGuide
        classes += ' invisible-character' if hasInvisibleCharacters

        leadingHtml = "<span class='#{classes}'>#{leadingWhitespace}</span>"
        startIndex = firstNonWhitespaceIndex

      if firstTrailingWhitespaceIndex?
        tokenIsOnlyWhitespace = firstTrailingWhitespaceIndex is 0
        trailingWhitespace = tokenText.substring(firstTrailingWhitespaceIndex)

        classes = 'trailing-whitespace'
        classes += ' indent-guide' if hasIndentGuide and not firstNonWhitespaceIndex? and tokenIsOnlyWhitespace
        classes += ' invisible-character' if hasInvisibleCharacters

        trailingHtml = "<span class='#{classes}'>#{trailingWhitespace}</span>"

        endIndex = firstTrailingWhitespaceIndex

      html = leadingHtml
      if tokenText.length > MaxTokenLength
        while startIndex < endIndex
          html += "<span>" + @escapeTokenText(tokenText, startIndex, startIndex + MaxTokenLength) + "</span>"
          startIndex += MaxTokenLength
      else
        html += @escapeTokenText(tokenText, startIndex, endIndex)

      html += trailingHtml
    html

  escapeTokenText: (tokenText, startIndex, endIndex) ->
    if startIndex? and endIndex? and startIndex > 0 or endIndex < tokenText.length
      tokenText = tokenText.slice(startIndex, endIndex)
    tokenText.replace(TokenTextEscapeRegex, @escapeTokenTextReplace)

  escapeTokenTextReplace: (match) ->
    switch match
      when '&' then '&amp;'
      when '"' then '&quot;'
      when "'" then '&#39;'
      when '<' then '&lt;'
      when '>' then '&gt;'
      else match

  buildEndOfLineHTML: (id) ->
    {endOfLineInvisibles} = @newTileState.lines[id]

    html = ''
    if endOfLineInvisibles?
      for invisible in endOfLineInvisibles
        html += "<span class='invisible-character'>#{invisible}</span>"
    html

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
