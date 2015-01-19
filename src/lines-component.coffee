_ = require 'underscore-plus'
React = require 'react-atom-fork'
{div, span} = require 'reactionary-atom-fork'
{debounce, isEqual, isEqualForProperties, multiplyString, toArray} = require 'underscore-plus'
{$$} = require 'space-pen'

Decoration = require './decoration'
CursorsComponent = require './cursors-component'
HighlightsComponent = require './highlights-component'
OverlayManager = require './overlay-manager'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
WrapperDiv = document.createElement('div')

module.exports =
LinesComponent = React.createClass
  displayName: 'LinesComponent'

  render: ->
    {performedInitialMeasurement, cursorBlinkPeriod, cursorBlinkResumeDelay} = @props

    if performedInitialMeasurement
      {editor, overlayDecorations, highlightDecorations, scrollHeight, scrollWidth, placeholderText, backgroundColor} = @props
      {lineHeightInPixels, defaultCharWidth, scrollViewHeight, scopedCharacterWidthsChangeCount} = @props
      {scrollTop, scrollLeft, cursorPixelRects} = @props
      style =
        height: Math.max(scrollHeight, scrollViewHeight)
        width: scrollWidth
        WebkitTransform: @getTransform()
        backgroundColor: if editor.isMini() then null else backgroundColor

    div {className: 'lines', style},
      div className: 'placeholder-text', placeholderText if placeholderText?

      CursorsComponent {
        cursorPixelRects, cursorBlinkPeriod, cursorBlinkResumeDelay, lineHeightInPixels,
        defaultCharWidth, scopedCharacterWidthsChangeCount, performedInitialMeasurement
      }

      HighlightsComponent {
        editor, highlightDecorations, lineHeightInPixels, defaultCharWidth,
        scopedCharacterWidthsChangeCount, performedInitialMeasurement
      }

  getTransform: ->
    {scrollTop, scrollLeft, useHardwareAcceleration} = @props

    if useHardwareAcceleration
      "translate3d(#{-scrollLeft}px, #{-scrollTop}px, 0px)"
    else
      "translate(#{-scrollLeft}px, #{-scrollTop}px)"

  componentWillMount: ->
    @measuredLines = new WeakSet
    @lineNodesByLineId = {}
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}
    @renderedDecorationsByLineId = {}

  componentDidMount: ->
    if @props.useShadowDOM
      insertionPoint = document.createElement('content')
      insertionPoint.setAttribute('select', '.overlayer')
      @getDOMNode().appendChild(insertionPoint)

      insertionPoint = document.createElement('content')
      insertionPoint.setAttribute('select', 'atom-overlay')
      @overlayManager = new OverlayManager(@props.hostElement)
      @getDOMNode().appendChild(insertionPoint)
    else
      @overlayManager = new OverlayManager(@getDOMNode())

  shouldComponentUpdate: (newProps) ->
    return true unless isEqualForProperties(newProps, @props,
      'renderedRowRange', 'lineDecorations', 'highlightDecorations', 'lineHeightInPixels', 'defaultCharWidth',
      'overlayDecorations', 'scrollTop', 'scrollLeft', 'showIndentGuide', 'scrollingVertically', 'visible',
      'scrollViewHeight', 'mouseWheelScreenRow', 'scopedCharacterWidthsChangeCount', 'lineWidth', 'useHardwareAcceleration',
      'placeholderText', 'performedInitialMeasurement', 'backgroundColor', 'cursorPixelRects'
    )

    {renderedRowRange, pendingChanges} = newProps
    return false unless renderedRowRange?

    [renderedStartRow, renderedEndRow] = renderedRowRange
    for change in pendingChanges
      if change.screenDelta is 0
        return true unless change.end < renderedStartRow or renderedEndRow <= change.start
      else
        return true unless renderedEndRow <= change.start

    false

  componentDidUpdate: (prevProps) ->
    {visible, scrollingVertically, performedInitialMeasurement} = @props
    return unless performedInitialMeasurement

    @clearScreenRowCaches() unless prevProps.lineHeightInPixels is @props.lineHeightInPixels
    @removeLineNodes() unless isEqualForProperties(prevProps, @props, 'showIndentGuide')
    @updateLines(@props.lineWidth isnt prevProps.lineWidth)
    @measureCharactersInNewLines() if visible and not scrollingVertically

    @overlayManager?.render(@props)

  clearScreenRowCaches: ->
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}

  updateLines: (updateWidth) ->
    {tokenizedLines, renderedRowRange, showIndentGuide, selectionChanged, lineDecorations} = @props
    [startRow] = renderedRowRange

    @removeLineNodes(tokenizedLines)
    @appendOrUpdateVisibleLineNodes(tokenizedLines, startRow, updateWidth)

  removeLineNodes: (visibleLines=[]) ->
    {mouseWheelScreenRow} = @props
    visibleLineIds = new Set
    visibleLineIds.add(line.id.toString()) for line in visibleLines
    node = @getDOMNode()
    for lineId, lineNode of @lineNodesByLineId when not visibleLineIds.has(lineId)
      screenRow = @screenRowsByLineId[lineId]
      if not screenRow? or screenRow isnt mouseWheelScreenRow
        delete @lineNodesByLineId[lineId]
        delete @lineIdsByScreenRow[screenRow] if @lineIdsByScreenRow[screenRow] is lineId
        delete @screenRowsByLineId[lineId]
        delete @renderedDecorationsByLineId[lineId]
        node.removeChild(lineNode)

  appendOrUpdateVisibleLineNodes: (visibleLines, startRow, updateWidth) ->
    {lineDecorations} = @props

    newLines = null
    newLinesHTML = null

    for line, index in visibleLines
      screenRow = startRow + index

      if @hasLineNode(line.id)
        @updateLineNode(line, screenRow, updateWidth)
      else
        newLines ?= []
        newLinesHTML ?= ""
        newLines.push(line)
        newLinesHTML += @buildLineHTML(line, screenRow)
        @screenRowsByLineId[line.id] = screenRow
        @lineIdsByScreenRow[screenRow] = line.id

      @renderedDecorationsByLineId[line.id] = lineDecorations[screenRow]

    return unless newLines?

    WrapperDiv.innerHTML = newLinesHTML
    newLineNodes = toArray(WrapperDiv.children)
    node = @getDOMNode()
    for line, i in newLines
      lineNode = newLineNodes[i]
      @lineNodesByLineId[line.id] = lineNode
      node.appendChild(lineNode)

  hasLineNode: (lineId) ->
    @lineNodesByLineId.hasOwnProperty(lineId)

  buildLineHTML: (line, screenRow) ->
    {showIndentGuide, lineHeightInPixels, lineDecorations, lineWidth} = @props
    {tokens, text, lineEnding, fold, isSoftWrapped, indentLevel} = line

    classes = ''
    if decorations = lineDecorations[screenRow]
      for id, decoration of decorations
        if Decoration.isType(decoration, 'line')
          classes += decoration.class + ' '
    classes += 'line'

    top = screenRow * lineHeightInPixels
    lineHTML = "<div class=\"#{classes}\" style=\"position: absolute; top: #{top}px; width: #{lineWidth}px;\" data-screen-row=\"#{screenRow}\">"

    if text is ""
      lineHTML += @buildEmptyLineInnerHTML(line)
    else
      lineHTML += @buildLineInnerHTML(line)

    lineHTML += '<span class="fold-marker"></span>' if fold
    lineHTML += "</div>"
    lineHTML

  buildEmptyLineInnerHTML: (line) ->
    {showIndentGuide} = @props
    {indentLevel, tabLength, endOfLineInvisibles} = line

    if showIndentGuide and indentLevel > 0
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
        lineHTML += "<span class='invisible-character'>#{line.endOfLineInvisibles[invisibleIndex++]}</span>"

      lineHTML
    else
      @buildEndOfLineHTML(line) or '&nbsp;'

  buildLineInnerHTML: (line) ->
    {editor, showIndentGuide} = @props
    {tokens, text} = line
    innerHTML = ""

    scopeStack = []
    firstTrailingWhitespacePosition = text.search(/\s*$/)
    lineIsWhitespaceOnly = firstTrailingWhitespacePosition is 0
    for token in tokens
      innerHTML += @updateScopeStack(scopeStack, token.scopes)
      hasIndentGuide = not editor.isMini() and showIndentGuide and (token.hasLeadingWhitespace() or (token.hasTrailingWhitespace() and lineIsWhitespaceOnly))
      innerHTML += token.getValueAsHtml({hasIndentGuide})

    innerHTML += @popScope(scopeStack) while scopeStack.length > 0
    innerHTML += @buildEndOfLineHTML(line)
    innerHTML

  buildEndOfLineHTML: (line) ->
    {endOfLineInvisibles} = line

    html = ''
    if endOfLineInvisibles?
      for invisible in endOfLineInvisibles
        html += "<span class='invisible-character'>#{invisible}</span>"
    html

  updateScopeStack: (scopeStack, desiredScopeDescriptor) ->
    html = ""

    # Find a common prefix
    for scope, i in desiredScopeDescriptor
      break unless scopeStack[i] is desiredScopeDescriptor[i]

    # Pop scopeDescriptor until we're at the common prefx
    until scopeStack.length is i
      html += @popScope(scopeStack)

    # Push onto common prefix until scopeStack equals desiredScopeDescriptor
    for j in [i...desiredScopeDescriptor.length]
      html += @pushScope(scopeStack, desiredScopeDescriptor[j])

    html

  popScope: (scopeStack) ->
    scopeStack.pop()
    "</span>"

  pushScope: (scopeStack, scope) ->
    scopeStack.push(scope)
    "<span class=\"#{scope.replace(/\.+/g, ' ')}\">"

  updateLineNode: (line, screenRow, updateWidth) ->
    {lineHeightInPixels, lineDecorations, lineWidth} = @props
    lineNode = @lineNodesByLineId[line.id]

    decorations = lineDecorations[screenRow]
    previousDecorations = @renderedDecorationsByLineId[line.id]

    if previousDecorations?
      for id, decoration of previousDecorations
        if Decoration.isType(decoration, 'line') and not @hasDecoration(decorations, decoration)
          lineNode.classList.remove(decoration.class)

    if decorations?
      for id, decoration of decorations
        if Decoration.isType(decoration, 'line') and not @hasDecoration(previousDecorations, decoration)
          lineNode.classList.add(decoration.class)

    lineNode.style.width = lineWidth + 'px' if updateWidth

    unless @screenRowsByLineId[line.id] is screenRow
      lineNode.style.top = screenRow * lineHeightInPixels + 'px'
      lineNode.dataset.screenRow = screenRow
      @screenRowsByLineId[line.id] = screenRow
      @lineIdsByScreenRow[screenRow] = line.id

  hasDecoration: (decorations, decoration) ->
    decorations? and decorations[decoration.id] is decoration

  lineNodeForScreenRow: (screenRow) ->
    @lineNodesByLineId[@lineIdsByScreenRow[screenRow]]

  measureLineHeightAndDefaultCharWidth: ->
    node = @getDOMNode()
    node.appendChild(DummyLineNode)
    lineHeightInPixels = DummyLineNode.getBoundingClientRect().height
    charWidth = DummyLineNode.firstChild.getBoundingClientRect().width
    node.removeChild(DummyLineNode)

    {editor, presenter} = @props
    presenter?.setLineHeight(lineHeightInPixels)
    editor.setLineHeightInPixels(lineHeightInPixels)
    presenter?.setBaseCharacterWidth(charWidth)
    editor.setDefaultCharWidth(charWidth)

  remeasureCharacterWidths: ->
    return unless @props.performedInitialMeasurement

    @clearScopedCharWidths()
    @measureCharactersInNewLines()

  measureCharactersInNewLines: ->
    {editor, tokenizedLines, renderedRowRange} = @props
    [visibleStartRow] = renderedRowRange
    node = @getDOMNode()

    editor.batchCharacterMeasurement =>
      for tokenizedLine in tokenizedLines
        unless @measuredLines.has(tokenizedLine)
          lineNode = @lineNodesByLineId[tokenizedLine.id]
          @measureCharactersInLine(tokenizedLine, lineNode)
      return

  measureCharactersInLine: (tokenizedLine, lineNode) ->
    {editor} = @props
    rangeForMeasurement = null
    iterator = null
    charIndex = 0

    for {value, scopes, hasPairedCharacter} in tokenizedLine.tokens
      charWidths = editor.getScopedCharWidths(scopes)

      valueIndex = 0
      while valueIndex < value.length
        if hasPairedCharacter
          char = value.substr(valueIndex, 2)
          charLength = 2
          valueIndex += 2
        else
          char = value[valueIndex]
          charLength = 1
          valueIndex++

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
          editor.setScopedCharWidth(scopes, char, charWidth)

        charIndex += charLength

    @measuredLines.add(tokenizedLine)

  clearScopedCharWidths: ->
    @measuredLines.clear()
    @props.editor.clearScopedCharWidths()
