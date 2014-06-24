_ = require 'underscore-plus'
React = require 'react-atom-fork'
{div, span} = require 'reactionary-atom-fork'
{debounce, isEqual, isEqualForProperties, multiplyString, toArray} = require 'underscore-plus'
{$$} = require 'space-pen'

HighlightsComponent = require './highlights-component'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
WrapperDiv = document.createElement('div')

module.exports =
LinesComponent = React.createClass
  displayName: 'LinesComponent'

  render: ->
    if @isMounted()
      {editor, highlightDecorations, scrollTop, scrollLeft, scrollHeight, scrollWidth} = @props
      {lineHeightInPixels, defaultCharWidth, scrollViewHeight, scopedCharacterWidthsChangeCount} = @props
      style =
        height: Math.max(scrollHeight, scrollViewHeight)
        width: scrollWidth
        WebkitTransform: "translate3d(#{-scrollLeft}px, #{-scrollTop}px, 0px)"

    # The lines div must have the 'editor-colors' class so it has an opaque
    # background to avoid sub-pixel anti-aliasing problems on the GPU
    div {className: 'lines editor-colors', style},
      HighlightsComponent({editor, highlightDecorations, lineHeightInPixels, defaultCharWidth, scopedCharacterWidthsChangeCount})

  componentWillMount: ->
    @measuredLines = new WeakSet
    @lineNodesByLineId = {}
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}
    @renderedDecorationsByLineId = {}

  shouldComponentUpdate: (newProps) ->
    return true unless isEqualForProperties(newProps, @props,
      'renderedRowRange', 'lineDecorations', 'highlightDecorations', 'lineHeightInPixels', 'defaultCharWidth',
      'scrollTop', 'scrollLeft', 'showIndentGuide', 'scrollingVertically', 'invisibles', 'visible',
      'scrollViewHeight', 'mouseWheelScreenRow', 'scopedCharacterWidthsChangeCount'
    )

    {renderedRowRange, pendingChanges} = newProps
    [renderedStartRow, renderedEndRow] = renderedRowRange
    for change in pendingChanges
      return true unless change.end < renderedStartRow or renderedEndRow <= change.start

    false

  componentDidUpdate: (prevProps) ->
    {visible, scrollingVertically} = @props

    @clearScreenRowCaches() unless prevProps.lineHeightInPixels is @props.lineHeightInPixels
    @removeLineNodes() unless isEqualForProperties(prevProps, @props, 'showIndentGuide', 'invisibles')
    @updateLines()
    @measureCharactersInNewLines() if visible and not scrollingVertically

  clearScreenRowCaches: ->
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}

  updateLines: ->
    {editor, renderedRowRange, showIndentGuide, selectionChanged, lineDecorations} = @props
    [startRow, endRow] = renderedRowRange

    visibleLines = editor.linesForScreenRows(startRow, endRow - 1)
    @removeLineNodes(visibleLines)
    @appendOrUpdateVisibleLineNodes(visibleLines, startRow)

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

  appendOrUpdateVisibleLineNodes: (visibleLines, startRow) ->
    {lineDecorations} = @props

    newLines = null
    newLinesHTML = null

    for line, index in visibleLines
      screenRow = startRow + index

      if @hasLineNode(line.id)
        @updateLineNode(line, screenRow)
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
    {editor, mini, showIndentGuide, lineHeightInPixels, lineDecorations} = @props
    {tokens, text, lineEnding, fold, isSoftWrapped, indentLevel} = line

    classes = ''
    if decorations = lineDecorations[screenRow]
      for decoration in decorations
        if editor.decorationMatchesType(decoration, 'line')
          classes += decoration.class + ' '
    classes += 'line'

    top = screenRow * lineHeightInPixels
    lineHTML = "<div class=\"#{classes}\" style=\"position: absolute; top: #{top}px; width: 100%;\" data-screen-row=\"#{screenRow}\">"

    if text is ""
      lineHTML += @buildEmptyLineInnerHTML(line)
    else
      lineHTML += @buildLineInnerHTML(line)

    lineHTML += '<span class="fold-marker"></span>' if fold
    lineHTML += "</div>"
    lineHTML

  buildEmptyLineInnerHTML: (line) ->
    {showIndentGuide} = @props
    {indentLevel, tabLength} = line

    if showIndentGuide and indentLevel > 0
      indentSpan = "<span class='indent-guide'>#{multiplyString(' ', tabLength)}</span>"
      multiplyString(indentSpan, indentLevel + 1)
    else
      "&nbsp;"

  buildLineInnerHTML: (line) ->
    {invisibles, mini, showIndentGuide, invisibles} = @props
    {tokens, text} = line
    innerHTML = ""

    scopeStack = []
    firstTrailingWhitespacePosition = text.search(/\s*$/)
    lineIsWhitespaceOnly = firstTrailingWhitespacePosition is 0
    for token in tokens
      innerHTML += @updateScopeStack(scopeStack, token.scopes)
      hasIndentGuide = not mini and showIndentGuide and token.hasLeadingWhitespace or (token.hasTrailingWhitespace and lineIsWhitespaceOnly)
      innerHTML += token.getValueAsHtml({invisibles, hasIndentGuide})

    innerHTML += @popScope(scopeStack) while scopeStack.length > 0
    innerHTML += @buildEndOfLineHTML(line, invisibles)
    innerHTML

  buildEndOfLineHTML: (line, invisibles) ->
    return '' if @props.mini or line.isSoftWrapped()

    html = ''
    if invisibles.cr? and line.lineEnding is '\r\n'
      html += "<span class='invisible-character'>#{invisibles.cr}</span>"
    if invisibles.eol?
      html += "<span class='invisible-character'>#{invisibles.eol}</span>"

    html

  updateScopeStack: (scopeStack, desiredScopes) ->
    html = ""

    # Find a common prefix
    for scope, i in desiredScopes
      break unless scopeStack[i]?.scope is desiredScopes[i]

    # Pop scopes until we're at the common prefx
    until scopeStack.length is i
      html += @popScope(scopeStack)

    # Push onto common prefix until scopeStack equals desiredScopes
    for j in [i...desiredScopes.length]
      html += @pushScope(scopeStack, desiredScopes[j])

    html

  popScope: (scopeStack) ->
    scopeStack.pop()
    "</span>"

  pushScope: (scopeStack, scope) ->
    scopeStack.push(scope)
    "<span class=\"#{scope.replace(/\.+/g, ' ')}\">"

  updateLineNode: (line, screenRow) ->
    {editor, lineHeightInPixels, lineDecorations} = @props
    lineNode = @lineNodesByLineId[line.id]

    decorations = lineDecorations[screenRow]
    previousDecorations = @renderedDecorationsByLineId[line.id]

    if previousDecorations?
      for decoration in previousDecorations
        lineNode.classList.remove(decoration.class) if editor.decorationMatchesType(decoration, 'line') and not _.deepContains(decorations, decoration)

    if decorations?
      for decoration in decorations
        if editor.decorationMatchesType(decoration, 'line') and not _.deepContains(previousDecorations, decoration)
          lineNode.classList.add(decoration.class)

    unless @screenRowsByLineId[line.id] is screenRow
      lineNode.style.top = screenRow * lineHeightInPixels + 'px'
      lineNode.dataset.screenRow = screenRow
      @screenRowsByLineId[line.id] = screenRow
      @lineIdsByScreenRow[screenRow] = line.id

  lineNodeForScreenRow: (screenRow) ->
    @lineNodesByLineId[@lineIdsByScreenRow[screenRow]]

  measureLineHeightAndDefaultCharWidth: ->
    node = @getDOMNode()
    node.appendChild(DummyLineNode)
    lineHeightInPixels = DummyLineNode.getBoundingClientRect().height
    charWidth = DummyLineNode.firstChild.getBoundingClientRect().width
    node.removeChild(DummyLineNode)

    {editor} = @props
    editor.setLineHeightInPixels(lineHeightInPixels)
    editor.setDefaultCharWidth(charWidth)

  remeasureCharacterWidths: ->
    @clearScopedCharWidths()
    @measureCharactersInNewLines()

  measureCharactersInNewLines: ->
    {editor} = @props
    [visibleStartRow, visibleEndRow] = @props.renderedRowRange
    node = @getDOMNode()

    for tokenizedLine in editor.linesForScreenRows(visibleStartRow, visibleEndRow - 1)
      unless @measuredLines.has(tokenizedLine)
        lineNode = @lineNodesByLineId[tokenizedLine.id]
        @measureCharactersInLine(tokenizedLine, lineNode)

  measureCharactersInLine: (tokenizedLine, lineNode) ->
    {editor} = @props
    rangeForMeasurement = null
    iterator = null
    charIndex = 0

    for {value, scopes}, tokenIndex in tokenizedLine.tokens
      charWidths = editor.getScopedCharWidths(scopes)

      for char in value
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
          rangeForMeasurement.setEnd(textNode, i + 1)
          charWidth = rangeForMeasurement.getBoundingClientRect().width
          editor.setScopedCharWidth(scopes, char, charWidth)

        charIndex++

    @measuredLines.add(tokenizedLine)

  clearScopedCharWidths: ->
    @measuredLines.clear()
    @props.editor.clearScopedCharWidths()
