React = require 'react'
{div, span} = require 'reactionary'
{debounce, isEqual, isEqualForProperties, multiplyString, toArray} = require 'underscore-plus'
{$$} = require 'space-pen'

SelectionsComponent = require './selections-component'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
WrapperDiv = document.createElement('div')

module.exports =
LinesComponent = React.createClass
  displayName: 'LinesComponent'

  render: ->
    if @isMounted()
      {editor, scrollTop, scrollLeft, scrollHeight, scrollWidth, lineHeight} = @props
      style =
        height: scrollHeight
        width: scrollWidth
        WebkitTransform: "translate3d(#{-scrollLeft}px, #{-scrollTop}px, 0px)"

    div {className: 'lines', style},
      SelectionsComponent({editor, lineHeight}) if @isMounted()

  componentWillMount: ->
    @measuredLines = new WeakSet
    @lineNodesByLineId = {}
    @lineNodeTopPositions = {}

  componentDidMount: ->
    @measureLineHeightAndCharWidth()

  shouldComponentUpdate: (newProps) ->
    return true if newProps.selectionChanged
    return true unless isEqualForProperties(newProps, @props,  'visibleRowRange', 'fontSize', 'fontFamily', 'lineHeight', 'scrollTop', 'scrollLeft', 'showIndentGuide', 'scrollingVertically')

    {visibleRowRange, pendingChanges} = newProps
    for change in pendingChanges
      return true unless change.end <= visibleRowRange.start or visibleRowRange.end <= change.start

    false

  componentDidUpdate: (prevProps) ->
    @updateLines()
    @measureLineHeightAndCharWidth() unless isEqualForProperties(prevProps, @props, 'fontSize', 'fontFamily', 'lineHeight')
    @clearScopedCharWidths() unless isEqualForProperties(prevProps, @props, 'fontSize', 'fontFamily')
    @measureCharactersInNewLines() unless @props.scrollingVertically

  updateLines: ->
    {editor, visibleRowRange, showIndentGuide, selectionChanged} = @props
    [startRow, endRow] = visibleRowRange
    startRow = Math.max(0, startRow - 8)
    endRow = Math.min(editor.getLineCount(), endRow + 8)

    visibleLines = editor.linesForScreenRows(startRow, endRow - 1)
    @removeNonVisibleLineNodes(visibleLines)
    @appendOrUpdateVisibleLineNodes(visibleLines, startRow)

  removeNonVisibleLineNodes: (visibleLines) ->
    visibleLineIds = new Set
    visibleLineIds.add(line.id.toString()) for line in visibleLines
    node = @getDOMNode()
    for lineId, lineNode of @lineNodesByLineId when not visibleLineIds.has(lineId)
      delete @lineNodesByLineId[lineId]
      delete @lineNodeTopPositions[lineId]
      node.removeChild(lineNode)

  appendOrUpdateVisibleLineNodes: (visibleLines, startRow) ->
    {lineHeight} = @props
    newLines = null
    newLinesHTML = null

    for line, index in visibleLines
      screenRow = startRow + index
      top = (screenRow * lineHeight)

      if @hasLineNode(line.id)
        @updateLineNode(line, top)
      else
        newLines ?= []
        newLinesHTML ?= ""
        newLines.push(line)
        newLinesHTML += @buildLineHTML(line, top)
        @lineNodeTopPositions[line.id] = top

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

  buildTranslate3d: (top) ->
    "translate3d(0px, #{top}px, 0px)"

  buildLineHTML: (line, top, left) ->
    {editor, mini, showIndentGuide} = @props
    {tokens, text, lineEnding, fold, isSoftWrapped, indentLevel} = line
    translate3d = @buildTranslate3d(top, left)
    lineHTML = "<div class=\"line\" style=\"position: absolute; top: #{top}px;\">"

    if text is ""
      lineHTML += "&nbsp;"
    else
      lineHTML += @buildLineInnerHTML(line)

    lineHTML += "</div>"
    lineHTML

  buildLineInnerHTML: (line) ->
    {invisibles, mini, showIndentGuide} = @props
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
    innerHTML

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

  updateLineNode: (line, top) ->
    unless @lineNodeTopPositions[line.id] is top
      lineNode = @lineNodesByLineId[line.id]
      lineNode.style.top = top + 'px'
      @lineNodeTopPositions[line.id] = top

  measureLineHeightAndCharWidth: ->
    node = @getDOMNode()
    node.appendChild(DummyLineNode)
    lineHeight = DummyLineNode.getBoundingClientRect().height
    charWidth = DummyLineNode.firstChild.getBoundingClientRect().width
    node.removeChild(DummyLineNode)

    {editor} = @props
    editor.setLineHeight(lineHeight)
    editor.setDefaultCharWidth(charWidth)

  measureCharactersInNewLines: ->
    [visibleStartRow, visibleEndRow] = @props.visibleRowRange
    node = @getDOMNode()

    for tokenizedLine in @props.editor.linesForScreenRows(visibleStartRow, visibleEndRow - 1)
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
