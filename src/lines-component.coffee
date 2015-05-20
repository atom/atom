_ = require 'underscore-plus'
{toArray} = require 'underscore-plus'
{$$} = require 'space-pen'

CursorsComponent = require './cursors-component'
HighlightsComponent = require './highlights-component'
TokenIterator = require './token-iterator'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
WrapperDiv = document.createElement('div')
TokenTextEscapeRegex = /[&"'<>]/g
MaxTokenLength = 20000

cloneObject = (object) ->
  clone = {}
  clone[key] = value for key, value of object
  clone

module.exports =
class LinesComponent
  placeholderTextDiv: null

  constructor: ({@presenter, @hostElement, @useShadowDOM, visible}) ->
    @tokenIterator = new TokenIterator
    @measuredLines = new Set
    @lineNodesByLineId = {}
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}
    @renderedDecorationsByLineId = {}

    @domNode = document.createElement('div')
    @domNode.classList.add('lines')

    @cursorsComponent = new CursorsComponent(@presenter)
    @domNode.appendChild(@cursorsComponent.getDomNode())

    @highlightsComponent = new HighlightsComponent(@presenter)
    @domNode.appendChild(@highlightsComponent.getDomNode())

    if @useShadowDOM
      insertionPoint = document.createElement('content')
      insertionPoint.setAttribute('select', '.overlayer')
      @domNode.appendChild(insertionPoint)

  getDomNode: ->
    @domNode

  updateSync: (state) ->
    @newState = state.content
    @oldState ?= {lines: {}}

    if @newState.scrollHeight isnt @oldState.scrollHeight
      @domNode.style.height = @newState.scrollHeight + 'px'
      @oldState.scrollHeight = @newState.scrollHeight

    if @newState.scrollTop isnt @oldState.scrollTop or @newState.scrollLeft isnt @oldState.scrollLeft
      @domNode.style['-webkit-transform'] = "translate3d(#{-@newState.scrollLeft}px, #{-@newState.scrollTop}px, 0px)"
      @oldState.scrollTop = @newState.scrollTop
      @oldState.scrollLeft = @newState.scrollLeft

    if @newState.backgroundColor isnt @oldState.backgroundColor
      @domNode.style.backgroundColor = @newState.backgroundColor
      @oldState.backgroundColor = @newState.backgroundColor

    if @newState.placeholderText isnt @oldState.placeholderText
      @placeholderTextDiv?.remove()
      if @newState.placeholderText?
        @placeholderTextDiv = document.createElement('div')
        @placeholderTextDiv.classList.add('placeholder-text')
        @placeholderTextDiv.textContent = @newState.placeholderText
        @domNode.appendChild(@placeholderTextDiv)

    @removeLineNodes() unless @oldState.indentGuidesVisible is @newState.indentGuidesVisible
    @updateLineNodes()

    if @newState.scrollWidth isnt @oldState.scrollWidth
      @domNode.style.width = @newState.scrollWidth + 'px'
      @oldState.scrollWidth = @newState.scrollWidth

    @cursorsComponent.updateSync(state)
    @highlightsComponent.updateSync(state)

    @oldState.indentGuidesVisible = @newState.indentGuidesVisible
    @oldState.scrollWidth = @newState.scrollWidth

  removeLineNodes: ->
    @removeLineNode(id) for id of @oldState.lines
    return

  removeLineNode: (id) ->
    @lineNodesByLineId[id].remove()
    delete @lineNodesByLineId[id]
    delete @lineIdsByScreenRow[@screenRowsByLineId[id]]
    delete @screenRowsByLineId[id]
    delete @oldState.lines[id]

  updateLineNodes: ->
    for id of @oldState.lines
      unless @newState.lines.hasOwnProperty(id)
        @removeLineNode(id)

    newLineIds = null
    newLinesHTML = null

    for id, lineState of @newState.lines
      if @oldState.lines.hasOwnProperty(id)
        @updateLineNode(id)
      else
        newLineIds ?= []
        newLinesHTML ?= ""
        newLineIds.push(id)
        newLinesHTML += @buildLineHTML(id)
        @screenRowsByLineId[id] = lineState.screenRow
        @lineIdsByScreenRow[lineState.screenRow] = id
        @oldState.lines[id] = cloneObject(lineState)

    return unless newLineIds?

    WrapperDiv.innerHTML = newLinesHTML
    newLineNodes = _.toArray(WrapperDiv.children)
    for id, i in newLineIds
      lineNode = newLineNodes[i]
      @lineNodesByLineId[id] = lineNode
      @domNode.appendChild(lineNode)

    return

  buildLineHTML: (id) ->
    {scrollWidth} = @newState
    {screenRow, tokens, text, top, lineEnding, fold, isSoftWrapped, indentLevel, decorationClasses} = @newState.lines[id]

    classes = ''
    if decorationClasses?
      for decorationClass in decorationClasses
        classes += decorationClass + ' '
    classes += 'line'

    lineHTML = "<div class=\"#{classes}\" style=\"position: absolute; top: #{top}px; width: #{scrollWidth}px;\" data-screen-row=\"#{screenRow}\">"

    if text is ""
      lineHTML += @buildEmptyLineInnerHTML(id)
    else
      lineHTML += @buildLineInnerHTML(id)

    lineHTML += '<span class="fold-marker"></span>' if fold
    lineHTML += "</div>"
    lineHTML

  buildEmptyLineInnerHTML: (id) ->
    {indentGuidesVisible} = @newState
    {indentLevel, tabLength, endOfLineInvisibles} = @newState.lines[id]

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
    lineState = @newState.lines[id]
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
    {endOfLineInvisibles} = @newState.lines[id]

    html = ''
    if endOfLineInvisibles?
      for invisible in endOfLineInvisibles
        html += "<span class='invisible-character'>#{invisible}</span>"
    html

  updateLineNode: (id) ->
    oldLineState = @oldState.lines[id]
    newLineState = @newState.lines[id]

    lineNode = @lineNodesByLineId[id]

    if @newState.scrollWidth isnt @oldState.scrollWidth
      lineNode.style.width = @newState.scrollWidth + 'px'

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
      oldLineState.top = newLineState.cop

    if newLineState.screenRow isnt oldLineState.screenRow
      lineNode.dataset.screenRow = newLineState.screenRow
      oldLineState.screenRow = newLineState.screenRow
      @lineIdsByScreenRow[newLineState.screenRow] = id

  lineNodeForScreenRow: (screenRow) ->
    @lineNodesByLineId[@lineIdsByScreenRow[screenRow]]

  measureLineHeightAndDefaultCharWidth: ->
    @domNode.appendChild(DummyLineNode)
    lineHeightInPixels = DummyLineNode.getBoundingClientRect().height
    charWidth = DummyLineNode.firstChild.getBoundingClientRect().width
    @domNode.removeChild(DummyLineNode)

    @presenter.setLineHeight(lineHeightInPixels)
    @presenter.setBaseCharacterWidth(charWidth)

  remeasureCharacterWidths: ->
    return unless @presenter.baseCharacterWidth

    @clearScopedCharWidths()
    @measureCharactersInNewLines()

  measureCharactersInNewLines: ->
    @presenter.batchCharacterMeasurement =>
      for id, lineState of @oldState.lines
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
            textNodeIndex = 0
            nextTextNodeIndex = textNode.textContent.length

          while nextTextNodeIndex <= charIndex
            textNode = iterator.nextNode()
            textNodeIndex = nextTextNodeIndex
            nextTextNodeIndex = textNodeIndex + textNode.textContent.length

          i = charIndex - textNodeIndex
          rangeForMeasurement.setStart(textNode, i)
          rangeForMeasurement.setEnd(textNode, i + charLength)
          charWidth = rangeForMeasurement.getBoundingClientRect().width
          @presenter.setScopedCharacterWidth(scopes, char, charWidth)

        charIndex += charLength

    @measuredLines.add(lineId)

  clearScopedCharWidths: ->
    @measuredLines.clear()
    @presenter.clearScopedCharacterWidths()
