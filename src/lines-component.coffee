React = require 'react-atom-fork'
{div, span} = require 'reactionary-atom-fork'
{debounce, isEqual, isEqualForProperties, multiplyString, toArray, clone} = require 'underscore-plus'
{$$} = require 'space-pen'

SelectionsComponent = require './selections-component'

DummyLineNode = $$(-> @div className: 'line', style: 'position: absolute; visibility: hidden;', => @span 'x')[0]
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
WrapperDiv = document.createElement('div')

module.exports =
LinesComponent = React.createClass
  displayName: 'LinesComponent'

  measureWhenShown: false

  render: ->
    {editor, scrollTop, scrollLeft, scrollHeight, scrollWidth, lineHeightInPixels, scrollViewHeight} = @props

    if @isMounted()
      style =
        height: Math.max(scrollHeight, scrollViewHeight)
        width: scrollWidth
        WebkitTransform: "translate3d(#{-scrollLeft}px, #{-scrollTop}px, 0px)"

    div {className: 'lines', style},
      @renderLines() if @isMounted()
      SelectionsComponent({key: 'selections', editor, lineHeightInPixels})

  renderLines: ->
    {editor, renderedRowRange, lineHeightInPixels, showIndentGuide, mini, invisibles, mouseWheelScreenRow} = @props
    [startRow, endRow] = renderedRowRange

    lineComponents =
      for line, i in editor.linesForScreenRows(startRow, endRow - 1)
        screenRow = startRow + i
        LineComponent({key: line.id, line, screenRow, lineHeightInPixels, showIndentGuide, mini, invisibles})

    if mouseWheelScreenRow? and not (startRow <= mouseWheelScreenRow < endRow)
      line = editor.lineForScreenRow(mouseWheelScreenRow)
      lineComponents.push(LineComponent({
        key: line.id, line, screenRow: mouseWheelScreenRow, screenRowOverride: endRow,
        lineHeightInPixels, showIndentGuide, mini, invisibles
      }))

    lineComponents

  componentWillMount: ->
    @measuredLines = new WeakSet

  componentDidMount: ->
    @measureLineHeightInPixelsAndCharWidth()

  shouldComponentUpdate: (newProps) ->
    return true if newProps.selectionChanged
    return true unless isEqualForProperties(newProps, @props,
      'renderedRowRange', 'fontSize', 'fontFamily', 'lineHeight', 'lineHeightInPixels',
      'scrollTop', 'scrollLeft', 'showIndentGuide', 'scrollingVertically', 'invisibles',
      'visible', 'scrollViewHeight', 'mouseWheelScreenRow'
    )

    {renderedRowRange, pendingChanges} = newProps
    for change in pendingChanges
      return true unless change.end <= renderedRowRange.start or renderedRowRange.end <= change.start

    false

  componentDidUpdate: (prevProps) ->
    @measureLineHeightInPixelsAndCharWidthIfNeeded(prevProps)
    @clearScopedCharWidths() unless isEqualForProperties(prevProps, @props, 'fontSize', 'fontFamily')
    @measureCharactersInNewLines() unless @props.scrollingVertically

  lineNodeForScreenRow: (screenRow) ->
    {renderedRowRange} = @props
    [startRow, endRow] = renderedRowRange

    unless startRow <= screenRow < endRow
      throw new Error("Requested screenRow #{screenRow} is not currently rendered")

    @getDOMNode().children[screenRow - startRow]

  measureLineHeightInPixelsAndCharWidthIfNeeded: (prevProps) ->
    {visible} = @props

    unless isEqualForProperties(prevProps, @props, 'fontSize', 'fontFamily', 'lineHeight')
      if visible
        @measureLineHeightInPixelsAndCharWidth()
      else
        @measureWhenShown = true
    @measureLineHeightInPixelsAndCharWidth() if visible and not prevProps.visible and @measureWhenShown

  measureLineHeightInPixelsAndCharWidth: ->
    @measureWhenShown = false
    node = @getDOMNode()
    node.appendChild(DummyLineNode)
    lineHeightInPixels = DummyLineNode.getBoundingClientRect().height
    charWidth = DummyLineNode.firstChild.getBoundingClientRect().width
    node.removeChild(DummyLineNode)

    {editor} = @props
    editor.setLineHeightInPixels(lineHeightInPixels)
    editor.setDefaultCharWidth(charWidth)

  measureCharactersInNewLines: ->
    [visibleStartRow, visibleEndRow] = @props.renderedRowRange
    node = @getDOMNode()

    for tokenizedLine, i in @props.editor.linesForScreenRows(visibleStartRow, visibleEndRow - 1)
      unless @measuredLines.has(tokenizedLine)
        lineNode = node.children[i]
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

LineComponent = React.createClass
  displayName: "LineComponent"

  render: ->
    {screenRow, screenRowOverride, lineHeightInPixels} = @props

    style =
      position: "absolute"
      top: (screenRowOverride ? screenRow) * lineHeightInPixels

    div className: "line", style: style, 'data-screen-row': screenRow, dangerouslySetInnerHTML: {__html: @buildInnerHTML()}

  shouldComponentUpdate: (newProps) ->
    not isEqualForProperties(newProps, @props, 'screenRow', 'lineHeightInPixels', 'showIndentGuide', 'invisibles')

  componentWillUpdate: (newProps) ->
    unless isEqualForProperties(newProps, @props, 'showIndentGuide', 'invisibles')
      @innerHTML = null

  buildInnerHTML: ->
    {line} = @props

    if line.text is ""
      @innerHTML ?= @buildEmptyInnerHTML()
    else
      @innerHTML ?= @buildNonEmptyInnerHTML()

  buildEmptyInnerHTML: ->
    {line, showIndentGuide} = @props
    {indentLevel, tabLength} = line

    if showIndentGuide and indentLevel > 0
      indentSpan = "<span class='indent-guide'>#{multiplyString(' ', tabLength)}</span>"
      multiplyString(indentSpan, indentLevel + 1)
    else
      "&nbsp;"

  buildNonEmptyInnerHTML: ->
    {line, invisibles, mini, showIndentGuide, invisibles} = @props
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

  buildEndOfLineHTML: ->
    {line, invisibles, mini} = @props
    return '' if mini or line.isSoftWrapped()

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
